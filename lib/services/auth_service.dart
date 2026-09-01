import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/family_user.dart';
import '../models/pin_reset_request.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  FamilyUser? _currentUser;
  FamilyUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static const String _usersCollection = 'family_users';
  static const String _requestsCollection = 'password_requests';
  static const String _prefUserIdKey = 'auth_user_id';
  static const String _prefUserAliasKey = 'auth_user_alias';

  /// Hash seguro SHA-256 para el PIN numérico
  static String hashPin(String pin) {
    const salt = 'auditoria_financiera_family_2026_salt_';
    final bytes = utf8.encode('$salt$pin');
    return sha256.convert(bytes).toString();
  }

  /// Lista de usuarios familiares por defecto
  List<FamilyUser> get defaultFamilyUsers {
    final defaultPin = hashPin('1234');
    final now = DateTime.now();
    return [
      FamilyUser(
        id: 'admin_user',
        alias: 'admin',
        displayName: 'Administrador',
        role: UserRole.admin,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'admin_panel_settings',
      ),
      FamilyUser(
        id: 'papa_user',
        alias: 'papa',
        displayName: 'Papá',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'person',
      ),
      FamilyUser(
        id: 'mama_user',
        alias: 'mama',
        displayName: 'Mamá',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'favorite',
      ),
      FamilyUser(
        id: 'hijo_user',
        alias: 'hijo',
        displayName: 'Hijo / Hija',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'school',
      ),
    ];
  }

  /// Inicializar y sincronizar usuarios por defecto en Firestore
  Future<void> initializeDefaultUsersIfNeeded() async {
    try {
      final defaultUsers = defaultFamilyUsers;
      final snapshot = await _firestore
          .collection(_usersCollection)
          .get()
          .timeout(const Duration(seconds: 4));

      if (snapshot.docs.isEmpty) {
        final batch = _firestore.batch();
        for (final user in defaultUsers) {
          batch.set(_firestore.collection(_usersCollection).doc(user.id), user.toMap());
        }
        await batch.commit().timeout(const Duration(seconds: 4));
      }
    } catch (e) {
      debugPrint('ℹ️ [AuthService] Firestore init offline o pendiente de reglas: $e');
    }
  }

  /// Obtener lista de todos los usuarios activos
  Future<List<FamilyUser>> getActiveUsers() async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('isActive', isEqualTo: true)
          .get()
          .timeout(const Duration(seconds: 3));

      final users = query.docs.map((doc) => FamilyUser.fromSnapshot(doc)).toList();
      if (users.isNotEmpty) {
        return users;
      }
    } catch (_) {}

    // Fallback instantáneo con los usuarios familiares por defecto
    return defaultFamilyUsers;
  }

  /// Obtener usuario guardado en el dispositivo para biometría
  Future<FamilyUser?> getSavedBiometricUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_prefUserIdKey);
      if (savedUserId != null) {
        final doc = await _firestore.collection(_usersCollection).doc(savedUserId).get().timeout(const Duration(seconds: 3));
        if (doc.exists) {
          final user = FamilyUser.fromSnapshot(doc);
          if (user.isActive) {
            return user;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Login con Alias y PIN Numérico
  Future<FamilyUser> loginWithPin({
    required String alias,
    required String pin,
  }) async {
    final cleanAlias = alias.trim().toLowerCase();
    final pinHashed = hashPin(pin.trim());

    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('alias', isEqualTo: cleanAlias)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final user = FamilyUser.fromSnapshot(doc);

        if (!user.isActive) {
          throw Exception('Esta cuenta ha sido desactivada por el Administrador.');
        }

        if (user.pinHash != pinHashed) {
          throw Exception('PIN incorrecto. Intenta de nuevo.');
        }

        doc.reference.update({
          'lastLogin': Timestamp.fromDate(DateTime.now()),
        }).catchError((_) {});

        _currentUser = user.copyWith(lastLogin: DateTime.now());
        await _saveSession(_currentUser!);
        return _currentUser!;
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('PIN incorrecto')) {
        rethrow;
      }
    }

    // Fallback con usuario local predeterminado si Firestore no responde
    final defaultUser = defaultFamilyUsers.firstWhere(
      (u) => u.alias.toLowerCase() == cleanAlias,
      orElse: () => throw Exception('Usuario no encontrado. Selecciona otro perfil.'),
    );

    if (defaultUser.pinHash != pinHashed) {
      throw Exception('PIN incorrecto. El PIN por defecto es 1234.');
    }

    _currentUser = defaultUser.copyWith(lastLogin: DateTime.now());
    await _saveSession(_currentUser!);
    return _currentUser!;
  }


  /// Autenticación por Biometría (Huella Dactilar)
  Future<FamilyUser?> authenticateWithBiometrics({String? targetAlias}) async {
    try {
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics && !isDeviceSupported) {
        throw Exception('El dispositivo no cuenta con sensor biométrico habilitado.');
      }

      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_prefUserIdKey);

      if (savedUserId == null) {
        throw Exception('Para usar huella, primero debes iniciar sesión con tu PIN.');
      }

      final doc = await _firestore.collection(_usersCollection).doc(savedUserId).get();
      if (!doc.exists) {
        throw Exception('El usuario guardado ya no existe en el sistema.');
      }

      final user = FamilyUser.fromSnapshot(doc);
      if (!user.isActive) {
        throw Exception('Esta cuenta ha sido desactivada por el Administrador.');
      }

      if (targetAlias != null && targetAlias.trim().toLowerCase() != user.alias.toLowerCase()) {
        throw Exception('La huella está vinculada a ${user.displayName}. Para ingresar como @$targetAlias debes ingresar su PIN.');
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Escanea tu huella para acceder como ${user.displayName}',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        _currentUser = user;
        return user;
      }
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
    return null;
  }

  /// Solicitar recuperación de PIN a Firestore
  Future<void> requestPinResetForUser({
    required FamilyUser user,
    required String reason,
  }) async {
    final existingQuery = await _firestore
        .collection(_requestsCollection)
        .where('userId', isEqualTo: user.id)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingQuery.docs.isNotEmpty) {
      throw Exception('Ya existe una solicitud de reseteo pendiente para ${user.displayName}. El Administrador la revisará pronto.');
    }

    final newRequest = PinResetRequest(
      id: '',
      userId: user.id,
      alias: user.alias,
      displayName: user.displayName,
      note: reason.trim(),
      status: RequestStatus.pending,
      requestedAt: DateTime.now(),
    );

    await _firestore.collection(_requestsCollection).add(newRequest.toMap());
  }

  /// Guardar sesión local
  Future<void> _saveSession(FamilyUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefUserIdKey, user.id);
    await prefs.setString(_prefUserAliasKey, user.alias);
  }

  /// Cargar sesión activa al arrancar
  Future<FamilyUser?> checkSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_prefUserIdKey);

      if (savedUserId != null) {
        final doc = await _firestore
            .collection(_usersCollection)
            .doc(savedUserId)
            .get()
            .timeout(const Duration(milliseconds: 1500));
        if (doc.exists) {
          final user = FamilyUser.fromSnapshot(doc);
          if (user.isActive) {
            _currentUser = user;
            return user;
          }
        }
      }
    } catch (_) {}
    return null;
  }


  /// Cerrar Sesión
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefUserIdKey);
    await prefs.remove(_prefUserAliasKey);
  }
}
