import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/financial_record.dart';

class TransactionTypeToggle extends StatelessWidget {
  final RecordType selectedType;
  final Function(RecordType) onChanged;

  const TransactionTypeToggle({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight.withAlpha(80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Opción Gasto / Egreso
          Expanded(
            child: _buildToggleButton(
              title: 'Gasto / Egreso',
              icon: Icons.arrow_upward_rounded,
              isSelected: selectedType == RecordType.expense,
              activeColor: AppColors.expense,
              onTap: () => onChanged(RecordType.expense),
            ),
          ),
          // Opción Ingreso
          Expanded(
            child: _buildToggleButton(
              title: 'Ingreso / Ahorro',
              icon: Icons.arrow_downward_rounded,
              isSelected: selectedType == RecordType.income,
              activeColor: AppColors.income,
              onTap: () => onChanged(RecordType.income),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(80),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
