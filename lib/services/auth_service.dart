import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
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

  /// Inicializar y sincronizar usuarios por defecto en Firestore con roles estrictamente separados
  Future<void> initializeDefaultUsersIfNeeded() async {
    try {
      final defaultPin = hashPin('1234');
      final now = DateTime.now();

      // 1. Administrador Puro (DBA / Gestor)
      final adminUser = FamilyUser(
        id: 'admin_user',
        alias: 'admin',
        displayName: 'Administrador',
        role: UserRole.admin,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'admin_panel_settings',
      );

      // 2. Papá (Rol Familiar Independiente)
      final papaUser = FamilyUser(
        id: 'papa_user',
        alias: 'papa',
        displayName: 'Papá',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'person',
      );

      // 3. Mamá (Rol Familiar)
      final mamaUser = FamilyUser(
        id: 'mama_user',
        alias: 'mama',
        displayName: 'Mamá',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'favorite',
      );

      // 4. Hijo/a (Rol Familiar)
      final hijoUser = FamilyUser(
        id: 'hijo_user',
        alias: 'hijo',
        displayName: 'Hijo / Hija',
        role: UserRole.member,
        pinHash: defaultPin,
        isActive: true,
        createdAt: now,
        biometricsEnabled: true,
        avatarIcon: 'school',
      );

      final snapshot = await _firestore.collection(_usersCollection).get();

      if (snapshot.docs.isEmpty) {
        final batch = _firestore.batch();
        batch.set(_firestore.collection(_usersCollection).doc(adminUser.id), adminUser.toMap());
        batch.set(_firestore.collection(_usersCollection).doc(papaUser.id), papaUser.toMap());
        batch.set(_firestore.collection(_usersCollection).doc(mamaUser.id), mamaUser.toMap());
        batch.set(_firestore.collection(_usersCollection).doc(hijoUser.id), hijoUser.toMap());
        await batch.commit();
      } else {
        // Migración/Limpieza automática: asegurar que Administrador y Papá estén separados en Firestore
        final batch = _firestore.batch();
        bool needsCommit = false;

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final displayName = data['displayName'] as String? ?? '';
          final alias = data['alias'] as String? ?? '';

          // Si el usuario anterior era "Papá / Admin", renombrarlo a "Administrador" puro
          if (displayName.contains('Papá / Admin') || (alias == 'admin' && displayName != 'Administrador')) {
            batch.update(doc.reference, {
              'displayName': 'Administrador',
              'role': 'admin',
              'avatarIcon': 'admin_panel_settings',
            });
            needsCommit = true;
          }
        }

        // Verificar si existe el usuario "papa", si no existe, crearlo
        final papaExists = snapshot.docs.any((d) => (d.data()['alias'] as String?) == 'papa');
        if (!papaExists) {
          batch.set(_firestore.collection(_usersCollection).doc(papaUser.id), papaUser.toMap());
          needsCommit = true;
        }

        if (needsCommit) {
          await batch.commit();
        }
      }
    } catch (_) {}
  }

  /// Obtener lista de todos los usuarios activos
  Future<List<FamilyUser>> getActiveUsers() async {
    try {
      final query = await _firestore
          .collection(_usersCollection)
          .where('isActive', isEqualTo: true)
          .get();
      return query.docs.map((doc) => FamilyUser.fromSnapshot(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Obtener usuario guardado en el dispositivo para biometría
  Future<FamilyUser?> getSavedBiometricUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUserId = prefs.getString(_prefUserIdKey);
    if (savedUserId != null) {
      final doc = await _firestore.collection(_usersCollection).doc(savedUserId).get();
      if (doc.exists) {
        final user = FamilyUser.fromSnapshot(doc);
        if (user.isActive) {
          return user;
        }
      }
    }
    return null;
  }

  /// Login con Alias y PIN Numérico
  Future<FamilyUser> loginWithPin({
    required String alias,
    required String pin,
  }) async {
    final cleanAlias = alias.trim().toLowerCase();
    final pinHashed = hashPin(pin.trim());

    final query = await _firestore
        .collection(_usersCollection)
        .where('alias', isEqualTo: cleanAlias)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Usuario no encontrado. Verifica el usuario seleccionado.');
    }

    final doc = query.docs.first;
    final user = FamilyUser.fromSnapshot(doc);

    if (!user.isActive) {
      throw Exception('Esta cuenta ha sido desactivada por el Administrador.');
    }

    if (user.pinHash != pinHashed) {
      throw Exception('PIN incorrecto. Intenta de nuevo.');
    }

    await doc.reference.update({
      'lastLogin': Timestamp.fromDate(DateTime.now()),
    });

    _currentUser = user.copyWith(lastLogin: DateTime.now());
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
        final doc = await _firestore.collection(_usersCollection).doc(savedUserId).get();
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
