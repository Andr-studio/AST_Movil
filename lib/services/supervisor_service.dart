import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class SupervisorService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Crear supervisor (solo Admin)
  Future<String?> crearSupervisor({
    required String nombre,
    required String email,
    required String telefono,
    required String password,
    required String adminUid,
  }) async {
    try {
      // 1. Crear usuario en Firebase Auth
      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final String supervisorUid = userCredential.user!.uid;

      // 2. Crear documento en Firestore
      final supervisorData = AppUser(
        uid: supervisorUid,
        nombre: nombre.trim(),
        email: email.trim(),
        telefono: telefono.trim(),
        rol: UserRole.supervisor,
        supervisorUid: null,
        carpetaDriveId: null,
        activo: true,
        creadoPor: adminUid,
        fechaRegistro: DateTime.now(),
        totalTecnicosCreados: 0,
        totalTecnicosActivos: 0,
        totalTecnicosInactivos: 0,
        totalASTAprobados: 0,
        totalASTRechazados: 0,
      );

      await _firestore
          .collection('usuarios')
          .doc(supervisorUid)
          .set(supervisorData.toFirestore());

      // 3. Actualizar colección supervisoresPorAdmin
      await _firestore
          .collection('supervisoresPorAdmin')
          .doc(adminUid)
          .set({
        'supervisores.$supervisorUid': {
          'nombre': nombre.trim(),
          'email': email.trim(),
          'activo': true,
          'totalTecnicos': 0,
          'fechaCreacion': FieldValue.serverTimestamp(),
        },
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Incrementar contador del admin
      await _firestore.collection('usuarios').doc(adminUid).update({
        'totalSupervisoresCreados': FieldValue.increment(1),
      });

      return supervisorUid;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw 'Este correo ya está registrado';
        case 'invalid-email':
          throw 'Correo electrónico inválido';
        case 'weak-password':
          throw 'La contraseña debe tener al menos 6 caracteres';
        default:
          throw 'Error al crear supervisor: ${e.message}';
      }
    } catch (e) {
      throw 'Error inesperado: $e';
    }
  }

  // Obtener supervisores de un admin (activos e inactivos)
  Stream<QuerySnapshot> obtenerSupervisoresPorAdmin(String adminUid) {
    return _firestore
        .collection('usuarios')
        .where('rol', isEqualTo: 'supervisor')
        .where('creadoPor', isEqualTo: adminUid)
        .orderBy('fechaRegistro', descending: true)
        .snapshots();
  }

  // Obtener solo supervisores activos
  Stream<QuerySnapshot> obtenerSupervisoresActivos(String adminUid) {
    return _firestore
        .collection('usuarios')
        .where('rol', isEqualTo: 'supervisor')
        .where('creadoPor', isEqualTo: adminUid)
        .where('activo', isEqualTo: true)
        .orderBy('fechaRegistro', descending: true)
        .snapshots();
  }

  // Eliminar supervisor (soft delete)
  Future<void> eliminarSupervisor({
    required String supervisorUid,
    required String adminUid,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Marcar supervisor como inactivo
      final supervisorRef = _firestore.collection('usuarios').doc(supervisorUid);
      batch.update(supervisorRef, {
        'activo': false,
        'fechaEliminacion': FieldValue.serverTimestamp(),
      });

      // 2. Marcar todos sus técnicos como inactivos
      final tecnicosSnapshot = await _firestore
          .collection('usuarios')
          .where('supervisorUid', isEqualTo: supervisorUid)
          .where('rol', isEqualTo: 'tecnico')
          .get();

      for (var doc in tecnicosSnapshot.docs) {
        batch.update(doc.reference, {
          'activo': false,
          'fechaEliminacion': FieldValue.serverTimestamp(),
        });
      }

      // 3. Actualizar colección supervisoresPorAdmin
      batch.update(
        _firestore.collection('supervisoresPorAdmin').doc(adminUid),
        {
          'supervisores.$supervisorUid.activo': false,
          'supervisores.$supervisorUid.fechaEliminacion':
              FieldValue.serverTimestamp(),
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al eliminar supervisor: $e';
    }
  }

  // Reactivar supervisor
  Future<void> reactivarSupervisor({
    required String supervisorUid,
    required String adminUid,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Reactivar supervisor
      final supervisorRef = _firestore.collection('usuarios').doc(supervisorUid);
      batch.update(supervisorRef, {
        'activo': true,
        'fechaEliminacion': null,
      });

      // 2. Actualizar colección supervisoresPorAdmin
      batch.update(
        _firestore.collection('supervisoresPorAdmin').doc(adminUid),
        {
          'supervisores.$supervisorUid.activo': true,
          'supervisores.$supervisorUid.fechaEliminacion': null,
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();
    } catch (e) {
      throw 'Error al reactivar supervisor: $e';
    }
  }

  // Actualizar datos del supervisor
  Future<void> actualizarSupervisor({
    required String supervisorUid,
    required String nombre,
    required String telefono,
  }) async {
    try {
      await _firestore.collection('usuarios').doc(supervisorUid).update({
        'nombre': nombre.trim(),
        'telefono': telefono.trim(),
      });
    } catch (e) {
      throw 'Error al actualizar supervisor: $e';
    }
  }

  // Obtener estadísticas de un supervisor
  Future<Map<String, dynamic>> obtenerEstadisticasSupervisor(
      String supervisorUid) async {
    try {
      final doc =
          await _firestore.collection('usuarios').doc(supervisorUid).get();
      
      if (!doc.exists) {
        throw 'Supervisor no encontrado';
      }

      final data = doc.data()!;
      
      return {
        'totalTecnicosCreados': data['totalTecnicosCreados'] ?? 0,
        'totalTecnicosActivos': data['totalTecnicosActivos'] ?? 0,
        'totalTecnicosInactivos': data['totalTecnicosInactivos'] ?? 0,
        'totalASTAprobados': data['totalASTAprobados'] ?? 0,
        'totalASTRechazados': data['totalASTRechazados'] ?? 0,
      };
    } catch (e) {
      throw 'Error al obtener estadísticas: $e';
    }
  }

  // Contar supervisores activos de un admin
  Future<int> contarSupervisoresActivos(String adminUid) async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'supervisor')
          .where('creadoPor', isEqualTo: adminUid)
          .where('activo', isEqualTo: true)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // Contar supervisores inactivos de un admin
  Future<int> contarSupervisoresInactivos(String adminUid) async {
    try {
      final snapshot = await _firestore
          .collection('usuarios')
          .where('rol', isEqualTo: 'supervisor')
          .where('creadoPor', isEqualTo: adminUid)
          .where('activo', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
