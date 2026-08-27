import 'package:flutter/material.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });
}

class AppCategories {
  // Categorías de Egresos
  static const List<CategoryItem> expenseCategories = [
    CategoryItem(
      id: 'alimentacion',
      name: 'Alimentación / Super',
      icon: Icons.shopping_cart_outlined,
      color: Color(0xFFF97316),
    ),
    CategoryItem(
      id: 'vivienda',
      name: 'Vivienda / Alquiler',
      icon: Icons.home_outlined,
      color: Color(0xFF6366F1),
    ),
    CategoryItem(
      id: 'servicios',
      name: 'Servicios Básicos (Luz/Agua)',
      icon: Icons.bolt_outlined,
      color: Color(0xFFEAB308),
    ),
    CategoryItem(
      id: 'transporte',
      name: 'Transporte / Gasolina',
      icon: Icons.directions_car_outlined,
      color: Color(0xFF06B6D4),
    ),
    CategoryItem(
      id: 'salud',
      name: 'Salud / Farmacia',
      icon: Icons.medical_services_outlined,
      color: Color(0xFFEC4899),
    ),
    CategoryItem(
      id: 'educacion',
      name: 'Educación / Cursos',
      icon: Icons.school_outlined,
      color: Color(0xFF8B5CF6),
    ),
    CategoryItem(
      id: 'entretenimiento',
      name: 'Ocio / Salidas',
      icon: Icons.movie_outlined,
      color: Color(0xFF14B8A6),
    ),
    CategoryItem(
      id: 'otros_gastos',
      name: 'Otros Gastos',
      icon: Icons.more_horiz_outlined,
      color: Color(0xFF94A3B8),
    ),
  ];

  // Categorías de Ingresos
  static const List<CategoryItem> incomeCategories = [
    CategoryItem(
      id: 'sueldo',
      name: 'Sueldo / Salario',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFF10B981),
    ),
    CategoryItem(
      id: 'ahorros',
      name: 'Fondo de Ahorro',
      icon: Icons.savings_outlined,
      color: Color(0xFF059669),
    ),
    CategoryItem(
      id: 'ventas',
      name: 'Ventas / Negocio',
      icon: Icons.storefront_outlined,
      color: Color(0xFF3B82F6),
    ),
    CategoryItem(
      id: 'inversiones',
      name: 'Inversiones / Rendimientos',
      icon: Icons.trending_up_outlined,
      color: Color(0xFF8B5CF6),
    ),
    CategoryItem(
      id: 'otros_ingresos',
      name: 'Otros Ingresos',
      icon: Icons.monetization_on_outlined,
      color: Color(0xFF34D399),
    ),
  ];

  static CategoryItem getCategoryById(String id) {
    final all = [...expenseCategories, ...incomeCategories];
    return all.firstWhere(
      (c) => c.id == id,
      orElse: () => const CategoryItem(
        id: 'general',
        name: 'General',
        icon: Icons.receipt_long_outlined,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}
