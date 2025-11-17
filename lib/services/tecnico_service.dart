import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class TecnicoService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear técnico (solo Supervisor)
  Future<String?> crearTecnico({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
    required String supervisorUid,
    required String supervisorNombre,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final String tecnicoUid = userCredential.user!.uid;

      // 2. Crear documento en Firestore
      final tecnicoData = AppUser(
        uid: tecnicoUid,
        nombre: nombre.trim(),
        email: email.trim(),
        telefono: telefono.trim(),
        rol: UserRole.tecnico,
        supervisorUid: supervisorUid, // Asignado automáticamente
        carpetaDriveId: null, // Se creará al generar primer AST
        activo: true,
        creadoPor: supervisorUid,
        fechaRegistro: DateTime.now(),
        totalASTGenerados: 0,
        totalASTPendientes: 0,
        totalASTAprobados: 0,
        totalASTRechazados: 0,
      );

      await _firestore
          .collection('usuarios')
          .doc(tecnicoUid)
          .set(tecnicoData.toFirestore());

      // 3. Actualizar colección tecnicosPorSupervisor
      await _firestore
          .collection('tecnicosPorSupervisor')
          .doc(supervisorUid)
          .set({
        'tecnicos.$tecnicoUid': {
          'nombre': nombre.trim(),
          'email': email.trim(),
          'activo': true,
          'totalAST': 0,
          'ultimoAST': null,
          'fechaCreacion': FieldValue.serverTimestamp(),
        },
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Incrementar contadores del supervisor
      await _firestore.collection('usuarios').doc(supervisorUid).update({
        'totalTecnicosCreados': FieldValue.increment(1),
        'totalTecnicosActivos': FieldValue.increment(1),
      });

      // 5. Crear historial de supervisores para el técnico
      await _firestore.collection('usuarios').doc(tecnicoUid).update({
        'historialSupervisores': [
          {
            'supervisorUid': supervisorUid,
            'supervisorNombre': supervisorNombre,
            'fechaAsignacion': FieldValue.serverTimestamp(),
            'fechaReasignacion': null,
            'reasignadoPor': null,
          }
        ],
      });

      return tecnicoUid;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Este correo ya está registrado';
        case 'invalid-email':
          throw 'Correo electrónico inválido';
        case 'weak-password':
          throw 'La contraseña debe tener al menos 6 caracteres';
        default:
          throw 'Error al crear técnico: ${e.message}';
      }
    } catch (e) {
      throw 'Error inesperado: $e';
    }
  }

  // Obtener técnicos de un supervisor
  Stream<QuerySnapshot> obtenerTecnicosPorSupervisor(String supervisorUid) {
    return _firestore
        .collection('usuarios')
        .where('rol', isEqualTo: 'tecnico')
        .where('supervisorUid', isEqualTo: supervisorUid)
        .orderBy('fechaRegistro', descending: true)
        .snapshots();
  }

  // Obtener solo técnicos activos
  Stream<QuerySnapshot> obtenerTecnicosActivos(String supervisorUid) {
    return _firestore
        .collection('usuarios')
        .where('rol', isEqualTo: 'tecnico')
        .where('supervisorUid', isEqualTo: supervisorUid)
        .where('activo', isEqualTo: true)
        .orderBy('fechaRegistro', descending: true)
        .snapshots();
  }

  // Eliminar técnico (soft delete)
  Future<void> eliminarTecnico({
    required String tecnicoUid,
    required String supervisorUid,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Marcar técnico como inactivo
      final tecnicoRef = _firestore.collection('usuarios').doc(tecnicoUid);
      batch.update(tecnicoRef, {
        'activo': false,
        'fechaEliminacion': FieldValue.serverTimestamp(),
      });

      // 2. Actualizar colección tecnicosPorSupervisor
      batch.update(
        _firestore.collection('tecnicosPorSupervisor').doc(supervisorUid),
        {
          'tecnicos.$tecnicoUid.activo': false,
          'tecnicos.$tecnicoUid.fechaEliminacion':
              FieldValue.serverTimestamp(),
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        },
      );

      // 3. Actualizar contadores del supervisor
      batch.update(
        _firestore.collection('usuarios').doc(supervisorUid),
        {
          'totalTecnicosActivos': FieldValue.increment(-1),
          'totalTecnicosInactivos': FieldValue.increment(1),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al eliminar técnico: $e';
    }
  }

  // Reactivar técnico
  Future<void> reactivarTecnico({
    required String tecnicoUid,
    required String supervisorUid,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Reactivar técnico
      final tecnicoRef = _firestore.collection('usuarios').doc(tecnicoUid);
      batch.update(tecnicoRef, {
        'activo': true,
        'fechaEliminacion': null,
      });

      // 2. Actualizar colección tecnicosPorSupervisor
      batch.update(
        _firestore.collection('tecnicosPorSupervisor').doc(supervisorUid),
        {
          'tecnicos.$tecnicoUid.activo': true,
          'tecnicos.$tecnicoUid.fechaEliminacion': null,
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        },
      );

      // 3. Actualizar contadores del supervisor
      batch.update(
        _firestore.collection('usuarios').doc(supervisorUid),
        {
          'totalTecnicosActivos': FieldValue.increment(1),
          'totalTecnicosInactivos': FieldValue.increment(-1),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al reactivar técnico: $e';
    }
  }

  // Actualizar datos del técnico
  Future<void> actualizarTecnico({
    required String tecnicoUid,
    required String nombre,
    required String telefono,
  }) async {
    try {
      await _firestore.collection('usuarios').doc(tecnicoUid).update({
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
      });
    } catch (e) {
      throw 'Error al actualizar técnico: $e';
    }
  }

  // Obtener estadísticas de un técnico
  Future<Map<String, dynamic>> obtenerEstadisticasTecnico(
      String tecnicoUid) async {
    try {
      final doc =
          await _firestore.collection('usuarios').doc(tecnicoUid).get();
      
      if (!doc.exists) {
        throw 'Técnico no encontrado';
      }

      final data = doc.data()!;
      
      return {
        'totalASTGenerados': data['totalASTGenerados'] ?? 0,
        'totalASTPendientes': data['totalASTPendientes'] ?? 0,
        'totalASTAprobados': data['totalASTAprobados'] ?? 0,
        'totalASTRechazados': data['totalASTRechazados'] ?? 0,
      };
    } catch (e) {
      throw 'Error al obtener estadísticas: $e';
    }
  }

  // Contar técnicos activos de un supervisor
  Future<int> contarTecnicosActivos(String supervisorUid) async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('supervisorUid', isEqualTo: supervisorUid)
          .where('activo', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Contar técnicos inactivos de un supervisor
  Future<int> contarTecnicosInactivos(String supervisorUid) async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'tecnico')
          .where('supervisorUid', isEqualTo: supervisorUid)
          .where('activo', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
