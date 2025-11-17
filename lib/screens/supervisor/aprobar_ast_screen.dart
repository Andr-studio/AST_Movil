import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'package:signature/signature.dart';
import '../../models/ast_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/aprobacion_service.dart';

class AprobarASTScreen extends StatefulWidget {
  final AST ast;

  const AprobarASTScreen({
    super.key,
    required this.ast,
  });

  @override
  State<AprobarASTScreen> createState() => _AprobarASTScreenState();
}

class _AprobarASTScreenState extends State<AprobarASTScreen> {
  final AprobacionService _aprobacionService = AprobacionService();
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isLoading = false;
  String _loadingMessage = 'Procesando...';
  Uint8List? _firmaSupervisor;

  @override
  void dispose() {
    _signatureController.dispose();
    _aprobacionService.dispose();
    super.dispose();
  }

  Future<void> _guardarFirma() async {
    try {
      if (_signatureController.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor, firma en el recuadro'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final firma = await _signatureController.toPngBytes();

      if (firma != null) {
        setState(() {
          _firmaSupervisor = firma;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Firma guardada correctamente ✓'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar firma: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _limpiarFirma() {
    _signatureController.clear();
    setState(() {
      _firmaSupervisor = null;
    });
  }

  Future<void> _confirmarAprobacion() async {
    if (_firmaSupervisor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes firmar antes de aprobar el AST'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Aprobación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas aprobar este AST?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AST: ${widget.ast.numeroMTA}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Técnico: ${widget.ast.tecnicoNombre}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Esta acción:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cambiará el estado a "Aprobado"',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Regenerará el PDF con tu firma',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                Icon(Icons.check, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Actualizará el archivo en Drive',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción no se puede deshacer',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_circle),
            label: const Text('APROBAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _aprobarAST();
    }
  }

  Future<void> _aprobarAST() async {
    setState(() {
      _isLoading = true;
      _loadingMessage = 'Aprobando AST...';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supervisor = authProvider.currentUser!;

      // Actualizar mensaje de progreso
      setState(() => _loadingMessage = 'Subiendo firma...');

      // Aprobar AST usando el servicio
      await _aprobacionService.aprobarAST(
        astId: widget.ast.id,
        supervisor: supervisor,
        firmaSupervisor: _firmaSupervisor!,
      );

      if (mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AST Aprobado Exitosamente',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.ast.numeroMTA,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Recargar usuario para actualizar contadores
        await authProvider.reloadCurrentUser();

        // Volver al home (2 pantallas atrás)
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aprobar AST: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aprobar AST'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información del AST
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade700, Colors.green.shade500],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'APROBAR AST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildInfoRow('Número MTA:', widget.ast.numeroMTA),
                        _buildInfoRow('Técnico:', widget.ast.tecnicoNombre),
                        _buildInfoRow('Dirección:', widget.ast.direccion),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Instrucciones
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Instrucciones',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Firma en el recuadro blanco usando tu dedo o stylus\n'
                        '2. Presiona "Guardar Firma" cuando termines\n'
                        '3. Revisa tu firma en la vista previa\n'
                        '4. Presiona "Aprobar AST" para finalizar',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Título Firma
                Text(
                  'FIRMA DEL SUPERVISOR',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Canvas de firma
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Signature(
                      controller: _signatureController,
                      height: 250,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Botones de firma
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _limpiarFirma,
                        icon: const Icon(Icons.clear),
                        label: const Text('Limpiar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _guardarFirma,
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar Firma'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Vista previa de la firma
                if (_firmaSupervisor != null) ...[
                  Text(
                    'VISTA PREVIA',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Image.memory(
                              _firmaSupervisor!,
                              height: 100,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Firma guardada correctamente',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ],
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          _loadingMessage,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Por favor espera...',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _firmaSupervisor != null && !_isLoading
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _confirmarAprobacion,
                    icon: const Icon(Icons.check_circle, size: 24),
                    label: const Text(
                      'APROBAR AST',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
