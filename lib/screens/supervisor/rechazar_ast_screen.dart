import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/ast_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/aprobacion_service.dart';

class RechazarASTScreen extends StatefulWidget {
  final AST ast;

  const RechazarASTScreen({
    super.key,
    required this.ast,
  });

  @override
  State<RechazarASTScreen> createState() => _RechazarASTScreenState();
}

class _RechazarASTScreenState extends State<RechazarASTScreen> {
  final AprobacionService _aprobacionService = AprobacionService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _motivoController = TextEditingController();

  bool _isLoading = false;

  // Motivos predefinidos comunes
  final List<String> _motivosPredefinidos = [
    'Falta información de seguridad crítica',
    'Medidas de control insuficientes',
    'Riesgos no identificados correctamente',
    'Fotografía del lugar no clara o insuficiente',
    'Ubicación GPS imprecisa o incorrecta',
    'Actividades no descritas adecuadamente',
    'Falta evidencia fotográfica requerida',
    'Información técnica incompleta',
  ];

  @override
  void dispose() {
    _motivoController.dispose();
    _aprobacionService.dispose();
    super.dispose();
  }

  void _seleccionarMotivoPredefinido(String motivo) {
    setState(() {
      if (_motivoController.text.isEmpty) {
        _motivoController.text = motivo;
      } else {
        _motivoController.text = '${_motivoController.text}\n• $motivo';
      }
    });
  }

  Future<void> _confirmarRechazo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Confirmar Rechazo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Estás seguro de que deseas rechazar este AST?',
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
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Motivo de rechazo:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _motivoController.text.trim(),
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
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
                      'El técnico será notificado del rechazo',
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
            icon: const Icon(Icons.cancel),
            label: const Text('RECHAZAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _rechazarAST();
    }
  }

  Future<void> _rechazarAST() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final supervisor = authProvider.currentUser!;

      await _aprobacionService.rechazarAST(
        astId: widget.ast.id,
        supervisor: supervisor,
        motivoRechazo: _motivoController.text.trim(),
      );

      if (mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cancel, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AST Rechazado',
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
            backgroundColor: Colors.red,
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
            content: Text('Error al rechazar AST: $e'),
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
        title: const Text('Rechazar AST'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                          colors: [Colors.red.shade700, Colors.red.shade500],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.cancel,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'RECHAZAR AST',
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

                  // Advertencia
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amber.shade700, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Importante',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'El motivo de rechazo debe ser claro y detallado para que el técnico pueda corregir el AST adecuadamente.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Campo de motivo
                  Text(
                    'MOTIVO DE RECHAZO',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _motivoController,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Describe el motivo del rechazo...\n\n'
                          'Ejemplo:\n'
                          '• Falta información sobre medidas de control\n'
                          '• La foto del lugar no es clara\n'
                          '• Los riesgos no están bien identificados',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Debes proporcionar un motivo de rechazo';
                      }
                      if (value.trim().length < 10) {
                        return 'El motivo debe tener al menos 10 caracteres';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Motivos predefinidos
                  Text(
                    'MOTIVOS FRECUENTES',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca para agregar al motivo:',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _motivosPredefinidos.map((motivo) {
                      return InkWell(
                        onTap: () => _seleccionarMotivoPredefinido(motivo),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red.shade200),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                size: 16,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                motivo,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 100), // Espacio para botón flotante
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  margin: EdgeInsets.all(32),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Rechazando AST...',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 8),
                        Text(
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
      bottomNavigationBar: !_isLoading
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
                    onPressed: _confirmarRechazo,
                    icon: const Icon(Icons.cancel, size: 24),
                    label: const Text(
                      'RECHAZAR AST',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
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
