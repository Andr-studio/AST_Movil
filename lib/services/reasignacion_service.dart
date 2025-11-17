import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/reasignacion_model.dart';
import '../models/notification_model.dart';
import 'notification_service.dart';

class ReasignacionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  /// Reasignar un técnico de un supervisor a otro
  /// Esta función realiza todas las actualizaciones necesarias en una transacción
  Future<void> reasignarTecnico({
    required String tecnicoUid,
    required String supervisorNuevoUid,
    required String adminUid,
    String? motivo,
  }) async {
    try {
      // 1. Obtener datos del técnico
      final tecnicoDoc =
          await _firestore.collection('usuarios').doc(tecnicoUid).get();

      if (!tecnicoDoc.exists) {
        throw 'Técnico no encontrado';
      }

      final tecnico = AppUser.fromFirestore(tecnicoDoc);

      if (tecnico.rol != UserRole.tecnico) {
        throw 'El usuario especificado no es un técnico';
      }

      if (!tecnico.activo) {
        throw 'No se puede reasignar un técnico inactivo';
      }

      final supervisorAnteriorUid = tecnico.supervisorUid;

      if (supervisorAnteriorUid == null) {
        throw 'El técnico no tiene supervisor asignado';
      }

      if (supervisorAnteriorUid == supervisorNuevoUid) {
        throw 'El técnico ya está asignado a este supervisor';
      }

      // 2. Obtener datos del supervisor anterior
      final supervisorAnteriorDoc = await _firestore
          .collection('usuarios')
          .doc(supervisorAnteriorUid)
          .get();

      if (!supervisorAnteriorDoc.exists) {
        throw 'Supervisor anterior no encontrado';
      }

      final supervisorAnterior =
          AppUser.fromFirestore(supervisorAnteriorDoc);

      // 3. Obtener datos del supervisor nuevo
      final supervisorNuevoDoc =
          await _firestore.collection('usuarios').doc(supervisorNuevoUid).get();

      if (!supervisorNuevoDoc.exists) {
        throw 'Supervisor nuevo no encontrado';
      }

      final supervisorNuevo = AppUser.fromFirestore(supervisorNuevoDoc);

      if (supervisorNuevo.rol != UserRole.supervisor) {
        throw 'El usuario especificado no es un supervisor';
      }

      if (!supervisorNuevo.activo) {
        throw 'No se puede asignar a un supervisor inactivo';
      }

      // 4. Obtener datos del admin
      final adminDoc =
          await _firestore.collection('usuarios').doc(adminUid).get();

      if (!adminDoc.exists) {
        throw 'Administrador no encontrado';
      }

      final admin = AppUser.fromFirestore(adminDoc);

      if (admin.rol != UserRole.admin) {
        throw 'Solo un administrador puede reasignar técnicos';
      }

      // 5. Contar AST pendientes del técnico
      final astPendientesSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .where('estado', isEqualTo: 'pendiente')
          .get();

      final astPendientesCount = astPendientesSnapshot.docs.length;

      // 6. Contar total de AST del técnico
      final totalASTSnapshot = await _firestore
          .collection('ast')
          .where('tecnicoUid', isEqualTo: tecnicoUid)
          .count()
          .get();

      final totalAST = totalASTSnapshot.count ?? 0;

      // 7. Ejecutar reasignación en un batch
      final batch = _firestore.batch();

      // 7.1. Actualizar documento del técnico
      final tecnicoRef = _firestore.collection('usuarios').doc(tecnicoUid);

      // Obtener historial actual
      final historialActual =
          tecnicoDoc.data()?['historialSupervisores'] as List<dynamic>? ?? [];

      // Actualizar el último registro del historial (cerrar periodo con supervisor anterior)
      if (historialActual.isNotEmpty) {
        final ultimoIndex = historialActual.length - 1;
        historialActual[ultimoIndex]['fechaReasignacion'] =
            FieldValue.serverTimestamp();
        historialActual[ultimoIndex]['reasignadoPor'] = adminUid;
        historialActual[ultimoIndex]['motivo'] = motivo;
      }

      // Agregar nuevo registro
      historialActual.add({
        'supervisorUid': supervisorNuevoUid,
        'supervisorNombre': supervisorNuevo.nombre,
        'fechaAsignacion': FieldValue.serverTimestamp(),
        'fechaReasignacion': null,
        'reasignadoPor': null,
        'motivo': null,
      });

      batch.update(tecnicoRef, {
        'supervisorUid': supervisorNuevoUid,
        'historialSupervisores': historialActual,
      });

      // 7.2. Actualizar todos los AST pendientes
      for (final astDoc in astPendientesSnapshot.docs) {
        final astRef = _firestore.collection('ast').doc(astDoc.id);
        batch.update(astRef, {
          'supervisorAsignadoUid': supervisorNuevoUid,
          'supervisorAsignadoNombre': supervisorNuevo.nombre,
          'supervisorAsignadoEmail': supervisorNuevo.email,
        });
      }

      // 7.3. Actualizar colección tecnicosPorSupervisor (remover del anterior)
      final tecnicosPorSupervisorAnteriorRef =
          _firestore.collection('tecnicosPorSupervisor').doc(supervisorAnteriorUid);
      batch.update(tecnicosPorSupervisorAnteriorRef, {
        'tecnicos.$tecnicoUid': FieldValue.delete(),
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      });

      // 7.4. Actualizar colección tecnicosPorSupervisor (agregar al nuevo)
      final tecnicosPorSupervisorNuevoRef =
          _firestore.collection('tecnicosPorSupervisor').doc(supervisorNuevoUid);
      batch.set(
        tecnicosPorSupervisorNuevoRef,
        {
          'tecnicos.$tecnicoUid': {
            'nombre': tecnico.nombre,
            'email': tecnico.email,
            'activo': true,
            'totalAST': totalAST,
            'ultimoAST': null,
            'fechaReasignacion': FieldValue.serverTimestamp(),
          },
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // 7.5. Actualizar contadores del supervisor anterior
      final supervisorAnteriorRef =
          _firestore.collection('usuarios').doc(supervisorAnteriorUid);
      batch.update(supervisorAnteriorRef, {
        'totalTecnicosActivos': FieldValue.increment(-1),
      });

      // 7.6. Actualizar contadores del supervisor nuevo
      final supervisorNuevoRef =
          _firestore.collection('usuarios').doc(supervisorNuevoUid);
      batch.update(supervisorNuevoRef, {
        'totalTecnicosActivos': FieldValue.increment(1),
        'totalTecnicosCreados': FieldValue.increment(1),
      });

      // 7.7. Crear registro en colección de historial de reasignaciones
      final reasignacionRef = _firestore.collection('reasignaciones').doc();
      final reasignacion = Reasignacion(
        id: reasignacionRef.id,
        tecnicoUid: tecnicoUid,
        tecnicoNombre: tecnico.nombre,
        tecnicoEmail: tecnico.email,
        supervisorAnteriorUid: supervisorAnteriorUid,
        supervisorAnteriorNombre: supervisorAnterior.nombre,
        supervisorAnteriorEmail: supervisorAnterior.email,
        supervisorNuevoUid: supervisorNuevoUid,
        supervisorNuevoNombre: supervisorNuevo.nombre,
        supervisorNuevoEmail: supervisorNuevo.email,
        adminUid: adminUid,
        adminNombre: admin.nombre,
        fechaReasignacion: DateTime.now(),
        astPendientesReasignados: astPendientesCount,
        totalASTDelTecnico: totalAST,
        motivo: motivo,
      );

      batch.set(reasignacionRef, reasignacion.toFirestore());

      // 8. Ejecutar todas las operaciones
      await batch.commit();

      // 9. Enviar notificaciones después de completar la transacción
      // 9.1. Notificar al técnico que fue reasignado
      await _notificationService.sendNotificationToUser(
        userId: tecnicoUid,
        title: '🔄 Reasignación de Supervisor',
        body: 'Has sido reasignado de ${supervisorAnterior.nombre} a ${supervisorNuevo.nombre}',
        data: {
          'type': 'reasignado',
          'nuevoSupervisorUid': supervisorNuevoUid,
          'nuevoSupervisorNombre': supervisorNuevo.nombre,
          'antiguoSupervisorUid': supervisorAnteriorUid,
          'antiguoSupervisorNombre': supervisorAnterior.nombre,
          'motivo': motivo ?? 'Sin motivo especificado',
        },
      );

      // 9.2. Notificar al nuevo supervisor que recibe al técnico
      await _notificationService.sendNotificationToUser(
        userId: supervisorNuevoUid,
        title: '🔄 Técnico Reasignado a Ti',
        body: '${tecnico.nombre} ha sido reasignado desde ${supervisorAnterior.nombre} a tu supervisión',
        data: {
          'type': 'tecnico_reasignado',
          'tecnicoUid': tecnicoUid,
          'tecnicoNombre': tecnico.nombre,
          'antiguoSupervisorUid': supervisorAnteriorUid,
          'antiguoSupervisorNombre': supervisorAnterior.nombre,
          'motivo': motivo ?? 'Sin motivo especificado',
        },
      );

      // 9.3. Notificar al admin que se completó la reasignación
      await _notificationService.sendNotificationToUser(
        userId: adminUid,
        title: '✅ Reasignación Completada',
        body: '${tecnico.nombre} fue reasignado exitosamente de ${supervisorAnterior.nombre} a ${supervisorNuevo.nombre}',
        data: {
          'type': 'reasignacion_completada',
          'tecnicoUid': tecnicoUid,
          'tecnicoNombre': tecnico.nombre,
          'nuevoSupervisorUid': supervisorNuevoUid,
          'nuevoSupervisorNombre': supervisorNuevo.nombre,
          'astPendientesReasignados': astPendientesCount,
        },
      );
    } catch (e) {
      throw 'Error al reasignar técnico: $e';
    }
  }

  /// Obtener historial de reasignaciones (todas)
  Stream<QuerySnapshot> obtenerHistorialReasignaciones() {
    return _firestore
        .collection('reasignaciones')
        .orderBy('fechaReasignacion', descending: true)
        .snapshots();
  }

  /// Obtener historial de reasignaciones de un técnico específico
  Stream<QuerySnapshot> obtenerHistorialReasignacionesDeTecnico(
      String tecnicoUid) {
    return _firestore
        .collection('reasignaciones')
        .where('tecnicoUid', isEqualTo: tecnicoUid)
        .orderBy('fechaReasignacion', descending: true)
        .snapshots();
  }

  /// Obtener historial de reasignaciones realizadas por un admin
  Stream<QuerySnapshot> obtenerHistorialReasignacionesPorAdmin(
      String adminUid) {
    return _firestore
        .collection('reasignaciones')
        .where('adminUid', isEqualTo: adminUid)
        .orderBy('fechaReasignacion', descending: true)
        .snapshots();
  }

  /// Obtener todos los técnicos activos del sistema (para reasignación)
  Future<List<AppUser>> obtenerTodosTecnicosActivos() async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw 'Error al obtener técnicos: $e';
    }
  }

  /// Obtener todos los supervisores activos (para reasignación)
  Future<List<AppUser>> obtenerTodosSupervisoresActivos() async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'supervisor')
          .where('activo', isEqualTo: true)
          .orderBy('nombre')
          .get();

      return snapshot.docs.map((doc) => AppUser.fromFirestore(doc)).toList();
    } catch (e) {
      throw 'Error al obtener supervisores: $e';
    }
  }

  /// Obtener historial de supervisores de un técnico (desde su documento)
  Future<List<HistorialSupervisor>> obtenerHistorialSupervisoresDeTecnico(
      String tecnicoUid) async {
    try {
      final tecnicoDoc =
          await _firestore.collection('usuarios').doc(tecnicoUid).get();

      if (!tecnicoDoc.exists) {
        throw 'Técnico no encontrado';
      }

      final historial =
          tecnicoDoc.data()?['historialSupervisores'] as List<dynamic>? ?? [];

      return historial
          .map((item) => HistorialSupervisor.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw 'Error al obtener historial: $e';
    }
  }

  /// Contar reasignaciones totales del sistema
  Future<int> contarTotalReasignaciones() async {
    try {
      final snapshot =
          await _firestore.collection('reasignaciones').count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Obtener estadísticas de reasignaciones
  Future<Map<String, int>> obtenerEstadisticasReasignaciones() async {
    try {
      // Total de reasignaciones
      final totalSnapshot =
          await _firestore.collection('reasignaciones').count().get();

      // Reasignaciones del último mes
      final hace30Dias = DateTime.now().subtract(const Duration(days: 30));
      final ultimoMesSnapshot = await _firestore
          .collection('reasignaciones')
          .where('fechaReasignacion',
              isGreaterThanOrEqualTo: Timestamp.fromDate(hace30Dias))
          .count()
          .get();

      // Técnicos que han sido reasignados (distintos)
      final reasignacionesSnapshot =
          await _firestore.collection('reasignaciones').get();

      final tecnicosUnicos = <String>{};
      for (final doc in reasignacionesSnapshot.docs) {
        tecnicosUnicos.add(doc.data()['tecnicoUid'] as String);
      }

      return {
        'total': totalSnapshot.count ?? 0,
        'ultimoMes': ultimoMesSnapshot.count ?? 0,
        'tecnicosReasignados': tecnicosUnicos.length,
      };
    } catch (e) {
      return {
        'total': 0,
        'ultimoMes': 0,
        'tecnicosReasignados': 0,
      };
    }
  }
}
