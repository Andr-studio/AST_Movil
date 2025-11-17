import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/ast_model.dart';
import '../models/user_model.dart';

class PDFService {
  // Generar PDF del AST
  Future<File> generarPDFAST({
    required AST ast,
    required AppUser tecnico,
    required AppUser supervisor,
    String? firmaTecnicoPath,
    String? firmaSupervisorPath,
    String? fotoLugarPath,
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    // Cargar imágenes si existen
    pw.ImageProvider? firmaTecnicoImage;
    pw.ImageProvider? firmaSupervisorImage;
    pw.ImageProvider? fotoLugarImage;

    if (firmaTecnicoPath != null && File(firmaTecnicoPath).existsSync()) {
      final bytes = await File(firmaTecnicoPath).readAsBytes();
      firmaTecnicoImage = pw.MemoryImage(bytes);
    }

    if (firmaSupervisorPath != null && File(firmaSupervisorPath).existsSync()) {
      final bytes = await File(firmaSupervisorPath).readAsBytes();
      firmaSupervisorImage = pw.MemoryImage(bytes);
    }

    if (fotoLugarPath != null && File(fotoLugarPath).existsSync()) {
      final bytes = await File(fotoLugarPath).readAsBytes();
      fotoLugarImage = pw.MemoryImage(bytes);
    }

    // Página 1: Información Principal
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Cabecera
              _buildHeader(ast, dateFormat),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              // Información General
              _buildSection(
                'INFORMACIÓN GENERAL',
                [
                  _buildInfoRow('Número MTA:', ast.numeroMTA),
                  _buildInfoRow('Estado:', _getEstadoText(ast.estado)),
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

              pw.SizedBox(height: 15),

              // Técnico
              _buildSection(
                'TÉCNICO',
                [
                  _buildInfoRow('Nombre:', tecnico.nombre),
                  _buildInfoRow('Email:', tecnico.email),
                  _buildInfoRow('Teléfono:', tecnico.telefono),
                ],
              ),

              pw.SizedBox(height: 15),

              // Supervisor
              _buildSection(
                'SUPERVISOR ASIGNADO',
                [
                  _buildInfoRow('Nombre:', supervisor.nombre),
                  _buildInfoRow('Email:', supervisor.email),
                  _buildInfoRow('Teléfono:', supervisor.telefono),
                ],
              ),

              pw.SizedBox(height: 15),

              // Ubicación
              _buildSection(
                'UBICACIÓN',
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
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );

    // Página 2: Actividades, Tareas, Riesgos
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Actividades
              if (ast.actividades.isNotEmpty) ...[
                _buildListSection('ACTIVIDADES', ast.actividades),
                pw.SizedBox(height: 15),
              ],

              // Tareas
              if (ast.tareas.isNotEmpty) ...[
                _buildListSection('TAREAS', ast.tareas),
                pw.SizedBox(height: 15),
              ],

              // Riesgos
              if (ast.riesgos.isNotEmpty) ...[
                _buildListSection('RIESGOS IDENTIFICADOS', ast.riesgos),
                pw.SizedBox(height: 15),
              ],

              // Medidas de Control
              if (ast.medidasControl.isNotEmpty) ...[
                _buildListSection('MEDIDAS DE CONTROL', ast.medidasControl),
                pw.SizedBox(height: 15),
              ],

              // Observaciones
              if (ast.observaciones.isNotEmpty) ...[
                _buildSection(
                  'OBSERVACIONES',
                  [
                    pw.Text(
                      ast.observaciones,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ],

              // Motivo de Rechazo
              if (ast.estado == EstadoAST.rechazado &&
                  ast.motivoRechazo != null) ...[
                pw.SizedBox(height: 15),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.red, width: 2),
                    borderRadius:
                        const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MOTIVO DE RECHAZO',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.red,
                        ),
                      ),
                      pw.SizedBox(height: 5),
                      pw.Text(
                        ast.motivoRechazo!,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    // Página 3: Firmas y Fotografía
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'FIRMAS Y EVIDENCIAS',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),

              // Firma del Técnico
              if (firmaTecnicoImage != null) ...[
                pw.Text(
                  'Firma del Técnico:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 100,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Center(
                    child: pw.Image(firmaTecnicoImage, height: 90),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  tecnico.nombre,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 20),
              ],

              // Firma del Supervisor
              if (firmaSupervisorImage != null) ...[
                pw.Text(
                  'Firma del Supervisor:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 100,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Center(
                    child: pw.Image(firmaSupervisorImage, height: 90),
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  supervisor.nombre,
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 20),
              ],

              // Fotografía del Lugar
              if (fotoLugarImage != null) ...[
                pw.Text(
                  'Fotografía del Lugar:',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Container(
                  height: 200,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey),
                  ),
                  child: pw.Center(
                    child: pw.Image(fotoLugarImage, fit: pw.BoxFit.contain),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    // Nota: El pie de página se agregará a través de la configuración de página
    // en la construcción de cada página individual

    // Guardar PDF
    final output = await _getTempFilePath(ast.numeroMTA);
    final file = File(output);
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // Helper: Cabecera del PDF
  pw.Widget _buildHeader(AST ast, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: _getEstadoColor(ast.estado),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ANÁLISIS SEGURO DE TRABAJO (AST)',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            ast.numeroMTA,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Estado: ${_getEstadoText(ast.estado).toUpperCase()}',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Sección con título
  pw.Widget _buildSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...children,
      ],
    );
  }

  // Helper: Fila de información
  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // Helper: Sección de lista numerada
  pw.Widget _buildListSection(String title, List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 10),
          decoration: const pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 8),
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5, left: 10),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '$index. ',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Expanded(
                  child: pw.Text(
                    item,
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // Helper: Obtener color según estado
  PdfColor _getEstadoColor(EstadoAST estado) {
    switch (estado) {
      case EstadoAST.pendiente:
        return PdfColors.orange;
      case EstadoAST.aprobado:
        return PdfColors.green;
      case EstadoAST.rechazado:
        return PdfColors.red;
    }
  }

  // Helper: Obtener texto del estado
  String _getEstadoText(EstadoAST estado) {
    switch (estado) {
      case EstadoAST.pendiente:
        return 'Pendiente';
      case EstadoAST.aprobado:
        return 'Aprobado';
      case EstadoAST.rechazado:
        return 'Rechazado';
    }
  }

  // Helper: Obtener ruta temporal para el PDF
  Future<String> _getTempFilePath(String numeroMTA) async {
    final tempDir = Directory.systemTemp;
    final fileName =
        'AST_${numeroMTA.replaceAll('/', '')}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    return '${tempDir.path}/$fileName';
  }

  // Obtener nombre del archivo PDF
  String getNombreArchivoPDF(String numeroMTA) {
    final now = DateTime.now();
    final dateFormat = DateFormat('yyyy-MM-dd');
    return 'AST_${numeroMTA.replaceAll('/', '')}_${dateFormat.format(now)}.pdf';
  }
}
