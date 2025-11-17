import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../models/ast_model.dart';

class DetalleASTScreen extends StatelessWidget {
  final AST ast;

  const DetalleASTScreen({
    super.key,
    required this.ast,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    Color estadoColor;
    IconData estadoIcon;

    switch (ast.estado) {
      case EstadoAST.pendiente:
        estadoColor = Colors.orange;
        estadoIcon = Icons.pending;
        break;
      case EstadoAST.aprobado:
        estadoColor = Colors.green;
        estadoIcon = Icons.check_circle;
        break;
      case EstadoAST.rechazado:
        estadoColor = Colors.red;
        estadoIcon = Icons.cancel;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(ast.numeroMTA),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Compartir AST (Fase 4 con PDF)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Compartir disponible en Fase 4'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera con estado
            _buildHeader(context, estadoColor, estadoIcon),
            const SizedBox(height: 24),

            // Información general
            _buildSection(
              context,
              'Información General',
              Icons.info_outline,
              Colors.blue,
              [
                _buildInfoRow('Número MTA', ast.numeroMTA),
                _buildInfoRow('Estado', ast.estado.displayName),
                _buildInfoRow(
                  'Fecha Generación',
                  dateFormat.format(ast.fechaGeneracion),
                ),
                if (ast.fechaAprobacion != null)
                  _buildInfoRow(
                    'Fecha Aprobación',
                    dateFormat.format(ast.fechaAprobacion!),
                  ),
                if (ast.fechaRechazo != null)
                  _buildInfoRow(
                    'Fecha Rechazo',
                    dateFormat.format(ast.fechaRechazo!),
                  ),
              ],
            ),

            const SizedBox(height: 24),

            // Técnico
            _buildSection(
              context,
              'Técnico',
              Icons.engineering,
              Colors.green,
              [
                _buildInfoRow('Nombre', ast.tecnicoNombre),
                _buildInfoRow('Email', ast.tecnicoEmail),
              ],
            ),

            const SizedBox(height: 24),

            // Supervisor
            _buildSection(
              context,
              'Supervisor Asignado',
              Icons.supervisor_account,
              Colors.blue,
              [
                _buildInfoRow('Nombre', ast.supervisorAsignadoNombre),
                _buildInfoRow('Email', ast.supervisorAsignadoEmail),
              ],
            ),

            if (ast.supervisorAprobadorNombre != null) ...[
              const SizedBox(height: 24),
              _buildSection(
                context,
                'Supervisor Aprobador',
                Icons.verified_user,
                Colors.purple,
                [
                  _buildInfoRow('Nombre', ast.supervisorAprobadorNombre!),
                ],
              ),
            ],

            const SizedBox(height: 24),

            // Ubicación
            _buildSection(
              context,
              'Ubicación',
              Icons.location_on,
              Colors.red,
              [
                _buildInfoRow('Dirección', ast.direccion),
                if (ast.gps != null) ...[
                  _buildInfoRow(
                    'Coordenadas',
                    'Lat: ${ast.gps!.lat.toStringAsFixed(6)}, Lng: ${ast.gps!.lng.toStringAsFixed(6)}',
                  ),
                  _buildInfoRow(
                    'Precisión GPS',
                    '${ast.gps!.precision.toStringAsFixed(1)} metros',
                  ),
                  _buildInfoRow(
                    'Dirección GPS',
                    ast.gps!.direccionLegible,
                  ),
                ],
              ],
            ),

            const SizedBox(height: 24),

            // Actividades
            if (ast.actividades.isNotEmpty)
              _buildListSection(
                context,
                'Actividades',
                Icons.work_outline,
                Colors.blue,
                ast.actividades,
              ),

            const SizedBox(height: 24),

            // Tareas
            if (ast.tareas.isNotEmpty)
              _buildListSection(
                context,
                'Tareas',
                Icons.task_alt,
                Colors.green,
                ast.tareas,
              ),

            const SizedBox(height: 24),

            // Riesgos
            if (ast.riesgos.isNotEmpty)
              _buildListSection(
                context,
                'Riesgos Identificados',
                Icons.warning_amber,
                Colors.orange,
                ast.riesgos,
              ),

            const SizedBox(height: 24),

            // Medidas de Control
            if (ast.medidasControl.isNotEmpty)
              _buildListSection(
                context,
                'Medidas de Control',
                Icons.security,
                Colors.purple,
                ast.medidasControl,
              ),

            const SizedBox(height: 24),

            // Observaciones
            if (ast.observaciones.isNotEmpty)
              _buildSection(
                context,
                'Observaciones',
                Icons.notes,
                Colors.grey,
                [
                  Text(ast.observaciones),
                ],
              ),

            const SizedBox(height: 24),

            // Firma del técnico
            if (ast.firmaTecnicoUrl != null)
              _buildMediaSection(
                context,
                'Firma del Técnico',
                Icons.edit,
                Colors.blue,
                ast.firmaTecnicoUrl!,
                MediaType.firma,
              ),

            const SizedBox(height: 24),

            // Foto del lugar
            if (ast.fotoLugarUrl != null)
              _buildMediaSection(
                context,
                'Fotografía del Lugar',
                Icons.camera_alt,
                Colors.green,
                ast.fotoLugarUrl!,
                MediaType.foto,
              ),

            const SizedBox(height: 24),

            // Firma del supervisor
            if (ast.firmaSupervisorUrl != null)
              _buildMediaSection(
                context,
                'Firma del Supervisor',
                Icons.verified_user,
                Colors.purple,
                ast.firmaSupervisorUrl!,
                MediaType.firma,
              ),

            // Motivo de rechazo
            if (ast.estado == EstadoAST.rechazado &&
                ast.motivoRechazo != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cancel, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Motivo de Rechazo',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ast.motivoRechazo!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Metadata
            _buildSection(
              context,
              'Información Técnica',
              Icons.settings,
              Colors.grey,
              [
                _buildInfoRow('Versión', 'v${ast.version}'),
                if (ast.dispositivoGeneracion != null)
                  _buildInfoRow('Dispositivo', ast.dispositivoGeneracion!),
                if (ast.pdfNombre != null) _buildInfoRow('PDF', ast.pdfNombre!),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color color, IconData icon) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              ast.numeroMTA,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                ast.estado.displayName,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Card(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
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

  Widget _buildListSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Card(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
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
                          '${index + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item),
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

  Widget _buildMediaSection(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    String path,
    MediaType type,
  ) {
    return Card(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildMediaWidget(path, type),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaWidget(String path, MediaType type) {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        return Container(
          height: type == MediaType.foto ? 200 : 150,
          color: Colors.grey[200],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == MediaType.foto
                      ? Icons.broken_image
                      : Icons.error_outline,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'Archivo no disponible',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }

      return Image.file(
        file,
        height: type == MediaType.foto ? 200 : 150,
        width: double.infinity,
        fit: BoxFit.contain,
      );
    } catch (e) {
      return Container(
        height: type == MediaType.foto ? 200 : 150,
        color: Colors.grey[200],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 8),
              Text(
                'Error al cargar archivo',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }
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
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum MediaType {
  foto,
  firma,
}
