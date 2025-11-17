import 'package:cloud_firestore/cloud_firestore.dart';

enum EstadoAST {
  pendiente,
  aprobado,
  rechazado;

  String get displayName {
    switch (this) {
      case EstadoAST.pendiente:
        return 'Pendiente';
      case EstadoAST.aprobado:
        return 'Aprobado';
      case EstadoAST.rechazado:
        return 'Rechazado';
    }
  }
}

class GPSData {
  final double lat;
  final double lng;
  final String direccionLegible;
  final double precision;
  final DateTime timestamp;

  GPSData({
    required this.lat,
    required this.lng,
    required this.direccionLegible,
    required this.precision,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'lat': lat,
      'lng': lng,
      'direccionLegible': direccionLegible,
      'precision': precision,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory GPSData.fromMap(Map<String, dynamic> map) {
    return GPSData(
      lat: map['lat']?.toDouble() ?? 0.0,
      lng: map['lng']?.toDouble() ?? 0.0,
      direccionLegible: map['direccionLegible'] ?? '',
      precision: map['precision']?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}

class AST {
  final String id; // Documento ID en Firestore
  final String numeroMTA;
  final EstadoAST estado;

  // Técnico
  final String tecnicoUid;
  final String tecnicoNombre;
  final String tecnicoEmail;

  // Supervisor
  final String supervisorAsignadoUid;
  final String supervisorAsignadoNombre;
  final String supervisorAsignadoEmail;

  // Supervisor que aprobó (puede ser diferente si hubo reasignación)
  final String? supervisorAprobadorUid;
  final String? supervisorAprobadorNombre;

  // Fechas
  final DateTime fechaGeneracion;
  final DateTime? fechaAprobacion;
  final DateTime? fechaRechazo;

  // Ubicación
  final String direccion;
  final GPSData? gps;

  // Formulario
  final List<String> actividades;
  final List<String> tareas;
  final List<String> riesgos;
  final List<String> medidasControl;
  final String observaciones;

  // Multimedia
  final String? firmaTecnicoUrl;
  final String? fotoLugarUrl;
  final String? firmaSupervisorUrl;

  // PDF en Drive (Fase 4)
  final String? pdfDriveId;
  final String? pdfUrl;
  final String? pdfNombre;

  // Rechazo
  final String? motivoRechazo;

  // Metadata
  final int version;
  final String? dispositivoGeneracion;

  AST({
    required this.id,
    required this.numeroMTA,
    required this.estado,
    required this.tecnicoUid,
    required this.tecnicoNombre,
    required this.tecnicoEmail,
    required this.supervisorAsignadoUid,
    required this.supervisorAsignadoNombre,
    required this.supervisorAsignadoEmail,
    this.supervisorAprobadorUid,
    this.supervisorAprobadorNombre,
    required this.fechaGeneracion,
    this.fechaAprobacion,
    this.fechaRechazo,
    required this.direccion,
    this.gps,
    required this.actividades,
    required this.tareas,
    required this.riesgos,
    required this.medidasControl,
    required this.observaciones,
    this.firmaTecnicoUrl,
    this.fotoLugarUrl,
    this.firmaSupervisorUrl,
    this.pdfDriveId,
    this.pdfUrl,
    this.pdfNombre,
    this.motivoRechazo,
    this.version = 1,
    this.dispositivoGeneracion,
  });

  factory AST.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return AST(
      id: doc.id,
      numeroMTA: data['numeroMTA'] ?? '',
      estado: EstadoAST.values.firstWhere(
        (e) => e.name == data['estado'],
        orElse: () => EstadoAST.pendiente,
      ),
      tecnicoUid: data['tecnicoUid'] ?? '',
      tecnicoNombre: data['tecnicoNombre'] ?? '',
      tecnicoEmail: data['tecnicoEmail'] ?? '',
      supervisorAsignadoUid: data['supervisorAsignadoUid'] ?? '',
      supervisorAsignadoNombre: data['supervisorAsignadoNombre'] ?? '',
      supervisorAsignadoEmail: data['supervisorAsignadoEmail'] ?? '',
      supervisorAprobadorUid: data['supervisorAprobadorUid'],
      supervisorAprobadorNombre: data['supervisorAprobadorNombre'],
      fechaGeneracion: (data['fechaGeneracion'] as Timestamp).toDate(),
      fechaAprobacion: data['fechaAprobacion'] != null
          ? (data['fechaAprobacion'] as Timestamp).toDate()
          : null,
      fechaRechazo: data['fechaRechazo'] != null
          ? (data['fechaRechazo'] as Timestamp).toDate()
          : null,
      direccion: data['direccion'] ?? '',
      gps: data['gps'] != null ? GPSData.fromMap(data['gps']) : null,
      actividades: List<String>.from(data['actividades'] ?? []),
      tareas: List<String>.from(data['tareas'] ?? []),
      riesgos: List<String>.from(data['riesgos'] ?? []),
      medidasControl: List<String>.from(data['medidasControl'] ?? []),
      observaciones: data['observaciones'] ?? '',
      firmaTecnicoUrl: data['firmaTecnicoUrl'],
      fotoLugarUrl: data['fotoLugarUrl'],
      firmaSupervisorUrl: data['firmaSupervisorUrl'],
      pdfDriveId: data['pdfDriveId'],
      pdfUrl: data['pdfUrl'],
      pdfNombre: data['pdfNombre'],
      motivoRechazo: data['motivoRechazo'],
      version: data['version'] ?? 1,
      dispositivoGeneracion: data['dispositivoGeneracion'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'numeroMTA': numeroMTA,
      'estado': estado.name,
      'tecnicoUid': tecnicoUid,
      'tecnicoNombre': tecnicoNombre,
      'tecnicoEmail': tecnicoEmail,
      'supervisorAsignadoUid': supervisorAsignadoUid,
      'supervisorAsignadoNombre': supervisorAsignadoNombre,
      'supervisorAsignadoEmail': supervisorAsignadoEmail,
      'supervisorAprobadorUid': supervisorAprobadorUid,
      'supervisorAprobadorNombre': supervisorAprobadorNombre,
      'fechaGeneracion': Timestamp.fromDate(fechaGeneracion),
      'fechaAprobacion': fechaAprobacion != null
          ? Timestamp.fromDate(fechaAprobacion!)
          : null,
      'fechaRechazo':
          fechaRechazo != null ? Timestamp.fromDate(fechaRechazo!) : null,
      'direccion': direccion,
      'gps': gps?.toMap(),
      'actividades': actividades,
      'tareas': tareas,
      'riesgos': riesgos,
      'medidasControl': medidasControl,
      'observaciones': observaciones,
      'firmaTecnicoUrl': firmaTecnicoUrl,
      'fotoLugarUrl': fotoLugarUrl,
      'firmaSupervisorUrl': firmaSupervisorUrl,
      'pdfDriveId': pdfDriveId,
      'pdfUrl': pdfUrl,
      'pdfNombre': pdfNombre,
      'motivoRechazo': motivoRechazo,
      'version': version,
      'dispositivoGeneracion': dispositivoGeneracion,
    };
  }

  AST copyWith({
    String? id,
    String? numeroMTA,
    EstadoAST? estado,
    DateTime? fechaAprobacion,
    DateTime? fechaRechazo,
    String? supervisorAprobadorUid,
    String? supervisorAprobadorNombre,
    String? firmaSupervisorUrl,
    String? motivoRechazo,
    String? pdfDriveId,
    String? pdfUrl,
    String? pdfNombre,
  }) {
    return AST(
      id: id ?? this.id,
      numeroMTA: numeroMTA ?? this.numeroMTA,
      estado: estado ?? this.estado,
      tecnicoUid: tecnicoUid,
      tecnicoNombre: tecnicoNombre,
      tecnicoEmail: tecnicoEmail,
      supervisorAsignadoUid: supervisorAsignadoUid,
      supervisorAsignadoNombre: supervisorAsignadoNombre,
      supervisorAsignadoEmail: supervisorAsignadoEmail,
      supervisorAprobadorUid: supervisorAprobadorUid ?? this.supervisorAprobadorUid,
      supervisorAprobadorNombre:
          supervisorAprobadorNombre ?? this.supervisorAprobadorNombre,
      fechaGeneracion: fechaGeneracion,
      fechaAprobacion: fechaAprobacion ?? this.fechaAprobacion,
      fechaRechazo: fechaRechazo ?? this.fechaRechazo,
      direccion: direccion,
      gps: gps,
      actividades: actividades,
      tareas: tareas,
      riesgos: riesgos,
      medidasControl: medidasControl,
      observaciones: observaciones,
      firmaTecnicoUrl: firmaTecnicoUrl,
      fotoLugarUrl: fotoLugarUrl,
      firmaSupervisorUrl: firmaSupervisorUrl ?? this.firmaSupervisorUrl,
      pdfDriveId: pdfDriveId ?? this.pdfDriveId,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      pdfNombre: pdfNombre ?? this.pdfNombre,
      motivoRechazo: motivoRechazo ?? this.motivoRechazo,
      version: version,
      dispositivoGeneracion: dispositivoGeneracion,
    );
  }
}
