import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ast_model.dart';

class UbicacionService {
  // Verificar y solicitar permisos de ubicación
  Future<bool> verificarPermisos() async {
    // Verificar si los servicios de ubicación están habilitados
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Los servicios de ubicación están deshabilitados. Por favor, habilítalos en la configuración.';
    }

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Permiso de ubicación denegado. La aplicación necesita acceso a tu ubicación para generar AST.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Permiso de ubicación denegado permanentemente. Por favor, habilítalo en la configuración del dispositivo.';
    }

    return true;
  }

  // Obtener ubicación actual
  Future<GPSData> obtenerUbicacion() async {
    try {
      // Verificar permisos primero
      await verificarPermisos();

      // Obtener posición actual con alta precisión
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Convertir coordenadas a dirección legible
      String direccionLegible = 'Ubicación no disponible';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          final partes = <String>[];

          if (place.street != null && place.street!.isNotEmpty) {
            partes.add(place.street!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) {
            partes.add(place.subLocality!);
          }
          if (place.locality != null && place.locality!.isNotEmpty) {
            partes.add(place.locality!);
          }
          if (place.country != null && place.country!.isNotEmpty) {
            partes.add(place.country!);
          }

          direccionLegible = partes.isNotEmpty
              ? partes.join(', ')
              : 'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
        }
      } catch (e) {
        // Si falla la conversión, usar coordenadas
        direccionLegible =
            'Lat: ${position.latitude.toStringAsFixed(6)}, Lng: ${position.longitude.toStringAsFixed(6)}';
      }

      return GPSData(
        lat: position.latitude,
        lng: position.longitude,
        direccionLegible: direccionLegible,
        precision: position.accuracy,
        timestamp: position.timestamp ?? DateTime.now(),
      );
    } on LocationServiceDisabledException {
      throw 'Los servicios de ubicación están desactivados. Por favor, actívelos.';
    } on PermissionDeniedException catch (e) {
      throw 'Permiso de ubicación denegado. Por favor, otórguelo para continuar.';
    } on TimeoutException {
      throw 'Tiempo de espera agotado al obtener ubicación. Verifica tu conexión GPS.';
    } catch (e) {
      throw 'Error al obtener ubicación: $e';
    }
  }

  // Obtener dirección desde coordenadas
  Future<String> obtenerDireccion(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final partes = <String>[];

        if (place.street != null && place.street!.isNotEmpty) {
          partes.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          partes.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          partes.add(place.locality!);
        }
        if (place.country != null && place.country!.isNotEmpty) {
          partes.add(place.country!);
        }

        return partes.isNotEmpty
            ? partes.join(', ')
            : 'Dirección no disponible';
      }

      return 'Dirección no disponible';
    } catch (e) {
      return 'Error al obtener dirección';
    }
  }

  // Verificar si la precisión es aceptable
  bool esPrecisionAceptable(double precision) {
    // Considerar aceptable si la precisión es menor a 50 metros
    return precision < 50.0;
  }

  // Obtener configuración actual de ubicación
  Future<Map<String, dynamic>> obtenerConfiguracion() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();

      return {
        'servicioHabilitado': serviceEnabled,
        'permiso': permission.toString(),
        'permisoOtorgado': permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always,
      };
    } catch (e) {
      return {
        'servicioHabilitado': false,
        'permiso': 'unknown',
        'permisoOtorgado': false,
        'error': e.toString(),
      };
    }
  }
}
