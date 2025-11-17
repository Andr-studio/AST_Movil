import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/ast_model.dart';
import 'aprobar_ast_screen.dart';
import 'rechazar_ast_screen.dart';

class RevisarASTScreen extends StatelessWidget {
  final AST ast;

  const RevisarASTScreen({
    super.key,
    required this.ast,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Revisar AST'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Estado del AST - Banner superior
          _buildEstadoBanner(context),

          // Contenido principal scrolleable
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Información Principal
                  _buildSectionCard(
                    context,
                    'INFORMACIÓN PRINCIPAL',
                    Icons.info_outline,
                    Colors.blue,
                    [
                      _buildInfoRow('Número MTA:', ast.numeroMTA),
                      _buildInfoRow('Estado:', ast.estado.displayName),
                      _buildInfoRow(
                        'Fecha Generación:',
                        dateFormat.format(ast.fechaGeneracion),
                      ),
                      if (ast.fechaAprobacion != null)
                        _buildInfoRow(
                          'Fecha Aprobación:',
                          dateFormat.format(ast.fechaAprobacion!),
                        ),
                      if (ast.fechaRechazo != null)
                        _buildInfoRow(
                          'Fecha Rechazo:',
                          dateFormat.format(ast.fechaRechazo!),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Técnico
                  _buildSectionCard(
                    context,
                    'TÉCNICO',
                    Icons.engineering,
                    Colors.green,
                    [
                      _buildInfoRow('Nombre:', ast.tecnicoNombre),
                      _buildInfoRow('Email:', ast.tecnicoEmail),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Ubicación
                  _buildSectionCard(
                    context,
                    'UBICACIÓN',
                    Icons.location_on,
                    Colors.red,
                    [
                      _buildInfoRow('Dirección:', ast.direccion),
                      if (ast.gps != null) ...[
                        _buildInfoRow(
                          'Coordenadas:',
                          'Lat: ${ast.gps!.lat.toStringAsFixed(6)}, Lng: ${ast.gps!.lng.toStringAsFixed(6)}',
                        ),
                        _buildInfoRow(
                          'Precisión GPS:',
                          '${ast.gps!.precision.toStringAsFixed(1)} metros',
                        ),
                        const SizedBox(height: 8),
                        _buildMapButton(context, ast.gps!),
                      ],
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Actividades
                  if (ast.actividades.isNotEmpty)
                    _buildListCard(
                      context,
                      'ACTIVIDADES',
                      ast.actividades,
                      Icons.work_outline,
                      Colors.purple,
                    ),

                  if (ast.actividades.isNotEmpty) const SizedBox(height: 16),

                  // Tareas
                  if (ast.tareas.isNotEmpty)
                    _buildListCard(
                      context,
                      'TAREAS',
                      ast.tareas,
                      Icons.assignment,
                      Colors.orange,
                    ),

                  if (ast.tareas.isNotEmpty) const SizedBox(height: 16),

                  // Riesgos
                  if (ast.riesgos.isNotEmpty)
                    _buildListCard(
                      context,
                      'RIESGOS IDENTIFICADOS',
                      ast.riesgos,
                      Icons.warning,
                      Colors.red,
                    ),

                  if (ast.riesgos.isNotEmpty) const SizedBox(height: 16),

                  // Medidas de Control
                  if (ast.medidasControl.isNotEmpty)
                    _buildListCard(
                      context,
                      'MEDIDAS DE CONTROL',
                      ast.medidasControl,
                      Icons.security,
                      Colors.green,
                    ),

                  if (ast.medidasControl.isNotEmpty) const SizedBox(height: 16),

                  // Observaciones
                  if (ast.observaciones.isNotEmpty)
                    _buildSectionCard(
                      context,
                      'OBSERVACIONES',
                      Icons.notes,
                      Colors.grey,
                      [
                        Text(
                          ast.observaciones,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),

                  if (ast.observaciones.isNotEmpty) const SizedBox(height: 16),

                  // Motivo de Rechazo (si está rechazado)
                  if (ast.estado == EstadoAST.rechazado &&
                      ast.motivoRechazo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red),
                              const SizedBox(width: 8),
                              Text(
                                'MOTIVO DE RECHAZO',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            ast.motivoRechazo!,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),

                  if (ast.estado == EstadoAST.rechazado &&
                      ast.motivoRechazo != null)
                    const SizedBox(height: 16),

                  // Evidencias
                  _buildEvidenciasCard(context),

                  const SizedBox(height: 16),

                  // PDF (si existe)
                  if (ast.pdfUrl != null && ast.pdfUrl!.isNotEmpty)
                    _buildPDFCard(context),

                  const SizedBox(height: 100), // Espacio para botones flotantes
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ast.estado == EstadoAST.pendiente
          ? _buildActionButtons(context)
          : null,
    );
  }

  Widget _buildEstadoBanner(BuildContext context) {
    Color backgroundColor;
    IconData icon;
    String text;

    switch (ast.estado) {
      case EstadoAST.pendiente:
        backgroundColor = Colors.orange;
        icon = Icons.pending_actions;
        text = 'PENDIENTE DE APROBACIÓN';
        break;
      case EstadoAST.aprobado:
        backgroundColor = Colors.green;
        icon = Icons.check_circle;
        text = 'APROBADO';
        break;
      case EstadoAST.rechazado:
        backgroundColor = Colors.red;
        icon = Icons.cancel;
        text = 'RECHAZADO';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context,
    String title,
    List<String> items,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$index',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapButton(BuildContext context, GPSData gps) {
    return ElevatedButton.icon(
      onPressed: () => _abrirMapa(gps),
      icon: const Icon(Icons.map),
      label: const Text('Ver en Mapa'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEvidenciasCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.photo_library, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'EVIDENCIAS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (ast.firmaTecnicoUrl != null)
              _buildEvidenciaButton(
                context,
                'Firma del Técnico',
                Icons.draw,
                ast.firmaTecnicoUrl!,
              ),
            if (ast.firmaTecnicoUrl != null) const SizedBox(height: 8),
            if (ast.firmaSupervisorUrl != null)
              _buildEvidenciaButton(
                context,
                'Firma del Supervisor',
                Icons.verified,
                ast.firmaSupervisorUrl!,
              ),
            if (ast.firmaSupervisorUrl != null) const SizedBox(height: 8),
            if (ast.fotoLugarUrl != null)
              _buildEvidenciaButton(
                context,
                'Fotografía del Lugar',
                Icons.photo_camera,
                ast.fotoLugarUrl!,
              ),
            if (ast.firmaTecnicoUrl == null &&
                ast.firmaSupervisorUrl == null &&
                ast.fotoLugarUrl == null)
              const Text(
                'No hay evidencias disponibles',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEvidenciaButton(
    BuildContext context,
    String label,
    IconData icon,
    String url,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _abrirURL(url),
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(12),
        ),
      ),
    );
  }

  Widget _buildPDFCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _abrirURL(ast.pdfUrl!),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ver PDF Completo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ast.pdfNombre ?? 'Documento PDF',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Container(
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
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rechazarAST(context),
                icon: const Icon(Icons.cancel),
                label: const Text('RECHAZAR'),
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
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _aprobarAST(context),
                icon: const Icon(Icons.check_circle),
                label: const Text('APROBAR'),
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
          ],
        ),
      ),
    );
  }

  void _aprobarAST(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AprobarASTScreen(ast: ast),
      ),
    );
  }

  void _rechazarAST(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RechazarASTScreen(ast: ast),
      ),
    );
  }

  Future<void> _abrirURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _abrirMapa(GPSData gps) async {
    final url = 'https://www.google.com/maps?q=${gps.lat},${gps.lng}';
    await _abrirURL(url);
  }
}
