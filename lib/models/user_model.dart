import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  supervisor,
  tecnico;

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Administrador';
      case UserRole.supervisor:
        return 'Supervisor';
      case UserRole.tecnico:
        return 'Técnico';
    }
  }
}

class AppUser {
  final String uid;
  final String nombre;
  final String email;
  final String telefono;
  final UserRole rol;
  final String? supervisorUid;
  final String? carpetaDriveId;
  final bool activo;
  final String? creadoPor;
  final DateTime fechaRegistro;
  final DateTime? fechaEliminacion;
  final DateTime? ultimoLogin;
  final String? fcmToken;

  // Estadísticas específicas por rol
  final int? totalSupervisoresCreados; // Admin
  final int? totalTecnicosEnSistema; // Admin
  final int? totalTecnicosCreados; // Supervisor
  final int? totalTecnicosActivos; // Supervisor
  final int? totalTecnicosInactivos; // Supervisor
  final int? totalASTAprobados; // Supervisor
  final int? totalASTRechazados; // Supervisor
  final int? totalASTGenerados; // Técnico
  final int? totalASTPendientes; // Técnico

  AppUser({
    required this.uid,
    required this.nombre,
    required this.email,
    required this.telefono,
    required this.rol,
    this.supervisorUid,
    this.carpetaDriveId,
    required this.activo,
    this.creadoPor,
    required this.fechaRegistro,
    this.fechaEliminacion,
    this.ultimoLogin,
    this.fcmToken,
    this.totalSupervisoresCreados,
    this.totalTecnicosEnSistema,
    this.totalTecnicosCreados,
    this.totalTecnicosActivos,
    this.totalTecnicosInactivos,
    this.totalASTAprobados,
    this.totalASTRechazados,
    this.totalASTGenerados,
    this.totalASTPendientes,
  });

  // Crear desde Firestore
  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return AppUser(
      uid: doc.id,
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      telefono: data['telefono'] ?? '',
      rol: UserRole.values.firstWhere(
        (e) => e.name == data['rol'],
        orElse: () => UserRole.tecnico,
      ),
      supervisorUid: data['supervisorUid'],
      carpetaDriveId: data['carpetaDriveId'],
      activo: data['activo'] ?? true,
      creadoPor: data['creadoPor'],
      fechaRegistro: (data['fechaRegistro'] as Timestamp).toDate(),
      fechaEliminacion: data['fechaEliminacion'] != null
          ? (data['fechaEliminacion'] as Timestamp).toDate()
          : null,
      ultimoLogin: data['ultimoLogin'] != null
          ? (data['ultimoLogin'] as Timestamp).toDate()
          : null,
      fcmToken: data['fcmToken'],
      totalSupervisoresCreados: data['totalSupervisoresCreados'],
      totalTecnicosEnSistema: data['totalTecnicosEnSistema'],
      totalTecnicosCreados: data['totalTecnicosCreados'],
      totalTecnicosActivos: data['totalTecnicosActivos'],
      totalTecnicosInactivos: data['totalTecnicosInactivos'],
      totalASTAprobados: data['totalASTAprobados'],
      totalASTRechazados: data['totalASTRechazados'],
      totalASTGenerados: data['totalASTGenerados'],
      totalASTPendientes: data['totalASTPendientes'],
    );
  }

  // Convertir a mapa para Firestore
  Map<String, dynamic> toFirestore() {
    final map = {
      'uid': uid,
      'nombre': nombre,
      'email': email,
      'telefono': telefono,
      'rol': rol.name,
      'supervisorUid': supervisorUid,
      'carpetaDriveId': carpetaDriveId,
      'activo': activo,
      'creadoPor': creadoPor,
      'fechaRegistro': Timestamp.fromDate(fechaRegistro),
      'fechaEliminacion': fechaEliminacion != null
          ? Timestamp.fromDate(fechaEliminacion!)
          : null,
      'ultimoLogin': ultimoLogin != null
          ? Timestamp.fromDate(ultimoLogin!)
          : null,
      'fcmToken': fcmToken,
    };

    // Agregar estadísticas según el rol
    if (rol == UserRole.admin) {
      map['totalSupervisoresCreados'] = totalSupervisoresCreados ?? 0;
      map['totalTecnicosEnSistema'] = totalTecnicosEnSistema ?? 0;
    } else if (rol == UserRole.supervisor) {
      map['totalTecnicosCreados'] = totalTecnicosCreados ?? 0;
      map['totalTecnicosActivos'] = totalTecnicosActivos ?? 0;
      map['totalTecnicosInactivos'] = totalTecnicosInactivos ?? 0;
      map['totalASTAprobados'] = totalASTAprobados ?? 0;
      map['totalASTRechazados'] = totalASTRechazados ?? 0;
    } else if (rol == UserRole.tecnico) {
      map['totalASTGenerados'] = totalASTGenerados ?? 0;
      map['totalASTPendientes'] = totalASTPendientes ?? 0;
      map['totalASTAprobados'] = totalASTAprobados ?? 0;
      map['totalASTRechazados'] = totalASTRechazados ?? 0;
    }

    return map;
  }

  // CopyWith para actualizaciones
  AppUser copyWith({
    String? nombre,
    String? email,
    String? telefono,
    String? supervisorUid,
    String? carpetaDriveId,
    bool? activo,
    DateTime? fechaEliminacion,
    DateTime? ultimoLogin,
    String? fcmToken,
    int? totalSupervisoresCreados,
    int? totalTecnicosEnSistema,
    int? totalTecnicosCreados,
    int? totalTecnicosActivos,
    int? totalTecnicosInactivos,
    int? totalASTAprobados,
    int? totalASTRechazados,
    int? totalASTGenerados,
    int? totalASTPendientes,
  }) {
    return AppUser(
      uid: uid,
      nombre: nombre ?? this.nombre,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      rol: rol,
      supervisorUid: supervisorUid ?? this.supervisorUid,
      carpetaDriveId: carpetaDriveId ?? this.carpetaDriveId,
      activo: activo ?? this.activo,
      creadoPor: creadoPor,
      fechaRegistro: fechaRegistro,
      fechaEliminacion: fechaEliminacion ?? this.fechaEliminacion,
      ultimoLogin: ultimoLogin ?? this.ultimoLogin,
      fcmToken: fcmToken ?? this.fcmToken,
      totalSupervisoresCreados: totalSupervisoresCreados ?? this.totalSupervisoresCreados,
      totalTecnicosEnSistema: totalTecnicosEnSistema ?? this.totalTecnicosEnSistema,
      totalTecnicosCreados: totalTecnicosCreados ?? this.totalTecnicosCreados,
      totalTecnicosActivos: totalTecnicosActivos ?? this.totalTecnicosActivos,
      totalTecnicosInactivos: totalTecnicosInactivos ?? this.totalTecnicosInactivos,
      totalASTAprobados: totalASTAprobados ?? this.totalASTAprobados,
      totalASTRechazados: totalASTRechazados ?? this.totalASTRechazados,
      totalASTGenerados: totalASTGenerados ?? this.totalASTGenerados,
      totalASTPendientes: totalASTPendientes ?? this.totalASTPendientes,
    );
  }
}
