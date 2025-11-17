import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

class AlmacenamientoService {
  final ImagePicker _picker = ImagePicker();

  // Solicitar permiso de cámara
  Future<bool> verificarPermisoCamara() async {
    final status = await Permission.camera.status;

    if (status.isDenied) {
      final result = await Permission.camera.request();
      return result.isGranted;
    }

    if (status.isPermanentlyDenied) {
      throw 'Permiso de cámara denegado permanentemente. Por favor, habilítalo en la configuración del dispositivo.';
    }

    return status.isGranted;
  }

  // Capturar foto con la cámara
  Future<File?> capturarFoto() async {
    try {
      // Verificar permiso
      final hasPermission = await verificarPermisoCamara();
      if (!hasPermission) {
        throw 'Permiso de cámara no otorgado';
      }

      // Capturar foto
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        return File(photo.path);
      }

      return null;
    } catch (e) {
      throw 'Error al capturar foto: $e';
    }
  }

  // Seleccionar foto de la galería
  Future<File?> seleccionarFotoGaleria() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        return File(photo.path);
      }

      return null;
    } catch (e) {
      throw 'Error al seleccionar foto: $e';
    }
  }

  // Guardar firma como archivo temporal
  Future<File> guardarFirma(Uint8List firmaBytes, String nombreArchivo) async {
    try {
      // Obtener directorio temporal
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$nombreArchivo');

      // Guardar bytes en archivo
      await file.writeAsBytes(firmaBytes);

      return file;
    } catch (e) {
      throw 'Error al guardar firma: $e';
    }
  }

  // Convertir archivo a base64 (para almacenamiento temporal)
  Future<String> archivoABase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return bytes.toString();
    } catch (e) {
      throw 'Error al convertir archivo: $e';
    }
  }

  // Limpiar archivos temporales
  Future<void> limpiarTemporales() async {
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (e) {
      // Ignorar errores de limpieza
    }
  }

  // Obtener tamaño de archivo en MB
  double obtenerTamanoMB(File file) {
    try {
      final bytes = file.lengthSync();
      return bytes / (1024 * 1024);
    } catch (e) {
      return 0.0;
    }
  }

  // Verificar si el archivo es válido
  bool esArchivoValido(File? file, {double maxSizeMB = 10.0}) {
    if (file == null) return false;
    if (!file.existsSync()) return false;

    final sizeMB = obtenerTamanoMB(file);
    return sizeMB <= maxSizeMB;
  }
}
