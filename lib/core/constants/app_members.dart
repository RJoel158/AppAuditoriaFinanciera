import 'package:flutter/material.dart';

class FamilyMember {
  final String id;
  final String name;
  final String role;
  final IconData icon;
  final Color color;
  final bool isAdmin;

  const FamilyMember({
    required this.id,
    required this.name,
    required this.role,
    required this.icon,
    required this.color,
    this.isAdmin = false,
  });
}

class AppMembers {
  // Lista de Miembros de la Familia
  static const List<FamilyMember> members = [
    FamilyMember(
      id: 'admin_papa',
      name: 'Papá / Admin',
      role: 'Administrador',
      icon: Icons.admin_panel_settings_rounded,
      color: Color(0xFF10B981),
      isAdmin: true,
    ),
    FamilyMember(
      id: 'mama',
      name: 'Mamá',
      role: 'Familiar',
      icon: Icons.favorite_rounded,
      color: Color(0xFFEC4899),
    ),
    FamilyMember(
      id: 'hijo_1',
      name: 'Hijo / Hija',
      role: 'Familiar',
      icon: Icons.school_rounded,
      color: Color(0xFF38BDF8),
    ),
    FamilyMember(
      id: 'otro_familiar',
      name: 'Otro Familiar',
      role: 'Familiar',
      icon: Icons.person_rounded,
      color: Color(0xFF8B5CF6),
    ),
  ];

  static FamilyMember getMemberById(String id) {
    return members.firstWhere(
      (m) => m.id == id || m.name == id,
      orElse: () => members.first,
    );
  }
}
