import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de notificaciones del sistema AST
enum NotificationType {
  // Notificaciones para Técnicos
  astAprobado('ast_aprobado', 'AST Aprobado'),
  astRechazado('ast_rechazado', 'AST Rechazado'),
  reasignado('reasignado', 'Reasignado a Nuevo Supervisor'),

  // Notificaciones para Supervisores
  nuevoAST('nuevo_ast', 'Nuevo AST Pendiente'),
  tecnicoCreado('tecnico_creado', 'Nuevo Técnico Asignado'),
  tecnicoReasignado('tecnico_reasignado', 'Técnico Reasignado'),

  // Notificaciones para Admins
  supervisorCreado('supervisor_creado', 'Nuevo Supervisor Registrado'),
  reasignacionCompletada('reasignacion_completada', 'Reasignación Completada'),

  // Notificaciones generales
  mensajeSistema('mensaje_sistema', 'Mensaje del Sistema'),
  recordatorio('recordatorio', 'Recordatorio');

  final String code;
  final String displayName;

  const NotificationType(this.code, this.displayName);

  static NotificationType fromCode(String code) {
    return NotificationType.values.firstWhere(
      (type) => type.code == code,
      orElse: () => NotificationType.mensajeSistema,
    );
  }
}

/// Modelo de notificación para almacenar en Firestore
///
/// Estructura de una notificación:
/// - id: ID único de la notificación
/// - userId: ID del usuario destinatario
/// - title: Título de la notificación
/// - body: Cuerpo del mensaje
/// - type: Tipo de notificación (NotificationType)
/// - data: Datos adicionales (astId, supervisorUid, etc.)
/// - delivered: Si la notificación push fue entregada exitosamente
/// - read: Si el usuario ha leído la notificación
/// - timestamp: Fecha y hora de creación
/// - readAt: Fecha y hora de lectura (opcional)
class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationType? type;
  final Map<String, dynamic> data;
  final bool delivered;
  final bool read;
  final DateTime timestamp;
  final DateTime? readAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.type,
    this.data = const {},
    this.delivered = false,
    this.read = false,
    required this.timestamp,
    this.readAt,
  });

  /// Crear desde Firestore
  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] != null
          ? NotificationType.fromCode(data['type'])
          : null,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      delivered: data['delivered'] ?? false,
      read: data['read'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readAt: data['readAt'] != null
          ? (data['readAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convertir a mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'body': body,
      'type': type?.code,
      'data': data,
      'delivered': delivered,
      'read': read,
      'timestamp': Timestamp.fromDate(timestamp),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
    };
  }

  /// CopyWith para actualizaciones
  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    NotificationType? type,
    Map<String, dynamic>? data,
    bool? delivered,
    bool? read,
    DateTime? timestamp,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      data: data ?? this.data,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
      timestamp: timestamp ?? this.timestamp,
      readAt: readAt ?? this.readAt,
    );
  }

  /// Helpers para generar notificaciones comunes

  /// Notificación de AST aprobado (para Técnico)
  static AppNotification astAprobado({
    required String tecnicoId,
    required String numeroMTA,
    required String supervisorNombre,
    required String astId,
  }) {
    return AppNotification(
      id: '',
      userId: tecnicoId,
      title: '✅ AST Aprobado',
      body: 'El AST $numeroMTA ha sido aprobado por $supervisorNombre',
      type: NotificationType.astAprobado,
      data: {
        'astId': astId,
        'numeroMTA': numeroMTA,
        'type': 'ast_aprobado',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de AST rechazado (para Técnico)
  static AppNotification astRechazado({
    required String tecnicoId,
    required String numeroMTA,
    required String supervisorNombre,
    required String motivo,
    required String astId,
  }) {
    return AppNotification(
      id: '',
      userId: tecnicoId,
      title: '❌ AST Rechazado',
      body: 'El AST $numeroMTA fue rechazado por $supervisorNombre. Motivo: $motivo',
      type: NotificationType.astRechazado,
      data: {
        'astId': astId,
        'numeroMTA': numeroMTA,
        'motivo': motivo,
        'type': 'ast_rechazado',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de nuevo AST (para Supervisor)
  static AppNotification nuevoAST({
    required String supervisorId,
    required String numeroMTA,
    required String tecnicoNombre,
    required String astId,
  }) {
    return AppNotification(
      id: '',
      userId: supervisorId,
      title: '📋 Nuevo AST Pendiente',
      body: '$tecnicoNombre ha generado un nuevo AST: $numeroMTA',
      type: NotificationType.nuevoAST,
      data: {
        'astId': astId,
        'numeroMTA': numeroMTA,
        'type': 'nuevo_ast',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de técnico reasignado (para el Técnico)
  static AppNotification tecnicoReasignado({
    required String tecnicoId,
    required String nuevoSupervisorNombre,
    required String antiguoSupervisorNombre,
    required String motivo,
  }) {
    return AppNotification(
      id: '',
      userId: tecnicoId,
      title: '🔄 Reasignación de Supervisor',
      body: 'Has sido reasignado de $antiguoSupervisorNombre a $nuevoSupervisorNombre. Motivo: $motivo',
      type: NotificationType.reasignado,
      data: {
        'nuevoSupervisor': nuevoSupervisorNombre,
        'antiguoSupervisor': antiguoSupervisorNombre,
        'motivo': motivo,
        'type': 'reasignado',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de nuevo técnico asignado (para Supervisor)
  static AppNotification nuevoTecnicoAsignado({
    required String supervisorId,
    required String tecnicoNombre,
    required String tecnicoId,
  }) {
    return AppNotification(
      id: '',
      userId: supervisorId,
      title: '👷 Nuevo Técnico Asignado',
      body: 'El técnico $tecnicoNombre ha sido asignado a tu supervisión',
      type: NotificationType.tecnicoCreado,
      data: {
        'tecnicoId': tecnicoId,
        'tecnicoNombre': tecnicoNombre,
        'type': 'tecnico_creado',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de técnico recibido por reasignación (para nuevo Supervisor)
  static AppNotification tecnicoRecibidoPorReasignacion({
    required String supervisorId,
    required String tecnicoNombre,
    required String tecnicoId,
    required String antiguoSupervisorNombre,
  }) {
    return AppNotification(
      id: '',
      userId: supervisorId,
      title: '🔄 Técnico Reasignado a Ti',
      body: '$tecnicoNombre ha sido reasignado desde $antiguoSupervisorNombre a tu supervisión',
      type: NotificationType.tecnicoReasignado,
      data: {
        'tecnicoId': tecnicoId,
        'tecnicoNombre': tecnicoNombre,
        'antiguoSupervisor': antiguoSupervisorNombre,
        'type': 'tecnico_reasignado',
      },
      timestamp: DateTime.now(),
    );
  }

  /// Notificación de nuevo supervisor creado (para Admin)
  static AppNotification supervisorCreado({
    required String adminId,
    required String supervisorNombre,
    required String supervisorId,
  }) {
    return AppNotification(
      id: '',
      userId: adminId,
      title: '👔 Nuevo Supervisor Registrado',
      body: 'Se ha registrado exitosamente al supervisor: $supervisorNombre',
      type: NotificationType.supervisorCreado,
      data: {
        'supervisorId': supervisorId,
        'supervisorNombre': supervisorNombre,
        'type': 'supervisor_creado',
      },
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'AppNotification(id: $id, userId: $userId, title: $title, type: ${type?.displayName}, read: $read)';
  }
}
