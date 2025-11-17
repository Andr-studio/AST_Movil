import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/ast_model.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class ASTService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  // Generar número MTA automático
  Future<String> generarNumeroMTA() async {
    try {
      final now = DateTime.now();
      final year =
          now.year.toString().substring(2); // Últimos 2 dígitos del año

      // Contar AST del año actual
      final startOfYear = DateTime(now.year, 1, 1);
      final count = await _firestore
          .collection('ast')
          .where('fechaGeneracion',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYear))
          .count()
          .get();

      final numero = (count.count ?? 0) + 1;
      final numeroMTA = 'MTA$year/${numero.toString().padLeft(3, '0')}';

      return numeroMTA;
    } catch (e) {
      throw 'Error al generar número MTA: $e';
    }
  }

  // Crear AST
  Future<String> crearAST({
    required AppUser tecnico,
    required AppUser supervisor,
    required String direccion,
    required GPSData? gps,
    required List<String> actividades,
    required List<String> tareas,
    required List<String> riesgos,
    required List<String> medidasControl,
    required String observaciones,
    required String firmaTecnicoUrl,
    required String? fotoLugarUrl,
    String? dispositivoGeneracion,
  }) async {
    try {
      // Generar número MTA
      final numeroMTA = await generarNumeroMTA();
      final docId = numeroMTA.replaceAll('/', '');

      // Crear documento AST
      final ast = AST(
        id: docId,
        numeroMTA: numeroMTA,
        estado: EstadoAST.pendiente,
        tecnicoUid: tecnico.uid,
        tecnicoNombre: tecnico.nombre,
        tecnicoEmail: tecnico.email,
        supervisorAsignadoUid: supervisor.uid,
        supervisorAsignadoNombre: supervisor.nombre,
        supervisorAsignadoEmail: supervisor.email,
        fechaGeneracion: DateTime.now(),
        direccion: direccion,
        gps: gps,
        actividades: actividades,
        tareas: tareas,
        riesgos: riesgos,
        medidasControl: medidasControl,
        observaciones: observaciones,
        firmaTecnicoUrl: firmaTecnicoUrl,
        fotoLugarUrl: fotoLugarUrl,
        dispositivoGeneracion:
            dispositivoGeneracion ?? Platform.operatingSystem,
      );

      // Guardar en Firestore
      await _firestore.collection('ast').doc(docId).set(ast.toFirestore());

      // Actualizar contadores del técnico
      await _firestore.collection('usuarios').doc(tecnico.uid).update({
        'totalASTGenerados': FieldValue.increment(1),
        'totalASTPendientes': FieldValue.increment(1),
      });

      // Actualizar colección tecnicosPorSupervisor
      await _firestore
          .collection('tecnicosPorSupervisor')
          .doc(supervisor.uid)
          .update({
        'tecnicos.${tecnico.uid}.totalAST': FieldValue.increment(1),
        'tecnicos.${tecnico.uid}.ultimoAST': FieldValue.serverTimestamp(),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      // Enviar notificación al supervisor sobre el nuevo AST
      await _notificationService.sendNotificationToUser(
        userId: supervisor.uid,
        title: '📋 Nuevo AST Pendiente',
        body: '${tecnico.nombre} ha generado un nuevo AST: $numeroMTA',
        data: {
          'type': 'nuevo_ast',
          'astId': docId,
          'numeroMTA': numeroMTA,
          'tecnicoUid': tecnico.uid,
          'tecnicoNombre': tecnico.nombre,
        },
      );

      return docId;
    } catch (e) {
      throw 'Error al crear AST: $e';
    }
  }

  // Obtener AST de un técnico
  Stream<QuerySnapshot> obtenerASTTecnico(String tecnicoUid) {
    return _firestore
        .collection('ast')
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .orderBy('fechaGeneracion', descending: true)
        .snapshots();
  }

  // Obtener AST pendientes de un técnico
  Stream<QuerySnapshot> obtenerASTPendientesTecnico(String tecnicoUid) {
    return _firestore
        .collection('ast')
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('fechaGeneracion', descending: true)
        .snapshots();
  }

  // Obtener AST aprobados de un técnico
  Stream<QuerySnapshot> obtenerASTAprobadosTecnico(String tecnicoUid) {
    return _firestore
        .collection('ast')
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .where('estado', isEqualTo: 'aprobado')
        .orderBy('fechaGeneracion', descending: true)
        .snapshots();
  }

  // Obtener AST rechazados de un técnico
  Stream<QuerySnapshot> obtenerASTRechazadosTecnico(String tecnicoUid) {
    return _firestore
        .collection('ast')
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .where('estado', isEqualTo: 'rechazado')
        .orderBy('fechaGeneracion', descending: true)
        .snapshots();
  }

  // Obtener AST pendientes de un supervisor (Fase 6)
  Stream<QuerySnapshot> obtenerASTPendientesSupervisor(String supervisorUid) {
    return _firestore
        .collection('ast')
        .where('supervisorAsignadoUid', isEqualTo: supervisorUid)
        .where('estado', isEqualTo: 'pendiente')
        .orderBy('fechaGeneracion', descending: true)
        .snapshots();
  }

  // Obtener un AST específico
  Future<AST?> obtenerAST(String astId) async {
    try {
      final doc = await _firestore.collection('ast').doc(astId).get();
      if (doc.exists) {
        return AST.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw 'Error al obtener AST: $e';
    }
  }

  // Contar AST por estado de un técnico
  Future<Map<String, int>> contarASTTecnico(String tecnicoUid) async {
    try {
      final totalSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .count()
          .get();

      final pendientesSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .where('estado', isEqualTo: 'pendiente')
          .count()
          .get();

      final aprobadosSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .where('estado', isEqualTo: 'aprobado')
          .count()
          .get();

      final rechazadosSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .where('estado', isEqualTo: 'rechazado')
          .count()
          .get();

      return {
        'total': totalSnapshot.count ?? 0,
        'pendientes': pendientesSnapshot.count ?? 0,
        'aprobados': aprobadosSnapshot.count ?? 0,
        'rechazados': rechazadosSnapshot.count ?? 0,
      };
    } catch (e) {
      return {
        'total': 0,
        'pendientes': 0,
        'aprobados': 0,
        'rechazados': 0,
      };
    }
  }

  // Aprobar AST (Fase 6)
  Future<void> aprobarAST({
    required String astId,
    required String supervisorUid,
    required String supervisorNombre,
    required String firmaSupervisorUrl,
  }) async {
    try {
      final batch = _firestore.batch();

      // Obtener AST actual
      final astDoc = await _firestore.collection('ast').doc(astId).get();
      if (!astDoc.exists) throw 'AST no encontrado';

      final ast = AST.fromFirestore(astDoc);

      // Actualizar AST
      batch.update(
        _firestore.collection('ast').doc(astId),
        {
          'estado': 'aprobado',
          'fechaAprobacion': FieldValue.serverTimestamp(),
          'supervisorAprobadorUid': supervisorUid,
          'supervisorAprobadorNombre': supervisorNombre,
          'firmaSupervisorUrl': firmaSupervisorUrl,
        },
      );

      // Actualizar contadores del técnico
      batch.update(
        _firestore.collection('usuarios').doc(ast.tecnicoUid),
        {
          'totalASTPendientes': FieldValue.increment(-1),
          'totalASTAprobados': FieldValue.increment(1),
        },
      );

      // Actualizar contadores del supervisor
      batch.update(
        _firestore.collection('usuarios').doc(supervisorUid),
        {
          'totalASTAprobados': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al aprobar AST: $e';
    }
  }

  // Rechazar AST (Fase 6)
  Future<void> rechazarAST({
    required String astId,
    required String supervisorUid,
    required String motivoRechazo,
  }) async {
    try {
      final batch = _firestore.batch();

      // Obtener AST actual
      final astDoc = await _firestore.collection('ast').doc(astId).get();
      if (!astDoc.exists) throw 'AST no encontrado';

      final ast = AST.fromFirestore(astDoc);

      // Actualizar AST
      batch.update(
        _firestore.collection('ast').doc(astId),
        {
          'estado': 'rechazado',
          'fechaRechazo': FieldValue.serverTimestamp(),
          'supervisorAprobadorUid': supervisorUid,
          'motivoRechazo': motivoRechazo,
        },
      );

      // Actualizar contadores del técnico
      batch.update(
        _firestore.collection('usuarios').doc(ast.tecnicoUid),
        {
          'totalASTPendientes': FieldValue.increment(-1),
          'totalASTRechazados': FieldValue.increment(1),
        },
      );

      // Actualizar contadores del supervisor
      batch.update(
        _firestore.collection('usuarios').doc(supervisorUid),
        {
          'totalASTRechazados': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al rechazar AST: $e';
    }
  }

  // Obtener supervisor
  Future<DocumentSnapshot?> obtenerSupervisor(String supervisorUid) async {
    try {
      final doc =
          await _firestore.collection('usuarios').doc(supervisorUid).get();
      if (doc.exists) {
        return doc;
      }
      return null;
    } catch (e) {
      throw 'Error al obtener supervisor: $e';
    }
  }
}
