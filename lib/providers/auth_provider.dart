import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AppUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  // Verificar estado de autenticación al iniciar
  Future<void> checkAuthState() async {
    _isLoading = true;
    notifyListeners();

    try {
      final User? firebaseUser = _auth.currentUser;
      
      if (firebaseUser != null) {
        await _loadUserData(firebaseUser.uid);
        
        // Actualizar último login
        if (_currentUser != null && _currentUser!.activo) {
          await _updateLastLogin(_currentUser!.uid);
        }
      }
    } catch (e) {
      _errorMessage = 'Error al verificar autenticación: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login con email y contraseña
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Autenticar en Firebase Auth
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      // Cargar datos del usuario desde Firestore
      await _loadUserData(credential.user!.uid);

      // Verificar que el usuario esté activo
      if (_currentUser == null) {
        await _auth.signOut();
        _errorMessage = 'Usuario no encontrado en el sistema';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      if (!_currentUser!.activo) {
        await _auth.signOut();
        _currentUser = null;
        _errorMessage = 'Usuario inactivo. Contacte al administrador.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Actualizar último login
      await _updateLastLogin(_currentUser!.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _currentUser = null;
      
      switch (e.code) {
        case 'user-not-found':
          _errorMessage = 'No existe una cuenta con este correo';
          break;
        case 'wrong-password':
          _errorMessage = 'Contraseña incorrecta';
          break;
        case 'invalid-email':
          _errorMessage = 'Correo electrónico inválido';
          break;
        case 'user-disabled':
          _errorMessage = 'Esta cuenta ha sido deshabilitada';
          break;
        case 'too-many-requests':
          _errorMessage = 'Demasiados intentos. Intente más tarde';
          break;
        default:
          _errorMessage = 'Error de autenticación: ${e.message}';
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _currentUser = null;
      _errorMessage = 'Error inesperado: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Cargar datos del usuario desde Firestore
  Future<void> _loadUserData(String uid) async {
    try {
      final doc = await _firestore.collection('usuarios').doc(uid).get();
      
      if (doc.exists) {
        _currentUser = AppUser.fromFirestore(doc);
      } else {
        _currentUser = null;
      }
    } catch (e) {
      debugPrint('Error al cargar datos del usuario: $e');
      _currentUser = null;
    }
  }

  // Actualizar último login
  Future<void> _updateLastLogin(String uid) async {
    try {
      await _firestore.collection('usuarios').doc(uid).update({
        'ultimoLogin': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error al actualizar último login: $e');
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
      _currentUser = null;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error al cerrar sesión: $e';
      notifyListeners();
    }
  }

  // Limpiar error
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Recargar datos del usuario actual
  Future<void> reloadCurrentUser() async {
    if (_currentUser != null) {
      await _loadUserData(_currentUser!.uid);
      notifyListeners();
    }
  }
}
