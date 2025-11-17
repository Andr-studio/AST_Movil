import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/ast_model.dart';
import '../../services/ast_service.dart';
import '../../services/ubicacion_service.dart';
import '../../services/almacenamiento_service.dart';
import '../../services/pdf_service.dart';
import '../../services/google_drive_service.dart';
import 'package:signature/signature.dart';

class GenerarASTScreen extends StatefulWidget {
  const GenerarASTScreen({super.key});

  @override
  State<GenerarASTScreen> createState() => _GenerarASTScreenState();
}

class _GenerarASTScreenState extends State<GenerarASTScreen> {
  final PageController _pageController = PageController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final ASTService _astService = ASTService();
  final UbicacionService _ubicacionService = UbicacionService();
  final AlmacenamientoService _almacenamientoService = AlmacenamientoService();
  final PDFService _pdfService = PDFService();
  final GoogleDriveService _driveService = GoogleDriveService();

  int _currentPage = 0;
  bool _isLoading = false;
  String _loadingMessage = 'Procesando...';

  // Datos del formulario
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();

  GPSData? _gpsData;
  File? _fotoLugar;
  Uint8List? _firmaTecnico;

  final List<String> _actividades = [];
  final List<String> _tareas = [];
  final List<String> _riesgos = [];
  final List<String> _medidasControl = [];

  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  @override
  void dispose() {
    _pageController.dispose();
    _direccionController.dispose();
    _observacionesController.dispose();
    _signatureController.dispose();
    _driveService.dispose();
    super.dispose();
  }

  Future<void> _capturarUbicacion() async {
    setState(() => _isLoading = true);

    try {
      final gpsData = await _ubicacionService.obtenerUbicacion();

      setState(() {
        _gpsData = gpsData;
        _direccionController.text = gpsData.direccionLegible;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ubicación capturada: ${gpsData.direccionLegible}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _capturarFoto() async {
    try {
      final foto = await _almacenamientoService.capturarFoto();

      if (foto != null) {
        setState(() {
          _fotoLugar = foto;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto capturada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarFirma() async {
    try {
      if (_signatureController.isEmpty) {
        throw 'Por favor, firma en el recuadro';
      }

      final firma = await _signatureController.toPngBytes();

      if (firma != null) {
        setState(() {
          _firmaTecnico = firma;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Firma guardada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generarAST() async {
    if (!_formKey.currentState!.validate()) return;

    if (_gpsData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes capturar la ubicación GPS'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_firmaTecnico == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes firmar el documento'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_actividades.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos una actividad'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = 'Generando AST...';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final tecnico = authProvider.currentUser!;

      // 1. Obtener supervisor
      setState(() => _loadingMessage = 'Obteniendo datos del supervisor...');

      final supervisorDoc =
          await _astService.obtenerSupervisor(tecnico.supervisorUid!);
      if (supervisorDoc == null) {
        throw 'Supervisor no encontrado';
      }

      final supervisor = AppUser.fromFirestore(supervisorDoc);

      // 2. Crear o verificar carpeta en Drive
      setState(
          () => _loadingMessage = 'Verificando carpeta en Google Drive...');

      String carpetaDriveId;
      if (tecnico.carpetaDriveId != null &&
          tecnico.carpetaDriveId!.isNotEmpty) {
        carpetaDriveId = tecnico.carpetaDriveId!;
      } else {
        // Crear carpeta por primera vez
        carpetaDriveId = await _driveService.crearCarpetaTecnico(
          tecnico.uid,
          tecnico.nombre,
        );

        // Actualizar en Firestore
        await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(tecnico.uid)
            .update({'carpetaDriveId': carpetaDriveId});
      }

      // 3. Generar número MTA
      setState(() => _loadingMessage = 'Generando número MTA...');
      final numeroMTA = await _astService.generarNumeroMTA();

      // 4. Guardar firma como archivo
      setState(() => _loadingMessage = 'Guardando firma...');
      final firmaFile = await _almacenamientoService.guardarFirma(
        _firmaTecnico!,
        'firma_tecnico_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      // 5. Subir firma a Drive
      setState(() => _loadingMessage = 'Subiendo firma a Drive...');
      final firmaData = await _driveService.subirFirma(
        firmaFile: firmaFile,
        tipo: 'tecnico',
        numeroMTA: numeroMTA,
        carpetaTecnicoId: carpetaDriveId,
      );

      // 6. Subir foto si existe
      String? fotoUrl;
      if (_fotoLugar != null) {
        setState(() => _loadingMessage = 'Subiendo fotografía...');
        final fotoData = await _driveService.subirFoto(
          fotoFile: _fotoLugar!,
          numeroMTA: numeroMTA,
          carpetaTecnicoId: carpetaDriveId,
        );
        fotoUrl = fotoData['url'];
      }

      // 7. Crear AST temporal en Firestore (sin PDF aún)
      setState(() => _loadingMessage = 'Creando registro en base de datos...');
      final docId = numeroMTA.replaceAll('/', '');

      final ast = AST(
        id: docId,
        numeroMTA: numeroMTA,
        estado: EstadoAST.pendiente,
        tecnicoUid: tecnico.uid,
        tecnicoNombre: tecnico.nombre,
        tecnicoEmail: tecnico.email,
        supervisorAsignadoUid: supervisor.uid,
        supervisorAsignadoNombre: supervisor.nombre,
        supervisorAsignadoEmail: supervisor.email,
        fechaGeneracion: DateTime.now(),
        direccion: _direccionController.text,
        gps: _gpsData,
        actividades: _actividades,
        tareas: _tareas,
        riesgos: _riesgos,
        medidasControl: _medidasControl,
        observaciones: _observacionesController.text,
        firmaTecnicoUrl: firmaData['url'],
        fotoLugarUrl: fotoUrl,
        dispositivoGeneracion: Platform.operatingSystem,
      );

      await FirebaseFirestore.instance
          .collection('ast')
          .doc(docId)
          .set(ast.toFirestore());

      // 8. Generar PDF
      setState(() => _loadingMessage = 'Generando PDF...');
      final pdfFile = await _pdfService.generarPDFAST(
        ast: ast,
        tecnico: tecnico,
        supervisor: supervisor,
        firmaTecnicoPath: firmaFile.path,
        fotoLugarPath: _fotoLugar?.path,
      );

      // 9. Subir PDF a Drive
      setState(() => _loadingMessage = 'Subiendo PDF a Drive...');
      final pdfData = await _driveService.subirPDFAST(
        pdfFile: pdfFile,
        numeroMTA: numeroMTA,
        carpetaTecnicoId: carpetaDriveId,
      );

      // 10. Actualizar AST con info del PDF
      setState(() => _loadingMessage = 'Finalizando...');
      await FirebaseFirestore.instance.collection('ast').doc(docId).update({
        'pdfDriveId': pdfData['id'],
        'pdfUrl': pdfData['url'],
        'pdfNombre': pdfData['nombre'],
      });

      // 11. Actualizar contadores
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(tecnico.uid)
          .update({
        'totalASTGenerados': FieldValue.increment(1),
        'totalASTPendientes': FieldValue.increment(1),
      });

      await FirebaseFirestore.instance
          .collection('tecnicosPorSupervisor')
          .doc(supervisor.uid)
          .update({
        'tecnicos.${tecnico.uid}.totalAST': FieldValue.increment(1),
        'tecnicos.${tecnico.uid}.ultimoAST': FieldValue.serverTimestamp(),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      // 12. Limpiar archivos temporales
      try {
        await pdfFile.delete();
        await firmaFile.delete();
      } catch (e) {
        // Ignorar errores de limpieza
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ AST generado correctamente',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('Número: $numeroMTA'),
                Text('PDF subido a Drive'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❌ Error al generar AST',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(e.toString()),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = 'Procesando...';
        });
      }
    }
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor espera, se está generando el AST...'),
              backgroundColor: Colors.orange,
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Generar AST'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _isLoading ? null : () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? _buildLoadingOverlay()
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Indicador de progreso
                    _buildProgressIndicator(),

                    // Páginas del formulario
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (page) {
                          setState(() {
                            _currentPage = page;
                          });
                        },
                        children: [
                          _buildPage1Ubicacion(),
                          _buildPage2Actividades(),
                          _buildPage3RiesgosYMedidas(),
                          _buildPage4FirmaYFoto(),
                        ],
                      ),
                    ),

                    // Botones de navegación
                    _buildNavigationButtons(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Por favor no cierres esta pantalla',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index == _currentPage;
          final isCompleted = index < _currentPage;

          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              decoration: BoxDecoration(
                color: isCompleted || isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  // PÁGINA 1: UBICACIÓN
  Widget _buildPage1Ubicacion() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso 1: Ubicación',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Captura la ubicación donde se realizará el trabajo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Botón capturar ubicación
          SizedBox(
            width: double.infinity,
            height: 120,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _capturarUbicacion,
              style: ElevatedButton.styleFrom(
                backgroundColor: _gpsData != null ? Colors.green : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _gpsData != null ? Icons.check_circle : Icons.gps_fixed,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _gpsData != null
                        ? 'Ubicación Capturada'
                        : 'CAPTURAR UBICACIÓN GPS',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (_gpsData != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Datos GPS',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _buildInfoRow('Latitud', _gpsData!.lat.toStringAsFixed(6)),
                    const SizedBox(height: 8),
                    _buildInfoRow('Longitud', _gpsData!.lng.toStringAsFixed(6)),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Precisión',
                      '${_gpsData!.precision.toStringAsFixed(1)} metros',
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Dirección
          TextFormField(
            controller: _direccionController,
            decoration: const InputDecoration(
              labelText: 'Dirección del trabajo *',
              prefixIcon: Icon(Icons.location_on),
              hintText: 'Ej: Av. Grecia 1345, Antofagasta',
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Ingresa la dirección';
              }
              return null;
            },
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La ubicación GPS se capturará automáticamente. Puedes editar la dirección si es necesario.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // PÁGINA 2: ACTIVIDADES Y TAREAS
  Widget _buildPage2Actividades() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso 2: Actividades y Tareas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Describe las actividades y tareas a realizar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Actividades
          _buildListSection(
            title: 'Actividades',
            icon: Icons.work_outline,
            items: _actividades,
            hintText: 'Ej: Instalación de fibra óptica',
            color: Colors.blue,
          ),

          const SizedBox(height: 24),

          // Tareas
          _buildListSection(
            title: 'Tareas Específicas',
            icon: Icons.task_alt,
            items: _tareas,
            hintText: 'Ej: Inspección visual del área',
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  // PÁGINA 3: RIESGOS Y MEDIDAS
  Widget _buildPage3RiesgosYMedidas() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso 3: Riesgos y Medidas de Control',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifica riesgos y las medidas para controlarlos',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Riesgos
          _buildListSection(
            title: 'Riesgos Identificados',
            icon: Icons.warning_amber,
            items: _riesgos,
            hintText: 'Ej: Caída a distinto nivel',
            color: Colors.orange,
          ),

          const SizedBox(height: 24),

          // Medidas de Control
          _buildListSection(
            title: 'Medidas de Control',
            icon: Icons.security,
            items: _medidasControl,
            hintText: 'Ej: Uso de EPP completo',
            color: Colors.purple,
          ),

          const SizedBox(height: 24),

          // Observaciones
          TextFormField(
            controller: _observacionesController,
            decoration: const InputDecoration(
              labelText: 'Observaciones adicionales',
              prefixIcon: Icon(Icons.notes),
              hintText: 'Agrega cualquier observación relevante',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // PÁGINA 4: FIRMA Y FOTO
  Widget _buildPage4FirmaYFoto() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paso 4: Firma y Fotografía',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Firma el documento y captura una foto del lugar',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),

          // Firma
          Text(
            'Firma del Técnico *',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          Container(
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _firmaTecnico != null
                  ? Image.memory(_firmaTecnico!, fit: BoxFit.contain)
                  : Signature(
                      controller: _signatureController,
                      backgroundColor: Colors.grey[50]!,
                    ),
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    _signatureController.clear();
                    setState(() {
                      _firmaTecnico = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('LIMPIAR'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _guardarFirma,
                  icon: const Icon(Icons.check),
                  label: const Text('GUARDAR'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Foto
          Text(
            'Fotografía del Lugar',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),

          if (_fotoLugar != null)
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: FileImage(_fotoLugar!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Sin fotografía'),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _capturarFoto,
              icon: const Icon(Icons.camera_alt),
              label:
                  Text(_fotoLugar != null ? 'CAMBIAR FOTO' : 'CAPTURAR FOTO'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection({
    required String title,
    required IconData icon,
    required List<String> items,
    required String hintText,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              '${items.length}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('No hay elementos agregados'),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      items.removeAt(index);
                    });
                  },
                ),
              ),
            );
          }),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _showAddItemDialog(items, hintText),
          icon: const Icon(Icons.add),
          label: const Text('AGREGAR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
          ),
        ),
      ],
    );
  }

  void _showAddItemDialog(List<String> items, String hintText) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar elemento'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  items.add(controller.text.trim());
                });
                Navigator.pop(context);
              }
            },
            child: const Text('AGREGAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _previousPage,
                child: const Text('ANTERIOR'),
              ),
            ),
          if (_currentPage > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : _currentPage < 3
                      ? _nextPage
                      : _generarAST,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(_currentPage < 3 ? 'SIGUIENTE' : 'GENERAR AST'),
            ),
          ),
        ],
      ),
    );
  }
}
