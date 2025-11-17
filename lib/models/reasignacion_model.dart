import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo para el historial de reasignaciones de técnicos
class Reasignacion {
  final String id; // ID del documento en Firestore
  final String tecnicoUid;
  final String tecnicoNombre;
  final String tecnicoEmail;

  // Supervisor anterior
  final String supervisorAnteriorUid;
  final String supervisorAnteriorNombre;
  final String supervisorAnteriorEmail;

  // Supervisor nuevo
  final String supervisorNuevoUid;
  final String supervisorNuevoNombre;
  final String supervisorNuevoEmail;

  // Admin que realizó la reasignación
  final String adminUid;
  final String adminNombre;

  // Fechas
  final DateTime fechaReasignacion;

  // Estadísticas al momento de la reasignación
  final int astPendientesReasignados;
  final int totalASTDelTecnico;

  // Motivo (opcional)
  final String? motivo;

  Reasignacion({
    required this.id,
    required this.tecnicoUid,
    required this.tecnicoNombre,
    required this.tecnicoEmail,
    required this.supervisorAnteriorUid,
    required this.supervisorAnteriorNombre,
    required this.supervisorAnteriorEmail,
    required this.supervisorNuevoUid,
    required this.supervisorNuevoNombre,
    required this.supervisorNuevoEmail,
    required this.adminUid,
    required this.adminNombre,
    required this.fechaReasignacion,
    required this.astPendientesReasignados,
    required this.totalASTDelTecnico,
    this.motivo,
  });

  // Crear desde Firestore
  factory Reasignacion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Reasignacion(
      id: doc.id,
      tecnicoUid: data['tecnicoUid'] ?? '',
      tecnicoNombre: data['tecnicoNombre'] ?? '',
      tecnicoEmail: data['tecnicoEmail'] ?? '',
      supervisorAnteriorUid: data['supervisorAnteriorUid'] ?? '',
      supervisorAnteriorNombre: data['supervisorAnteriorNombre'] ?? '',
      supervisorAnteriorEmail: data['supervisorAnteriorEmail'] ?? '',
      supervisorNuevoUid: data['supervisorNuevoUid'] ?? '',
      supervisorNuevoNombre: data['supervisorNuevoNombre'] ?? '',
      supervisorNuevoEmail: data['supervisorNuevoEmail'] ?? '',
      adminUid: data['adminUid'] ?? '',
      adminNombre: data['adminNombre'] ?? '',
      fechaReasignacion: (data['fechaReasignacion'] as Timestamp).toDate(),
      astPendientesReasignados: data['astPendientesReasignados'] ?? 0,
      totalASTDelTecnico: data['totalASTDelTecnico'] ?? 0,
      motivo: data['motivo'],
    );
  }

  // Convertir a mapa para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'tecnicoUid': tecnicoUid,
      'tecnicoNombre': tecnicoNombre,
      'tecnicoEmail': tecnicoEmail,
      'supervisorAnteriorUid': supervisorAnteriorUid,
      'supervisorAnteriorNombre': supervisorAnteriorNombre,
      'supervisorAnteriorEmail': supervisorAnteriorEmail,
      'supervisorNuevoUid': supervisorNuevoUid,
      'supervisorNuevoNombre': supervisorNuevoNombre,
      'supervisorNuevoEmail': supervisorNuevoEmail,
      'adminUid': adminUid,
      'adminNombre': adminNombre,
      'fechaReasignacion': Timestamp.fromDate(fechaReasignacion),
      'astPendientesReasignados': astPendientesReasignados,
      'totalASTDelTecnico': totalASTDelTecnico,
      'motivo': motivo,
    };
  }
}

/// Modelo para el historial de supervisores de un técnico (en el documento del usuario)
class HistorialSupervisor {
  final String supervisorUid;
  final String supervisorNombre;
  final DateTime fechaAsignacion;
  final DateTime? fechaReasignacion;
  final String? reasignadoPor; // UID del admin que hizo la reasignación
  final String? motivo;

  HistorialSupervisor({
    required this.supervisorUid,
    required this.supervisorNombre,
    required this.fechaAsignacion,
    this.fechaReasignacion,
    this.reasignadoPor,
    this.motivo,
  });

  // Crear desde mapa
  factory HistorialSupervisor.fromMap(Map<String, dynamic> map) {
    return HistorialSupervisor(
      supervisorUid: map['supervisorUid'] ?? '',
      supervisorNombre: map['supervisorNombre'] ?? '',
      fechaAsignacion: (map['fechaAsignacion'] as Timestamp).toDate(),
      fechaReasignacion: map['fechaReasignacion'] != null
          ? (map['fechaReasignacion'] as Timestamp).toDate()
          : null,
      reasignadoPor: map['reasignadoPor'],
      motivo: map['motivo'],
    );
  }

  // Convertir a mapa para Firestore
  Map<String, dynamic> toMap() {
    return {
      'supervisorUid': supervisorUid,
      'supervisorNombre': supervisorNombre,
      'fechaAsignacion': Timestamp.fromDate(fechaAsignacion),
      'fechaReasignacion': fechaReasignacion != null
          ? Timestamp.fromDate(fechaReasignacion!)
          : null,
      'reasignadoPor': reasignadoPor,
      'motivo': motivo,
    };
  }
}
