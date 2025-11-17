import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/ast_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import 'almacenamiento_service.dart';
import 'google_drive_service.dart';
import 'pdf_service.dart';
import 'ast_service.dart';
import 'notification_service.dart';

class AprobacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AlmacenamientoService _almacenamientoService = AlmacenamientoService();
  final GoogleDriveService _driveService = GoogleDriveService();
  final PDFService _pdfService = PDFService();
  final ASTService _astService = ASTService();
  final NotificationService _notificationService = NotificationService();

  /// Aprobar un AST con firma digital del supervisor
  ///
  /// Este método:
  /// 1. Valida que el AST esté pendiente
  /// 2. Sube la firma del supervisor a Google Drive
  /// 3. Descarga las imágenes existentes (firma técnico, foto)
  /// 4. Regenera el PDF con la firma del supervisor
  /// 5. Reemplaza el PDF antiguo en Drive
  /// 6. Actualiza el AST en Firestore con estado "aprobado"
  /// 7. Actualiza los contadores del técnico y supervisor
  Future<void> aprobarAST({
    required String astId,
    required AppUser supervisor,
    required Uint8List firmaSupervisor,
  }) async {
    try {
      // 1. Obtener AST actual
      final ast = await _astService.obtenerAST(astId);
      if (ast == null) {
        throw 'AST no encontrado';
      }

      // 2. Validar que el AST esté pendiente
      if (ast.estado != EstadoAST.pendiente) {
        throw 'Este AST ya fue ${ast.estado.displayName.toLowerCase()}';
      }

      // 3. Validar que el supervisor tenga permiso
      if (ast.supervisorAsignadoUid != supervisor.uid) {
        throw 'No tienes permiso para aprobar este AST';
      }

      // 4. Obtener información del técnico
      final tecnicoDoc = await _firestore
          .collection('usuarios')
          .doc(ast.tecnicoUid)
          .get();

      if (!tecnicoDoc.exists) {
        throw 'Técnico no encontrado';
      }

      final tecnico = AppUser.fromFirestore(tecnicoDoc);
      final carpetaDriveId = tecnico.carpetaDriveId;

      if (carpetaDriveId == null || carpetaDriveId.isEmpty) {
        throw 'Carpeta de Drive del técnico no encontrada';
      }

      // 5. Guardar firma del supervisor como archivo
      final firmaFile = await _almacenamientoService.guardarFirma(
        firmaSupervisor,
        'firma_supervisor_${ast.numeroMTA.replaceAll('/', '_')}_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      // 6. Subir firma del supervisor a Drive
      final firmaData = await _driveService.subirFirma(
        firmaFile: firmaFile,
        tipo: 'supervisor',
        numeroMTA: ast.numeroMTA,
        carpetaTecnicoId: carpetaDriveId,
      );

      final firmaSupervisorUrl = firmaData['url'];

      // 7. Descargar firma del técnico y foto del lugar
      String? firmaTecnicoPath;
      String? fotoLugarPath;
      String? firmaSupervisorPath = firmaFile.path;

      if (ast.firmaTecnicoUrl != null && ast.firmaTecnicoUrl!.isNotEmpty) {
        firmaTecnicoPath = await _descargarArchivo(
          ast.firmaTecnicoUrl!,
          'firma_tecnico_temp.png',
        );
      }

      if (ast.fotoLugarUrl != null && ast.fotoLugarUrl!.isNotEmpty) {
        fotoLugarPath = await _descargarArchivo(
          ast.fotoLugarUrl!,
          'foto_lugar_temp.jpg',
        );
      }

      // 8. Regenerar PDF con firma del supervisor
      final pdfFile = await _pdfService.generarPDFAST(
        ast: ast.copyWith(
          estado: EstadoAST.aprobado,
          supervisorAprobadorUid: supervisor.uid,
          supervisorAprobadorNombre: supervisor.nombre,
          fechaAprobacion: DateTime.now(),
          firmaSupervisorUrl: firmaSupervisorUrl,
        ),
        tecnico: tecnico,
        supervisor: supervisor,
        firmaTecnicoPath: firmaTecnicoPath,
        firmaSupervisorPath: firmaSupervisorPath,
        fotoLugarPath: fotoLugarPath,
      );

      // 9. Eliminar PDF antiguo de Drive si existe
      if (ast.pdfDriveId != null && ast.pdfDriveId!.isNotEmpty) {
        try {
          await _driveService.eliminarArchivo(ast.pdfDriveId!);
        } catch (e) {
          // No es crítico si falla
          print('Advertencia: No se pudo eliminar PDF antiguo: $e');
        }
      }

      // 10. Subir nuevo PDF a Drive
      final pdfData = await _driveService.subirPDFAST(
        pdfFile: pdfFile,
        numeroMTA: ast.numeroMTA,
        carpetaTecnicoId: carpetaDriveId,
      );

      // 11. Actualizar AST en Firestore usando el método del servicio
      await _astService.aprobarAST(
        astId: astId,
        supervisorUid: supervisor.uid,
        supervisorNombre: supervisor.nombre,
        firmaSupervisorUrl: firmaSupervisorUrl,
      );

      // 12. Actualizar también los campos del PDF
      await _firestore.collection('ast').doc(astId).update({
        'pdfDriveId': pdfData['id'],
        'pdfUrl': pdfData['url'],
        'pdfNombre': pdfData['nombre'],
      });

      // 13. Enviar notificación al técnico
      await _notificationService.sendNotificationToUser(
        userId: ast.tecnicoUid,
        title: '✅ AST Aprobado',
        body: 'El AST ${ast.numeroMTA} ha sido aprobado por ${supervisor.nombre}',
        data: {
          'type': 'ast_aprobado',
          'astId': astId,
          'numeroMTA': ast.numeroMTA,
          'supervisorUid': supervisor.uid,
          'supervisorNombre': supervisor.nombre,
        },
      );

      // 14. Limpiar archivos temporales
      await _limpiarArchivosTemporales([
        firmaTecnicoPath,
        fotoLugarPath,
        pdfFile.path,
      ]);
    } catch (e) {
      throw 'Error al aprobar AST: $e';
    }
  }

  /// Rechazar un AST con motivo
  ///
  /// Este método:
  /// 1. Valida que el AST esté pendiente
  /// 2. Actualiza el AST en Firestore con estado "rechazado"
  /// 3. Actualiza los contadores del técnico y supervisor
  Future<void> rechazarAST({
    required String astId,
    required AppUser supervisor,
    required String motivoRechazo,
  }) async {
    try {
      // 1. Validar motivo
      if (motivoRechazo.trim().isEmpty) {
        throw 'Debes proporcionar un motivo de rechazo';
      }

      if (motivoRechazo.trim().length < 10) {
        throw 'El motivo de rechazo debe tener al menos 10 caracteres';
      }

      // 2. Obtener AST actual
      final ast = await _astService.obtenerAST(astId);
      if (ast == null) {
        throw 'AST no encontrado';
      }

      // 3. Validar que el AST esté pendiente
      if (ast.estado != EstadoAST.pendiente) {
        throw 'Este AST ya fue ${ast.estado.displayName.toLowerCase()}';
      }

      // 4. Validar que el supervisor tenga permiso
      if (ast.supervisorAsignadoUid != supervisor.uid) {
        throw 'No tienes permiso para rechazar este AST';
      }

      // 5. Rechazar AST usando el método del servicio
      await _astService.rechazarAST(
        astId: astId,
        supervisorUid: supervisor.uid,
        motivoRechazo: motivoRechazo.trim(),
      );

      // 6. Enviar notificación al técnico
      await _notificationService.sendNotificationToUser(
        userId: ast.tecnicoUid,
        title: '❌ AST Rechazado',
        body: 'El AST ${ast.numeroMTA} fue rechazado por ${supervisor.nombre}',
        data: {
          'type': 'ast_rechazado',
          'astId': astId,
          'numeroMTA': ast.numeroMTA,
          'supervisorUid': supervisor.uid,
          'supervisorNombre': supervisor.nombre,
          'motivo': motivoRechazo.trim(),
        },
      );

      // Nota: No se regenera el PDF en caso de rechazo,
      // simplemente se actualiza el estado en Firestore
    } catch (e) {
      throw 'Error al rechazar AST: $e';
    }
  }

  /// Descargar archivo desde URL y guardarlo temporalmente
  Future<String?> _descargarArchivo(String url, String nombreArchivo) async {
    try {
      // Extraer el ID del archivo de Google Drive
      final driveId = _extraerDriveIdDeUrl(url);

      if (driveId == null) {
        print('No se pudo extraer ID de Drive de URL: $url');
        return null;
      }

      // Usar URL de descarga directa
      final downloadUrl = _driveService.obtenerURLDescarga(driveId);

      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/$nombreArchivo');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }

      return null;
    } catch (e) {
      print('Error al descargar archivo: $e');
      return null;
    }
  }

  /// Extraer ID de archivo de Google Drive desde URL
  String? _extraerDriveIdDeUrl(String url) {
    try {
      // Formatos posibles:
      // https://drive.google.com/file/d/FILE_ID/view
      // https://drive.google.com/uc?export=download&id=FILE_ID

      if (url.contains('/file/d/')) {
        final parts = url.split('/file/d/');
        if (parts.length > 1) {
          final idPart = parts[1].split('/').first;
          return idPart;
        }
      }

      if (url.contains('id=')) {
        final uri = Uri.parse(url);
        return uri.queryParameters['id'];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Limpiar archivos temporales
  Future<void> _limpiarArchivosTemporales(List<String?> paths) async {
    for (final path in paths) {
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignorar errores de limpieza
        }
      }
    }
  }

  /// Verificar si un AST puede ser aprobado/rechazado por el supervisor
  Future<bool> puedeGestionarAST({
    required String astId,
    required String supervisorUid,
  }) async {
    try {
      final ast = await _astService.obtenerAST(astId);

      if (ast == null) return false;
      if (ast.estado != EstadoAST.pendiente) return false;
      if (ast.supervisorAsignadoUid != supervisorUid) return false;

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtener estadísticas de aprobación/rechazo de un supervisor
  Future<Map<String, int>> obtenerEstadisticasSupervisor(
    String supervisorUid,
  ) async {
    try {
      final pendientesSnapshot = await _firestore
          .collection('ast')
          .where('supervisorAsignadoUid', isEqualTo: supervisorUid)
          .where('estado', isEqualTo: 'pendiente')
          .count()
          .get();

      final aprobadosSnapshot = await _firestore
          .collection('ast')
          .where('supervisorAprobadorUid', isEqualTo: supervisorUid)
          .where('estado', isEqualTo: 'aprobado')
          .count()
          .get();

      final rechazadosSnapshot = await _firestore
          .collection('ast')
          .where('supervisorAprobadorUid', isEqualTo: supervisorUid)
          .where('estado', isEqualTo: 'rechazado')
          .count()
          .get();

      return {
        'pendientes': pendientesSnapshot.count ?? 0,
        'aprobados': aprobadosSnapshot.count ?? 0,
        'rechazados': rechazadosSnapshot.count ?? 0,
      };
    } catch (e) {
      return {
        'pendientes': 0,
        'aprobados': 0,
        'rechazados': 0,
      };
    }
  }

  void dispose() {
    _driveService.dispose();
  }
}
