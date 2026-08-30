import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/family_user.dart';
import '../models/pin_reset_request.dart';
import 'auth_service.dart';

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _usersCollection = 'family_users';
  static const String _requestsCollection = 'password_requests';

  /// Stream en tiempo real de todos los usuarios de la familia
  Stream<List<FamilyUser>> getFamilyUsersStream() {
    return _firestore
        .collection(_usersCollection)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => FamilyUser.fromSnapshot(doc)).toList());
  }

  /// Stream en tiempo real de solicitudes de reseteo de PIN pendientes
  Stream<List<PinResetRequest>> getPendingRequestsStream() {
    return _firestore
        .collection(_requestsCollection)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PinResetRequest.fromSnapshot(doc))
            .where((r) => r.isPending)
            .toList());
  }

  /// Stream de todas las solicitudes (historial)
  Stream<List<PinResetRequest>> getAllRequestsStream() {
    return _firestore
        .collection(_requestsCollection)
        .orderBy('requestedAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PinResetRequest.fromSnapshot(doc)).toList());
  }

  /// Crear nuevo integrante familiar
  Future<void> createFamilyMember({
    required String displayName,
    required String alias,
    required UserRole role,
    required String initialPin,
    required String avatarIcon,
  }) async {
    final cleanAlias = alias.trim().toLowerCase();

    // Validar alias único
    final existing = await _firestore
        .collection(_usersCollection)
        .where('alias', isEqualTo: cleanAlias)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      throw Exception('El alias "$cleanAlias" ya está en uso. Elige otro.');
    }

    final newUser = FamilyUser(
      id: '',
      alias: cleanAlias,
      displayName: displayName.trim(),
      role: role,
      pinHash: AuthService.hashPin(initialPin.trim()),
      isActive: true,
      createdAt: DateTime.now(),
      biometricsEnabled: true,
      avatarIcon: avatarIcon,
    );

    await _firestore.collection(_usersCollection).add(newUser.toMap());
  }

  /// Activar o desactivar cuenta de un integrante
  Future<void> updateUserStatus(String userId, bool isActive) async {
    await _firestore.collection(_usersCollection).doc(userId).update({
      'isActive': isActive,
    });
  }

  /// Cambiar PIN de un integrante directamente
  Future<void> changeUserPin(String userId, String newPin) async {
    final pinHash = AuthService.hashPin(newPin.trim());
    await _firestore.collection(_usersCollection).doc(userId).update({
      'pinHash': pinHash,
    });
  }

  /// Aprobar solicitud de reseteo y asignar nuevo PIN
  Future<void> resolvePinReset({
    required String requestId,
    required String userId,
    required String newPin,
    required String resolvedBy,
  }) async {
    final pinHash = AuthService.hashPin(newPin.trim());

    final batch = _firestore.batch();
    // 1. Actualizar PIN del usuario
    batch.update(_firestore.collection(_usersCollection).doc(userId), {
      'pinHash': pinHash,
    });

    // 2. Marcar solicitud como aprobada
    batch.update(_firestore.collection(_requestsCollection).doc(requestId), {
      'status': RequestStatus.approved.key,
      'resolvedAt': Timestamp.fromDate(DateTime.now()),
      'resolvedBy': resolvedBy,
    });

    await batch.commit();
  }

  /// Rechazar solicitud de reseteo
  Future<void> rejectPinReset({
    required String requestId,
    required String resolvedBy,
  }) async {
    await _firestore.collection(_requestsCollection).doc(requestId).update({
      'status': RequestStatus.rejected.key,
      'resolvedAt': Timestamp.fromDate(DateTime.now()),
      'resolvedBy': resolvedBy,
    });
  }
}
