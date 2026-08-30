import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  admin,
  member;

  static UserRole fromString(String value) {
    if (value.toLowerCase() == 'admin' || value.toLowerCase() == 'administrador') {
      return UserRole.admin;
    }
    return UserRole.member;
  }

  String get key => this == UserRole.admin ? 'admin' : 'member';
  String get label => this == UserRole.admin ? 'Administrador' : 'Familiar';
}

class FamilyUser {
  final String id;
  final String alias; // ej: 'papa', 'mama', 'hijo'
  final String displayName; // ej: 'Papá / Admin'
  final UserRole role;
  final String pinHash;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final bool biometricsEnabled;
  final String avatarIcon; // 'admin_panel_settings', 'favorite', 'school', 'person'

  FamilyUser({
    required this.id,
    required this.alias,
    required this.displayName,
    required this.role,
    required this.pinHash,
    this.isActive = true,
    required this.createdAt,
    this.lastLogin,
    this.biometricsEnabled = false,
    this.avatarIcon = 'person',
  });

  bool get isAdmin => role == UserRole.admin;

  Map<String, dynamic> toMap() {
    return {
      'alias': alias.toLowerCase().trim(),
      'displayName': displayName.trim(),
      'role': role.key,
      'pinHash': pinHash,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'biometricsEnabled': biometricsEnabled,
      'avatarIcon': avatarIcon,
    };
  }

  factory FamilyUser.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FamilyUser(
      id: doc.id,
      alias: data['alias'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Miembro Familiar',
      role: UserRole.fromString(data['role'] as String? ?? 'member'),
      pinHash: data['pinHash'] as String? ?? '',
      isActive: data['isActive'] as bool? ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
      biometricsEnabled: data['biometricsEnabled'] as bool? ?? false,
      avatarIcon: data['avatarIcon'] as String? ?? 'person',
    );
  }

  FamilyUser copyWith({
    String? id,
    String? alias,
    String? displayName,
    UserRole? role,
    String? pinHash,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
    bool? biometricsEnabled,
    String? avatarIcon,
  }) {
    return FamilyUser(
      id: id ?? this.id,
      alias: alias ?? this.alias,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      pinHash: pinHash ?? this.pinHash,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
      avatarIcon: avatarIcon ?? this.avatarIcon,
    );
  }
}
