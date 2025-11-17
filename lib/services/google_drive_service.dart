import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;

class GoogleDriveService {
  // Credenciales de la cuenta de servicio
  // IMPORTANTE: Este archivo debe estar en assets/service-account.json
  static const String _serviceAccountPath = 'assets/service-account.json';

  // ID de la carpeta raíz en Drive (debe ser compartida con la cuenta de servicio)
  // Crear una carpeta llamada "AST_Mobile" en Drive y compartirla con la cuenta de servicio
  static const String _rootFolderId =
      '1ON-fizfeyks_uqEHxpPlYvdt_QEI0X3e'; // Cambiar por el ID real

  drive.DriveApi? _driveApi;

  // Inicializar cliente de Google Drive
  Future<drive.DriveApi> _getDriveApi() async {
    if (_driveApi != null) return _driveApi!;

    try {
      // Cargar credenciales de la cuenta de servicio
      final serviceAccountJson =
          await rootBundle.loadString(_serviceAccountPath);
      final accountCredentials =
          ServiceAccountCredentials.fromJson(serviceAccountJson);

      // Crear cliente autenticado
      final scopes = [drive.DriveApi.driveScope];
      final authClient =
          await clientViaServiceAccount(accountCredentials, scopes);

      _driveApi = drive.DriveApi(authClient);
      return _driveApi!;
    } catch (e) {
      throw 'Error al inicializar Google Drive: $e';
    }
  }

  // Crear carpeta para un técnico (si no existe)
  Future<String> crearCarpetaTecnico(
      String tecnicoUid, String tecnicoNombre) async {
    try {
      final driveApi = await _getDriveApi();

      // Buscar si ya existe la carpeta
      final query = "name='${_sanitizeFolderName(tecnicoNombre)}' and "
          "'$_rootFolderId' in parents and "
          "mimeType='application/vnd.google-apps.folder' and "
          "trashed=false";

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        // Carpeta ya existe
        return fileList.files!.first.id!;
      }

      // Crear nueva carpeta
      final folder = drive.File()
        ..name = _sanitizeFolderName(tecnicoNombre)
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [_rootFolderId];

      final createdFolder = await driveApi.files.create(folder);

      return createdFolder.id!;
    } catch (e) {
      throw 'Error al crear carpeta del técnico: $e';
    }
  }

  // Subir archivo a Google Drive
  Future<Map<String, String>> subirArchivo({
    required File archivo,
    required String nombreArchivo,
    required String carpetaId,
    String? mimeType,
  }) async {
    try {
      final driveApi = await _getDriveApi();

      // Crear metadata del archivo
      final driveFile = drive.File()
        ..name = nombreArchivo
        ..parents = [carpetaId];

      // Leer contenido del archivo
      final media = drive.Media(
        archivo.openRead(),
        archivo.lengthSync(),
        contentType: mimeType ?? 'application/octet-stream',
      );

      // Subir archivo
      final uploadedFile = await driveApi.files.create(
        driveFile,
        uploadMedia: media,
        $fields: 'id, name, webViewLink, webContentLink',
      );

      // Hacer el archivo público (opcional, pero recomendado para visualización)
      await _hacerArchivoPublico(driveApi, uploadedFile.id!);

      return {
        'id': uploadedFile.id!,
        'url': uploadedFile.webViewLink ?? '',
        'downloadUrl': uploadedFile.webContentLink ?? '',
        'nombre': uploadedFile.name ?? nombreArchivo,
      };
    } catch (e) {
      throw 'Error al subir archivo a Drive: $e';
    }
  }

  // Subir PDF del AST
  Future<Map<String, String>> subirPDFAST({
    required File pdfFile,
    required String numeroMTA,
    required String carpetaTecnicoId,
  }) async {
    try {
      final nombreArchivo =
          'AST_${numeroMTA.replaceAll('/', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      return await subirArchivo(
        archivo: pdfFile,
        nombreArchivo: nombreArchivo,
        carpetaId: carpetaTecnicoId,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      throw 'Error al subir PDF del AST: $e';
    }
  }

  // Subir firma
  Future<Map<String, String>> subirFirma({
    required File firmaFile,
    required String tipo, // 'tecnico' o 'supervisor'
    required String numeroMTA,
    required String carpetaTecnicoId,
  }) async {
    try {
      final nombreArchivo =
          'Firma_${tipo}_${numeroMTA.replaceAll('/', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';

      return await subirArchivo(
        archivo: firmaFile,
        nombreArchivo: nombreArchivo,
        carpetaId: carpetaTecnicoId,
        mimeType: 'image/png',
      );
    } catch (e) {
      throw 'Error al subir firma: $e';
    }
  }

  // Subir foto del lugar
  Future<Map<String, String>> subirFoto({
    required File fotoFile,
    required String numeroMTA,
    required String carpetaTecnicoId,
  }) async {
    try {
      final nombreArchivo =
          'Foto_Lugar_${numeroMTA.replaceAll('/', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      return await subirArchivo(
        archivo: fotoFile,
        nombreArchivo: nombreArchivo,
        carpetaId: carpetaTecnicoId,
        mimeType: 'image/jpeg',
      );
    } catch (e) {
      throw 'Error al subir foto: $e';
    }
  }

  // Hacer archivo público para visualización
  Future<void> _hacerArchivoPublico(
      drive.DriveApi driveApi, String fileId) async {
    try {
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';

      await driveApi.permissions.create(permission, fileId);
    } catch (e) {
      // No es crítico si falla
      print('Advertencia: No se pudo hacer público el archivo: $e');
    }
  }

  // Eliminar archivo de Drive (opcional, por si se necesita)
  Future<void> eliminarArchivo(String fileId) async {
    try {
      final driveApi = await _getDriveApi();
      await driveApi.files.delete(fileId);
    } catch (e) {
      throw 'Error al eliminar archivo: $e';
    }
  }

  // Listar archivos de una carpeta
  Future<List<drive.File>> listarArchivos(String carpetaId) async {
    try {
      final driveApi = await _getDriveApi();

      final query = "'$carpetaId' in parents and trashed=false";

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name, mimeType, createdTime, size, webViewLink)',
        orderBy: 'createdTime desc',
      );

      return fileList.files ?? [];
    } catch (e) {
      throw 'Error al listar archivos: $e';
    }
  }

  // Obtener información de un archivo
  Future<drive.File?> obtenerInfoArchivo(String fileId) async {
    try {
      final driveApi = await _getDriveApi();

      return await driveApi.files.get(
        fileId,
        $fields:
            'id, name, mimeType, size, webViewLink, webContentLink, createdTime',
      ) as drive.File;
    } catch (e) {
      return null;
    }
  }

  // Verificar si la carpeta raíz existe y es accesible
  Future<bool> verificarAccesoDrive() async {
    try {
      final driveApi = await _getDriveApi();

      await driveApi.files.get(
        _rootFolderId,
        $fields: 'id, name',
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  // Obtener URL de visualización de archivo
  String obtenerURLVisualizacion(String fileId) {
    return 'https://drive.google.com/file/d/$fileId/view';
  }

  // Obtener URL de descarga de archivo
  String obtenerURLDescarga(String fileId) {
    return 'https://drive.google.com/uc?export=download&id=$fileId';
  }

  // Sanitizar nombre de carpeta (remover caracteres no permitidos)
  String _sanitizeFolderName(String name) {
    // Remover caracteres no permitidos en nombres de carpetas de Drive
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }

  // Cerrar cliente
  void dispose() {
    _driveApi = null;
  }
}
