import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/notification_model.dart';

/// Servicio para gestionar notificaciones push con Firebase Cloud Messaging
///
/// Responsabilidades:
/// - Inicializar y configurar FCM
/// - Manejar tokens de dispositivos
/// - Enviar notificaciones a usuarios específicos
/// - Gestionar notificaciones en foreground/background
/// - Almacenar historial de notificaciones en Firestore
class NotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Controller para notificaciones recibidas en foreground
  final _notificationStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get notificationStream => _notificationStreamController.stream;

  // Singleton pattern
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Inicializa el servicio de notificaciones
  /// Solicita permisos y configura handlers
  Future<void> initialize() async {
    try {
      // Solicitar permisos de notificación (iOS y Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permisos de notificación otorgados');
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('⚠️ Permisos de notificación provisionales');
      } else {
        debugPrint('❌ Permisos de notificación denegados');
        return;
      }

      // Configurar handlers de mensajes
      _setupMessageHandlers();

      debugPrint('✅ Servicio de notificaciones inicializado');
    } catch (e) {
      debugPrint('❌ Error al inicializar notificaciones: $e');
    }
  }

  /// Configura los handlers para diferentes estados de la app
  void _setupMessageHandlers() {
    // Foreground: App abierta y en uso
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📱 Notificación recibida en foreground');
      debugPrint('Título: ${message.notification?.title}');
      debugPrint('Cuerpo: ${message.notification?.body}');
      debugPrint('Data: ${message.data}');

      // Emitir a través del stream para que la UI pueda reaccionar
      _notificationStreamController.add(message);

      // Guardar en historial
      _saveNotificationToHistory(message);
    });

    // Background: App en segundo plano pero no cerrada
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📱 Notificación abierta desde background');
      debugPrint('Data: ${message.data}');

      // Navegar a la pantalla correspondiente según el tipo
      _handleNotificationNavigation(message);
    });

    // Terminated: App completamente cerrada
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📱 App abierta desde notificación (terminated)');
        debugPrint('Data: ${message.data}');

        // Navegar a la pantalla correspondiente
        _handleNotificationNavigation(message);
      }
    });
  }

  /// Obtiene el token FCM del dispositivo actual
  /// Retorna null si no se pudo obtener
  Future<String?> getDeviceToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token obtenido: ${token.substring(0, 20)}...');
      }
      return token;
    } catch (e) {
      debugPrint('❌ Error al obtener FCM token: $e');
      return null;
    }
  }

  /// Actualiza el FCM token del usuario en Firestore
  Future<void> updateUserToken(String userId) async {
    try {
      final token = await getDeviceToken();
      if (token == null) {
        debugPrint('⚠️ No se pudo obtener el token FCM');
        return;
      }

      await _firestore.collection('usuarios').doc(userId).update({
        'fcmToken': token,
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Token FCM actualizado para usuario: $userId');

      // Listener para cuando el token se refresca
      _messaging.onTokenRefresh.listen((newToken) {
        _firestore.collection('usuarios').doc(userId).update({
          'fcmToken': newToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('🔄 Token FCM refrescado para usuario: $userId');
      });
    } catch (e) {
      debugPrint('❌ Error al actualizar token del usuario: $e');
    }
  }

  /// Envía una notificación a un usuario específico
  ///
  /// Parámetros:
  /// - userId: ID del usuario destinatario
  /// - title: Título de la notificación
  /// - body: Cuerpo del mensaje
  /// - data: Datos adicionales (tipo, astId, etc.)
  /// - priority: Prioridad (high/normal)
  Future<bool> sendNotificationToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String priority = 'high',
  }) async {
    try {
      // Obtener el token FCM del usuario
      final userDoc = await _firestore.collection('usuarios').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ Usuario no encontrado: $userId');
        return false;
      }

      final userData = userDoc.data()!;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('⚠️ Usuario sin token FCM: $userId');

        // Guardar notificación en Firestore aunque no se pueda enviar push
        await _saveNotificationToFirestore(
          userId: userId,
          title: title,
          body: body,
          data: data,
          delivered: false,
        );

        return false;
      }

      // Enviar notificación vía FCM
      final sent = await _sendFCMNotification(
        token: fcmToken,
        title: title,
        body: body,
        data: data ?? {},
        priority: priority,
      );

      // Guardar en Firestore
      await _saveNotificationToFirestore(
        userId: userId,
        title: title,
        body: body,
        data: data,
        delivered: sent,
      );

      return sent;
    } catch (e) {
      debugPrint('❌ Error al enviar notificación: $e');
      return false;
    }
  }

  /// Envía notificaciones a múltiples usuarios
  Future<Map<String, bool>> sendNotificationToMultipleUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final results = <String, bool>{};

    for (final userId in userIds) {
      final sent = await sendNotificationToUser(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
      results[userId] = sent;
    }

    return results;
  }

  /// Envía la notificación FCM real usando la API de Firebase
  /// Nota: En producción, esto debería hacerse desde Cloud Functions
  /// para mayor seguridad (no exponer la Server Key)
  Future<bool> _sendFCMNotification({
    required String token,
    required String title,
    required String body,
    required Map<String, dynamic> data,
    required String priority,
  }) async {
    try {
      // NOTA IMPORTANTE:
      // En producción, esto debe moverse a Cloud Functions
      // Aquí se usa la API legacy de FCM, pero se recomienda usar
      // Firebase Admin SDK desde el backend

      debugPrint('📤 Enviando notificación FCM...');
      debugPrint('   Título: $title');
      debugPrint('   Destinatario: ${token.substring(0, 20)}...');

      // Por ahora, simulamos el envío exitoso
      // En producción real, se haría con Cloud Functions:
      /*
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=YOUR_SERVER_KEY', // NO hacer esto en producción
        },
        body: jsonEncode({
          'to': token,
          'priority': priority,
          'notification': {
            'title': title,
            'body': body,
            'sound': 'default',
            'badge': '1',
          },
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Notificación enviada exitosamente');
        return true;
      } else {
        debugPrint('❌ Error al enviar: ${response.body}');
        return false;
      }
      */

      // Simulación para desarrollo
      await Future.delayed(const Duration(milliseconds: 100));
      debugPrint('✅ Notificación FCM simulada exitosamente');
      return true;
    } catch (e) {
      debugPrint('❌ Error en _sendFCMNotification: $e');
      return false;
    }
  }

  /// Guarda la notificación en Firestore para historial
  Future<void> _saveNotificationToFirestore({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    required bool delivered,
  }) async {
    try {
      final notification = AppNotification(
        id: '', // Firestore asignará el ID
        userId: userId,
        title: title,
        body: body,
        data: data ?? {},
        delivered: delivered,
        read: false,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('notificaciones').add(notification.toFirestore());
      debugPrint('💾 Notificación guardada en Firestore');
    } catch (e) {
      debugPrint('❌ Error al guardar notificación: $e');
    }
  }

  /// Guarda notificación recibida en el historial
  Future<void> _saveNotificationToHistory(RemoteMessage message) async {
    try {
      // Extraer userId de los datos del mensaje
      final userId = message.data['userId'] as String?;
      if (userId == null) return;

      final notification = AppNotification(
        id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        title: message.notification?.title ?? 'Notificación',
        body: message.notification?.body ?? '',
        data: message.data,
        delivered: true,
        read: false,
        timestamp: DateTime.now(),
      );

      await _firestore.collection('notificaciones').doc(notification.id).set(
        notification.toFirestore(),
      );
    } catch (e) {
      debugPrint('❌ Error al guardar notificación en historial: $e');
    }
  }

  /// Maneja la navegación cuando se toca una notificación
  void _handleNotificationNavigation(RemoteMessage message) {
    // Este método será llamado desde main.dart donde tenemos acceso al Navigator
    // Por ahora solo registramos el evento
    debugPrint('🔔 Navegación solicitada para: ${message.data['type']}');
  }

  /// Marca una notificación como leída
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection('notificaciones').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Notificación marcada como leída: $notificationId');
    } catch (e) {
      debugPrint('❌ Error al marcar notificación: $e');
    }
  }

  /// Obtiene el stream de notificaciones no leídas de un usuario
  Stream<List<AppNotification>> getUnreadNotifications(String userId) {
    return _firestore
        .collection('notificaciones')
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    });
  }

  /// Obtiene todas las notificaciones de un usuario (con paginación)
  Future<List<AppNotification>> getUserNotifications({
    required String userId,
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    try {
      Query query = _firestore
          .collection('notificaciones')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error al obtener notificaciones: $e');
      return [];
    }
  }

  /// Elimina el token FCM del usuario (al hacer logout)
  Future<void> removeUserToken(String userId) async {
    try {
      await _messaging.deleteToken();
      await _firestore.collection('usuarios').doc(userId).update({
        'fcmToken': FieldValue.delete(),
      });
      debugPrint('🗑️ Token FCM eliminado para usuario: $userId');
    } catch (e) {
      debugPrint('❌ Error al eliminar token: $e');
    }
  }

  /// Limpia recursos
  void dispose() {
    _notificationStreamController.close();
  }
}

// Handler de notificaciones en background (debe ser top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('📱 Notificación recibida en background');
  debugPrint('Mensaje: ${message.notification?.title}');

  // Aquí se puede procesar la notificación en background
  // Por ejemplo, actualizar base de datos local, etc.
}
