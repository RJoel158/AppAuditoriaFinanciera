import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/financial_record.dart';

class CategoryFilterBar extends StatelessWidget {
  final RecordType? selectedType;
  final Function(RecordType?) onTypeSelected;

  const CategoryFilterBar({
    super.key,
    required this.selectedType,
    required this.onTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'Todos',
            icon: Icons.dashboard_outlined,
            isSelected: selectedType == null,
            onTap: () => onTypeSelected(null),
            activeColor: AppColors.secondary,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Ingresos (+)',
            icon: Icons.arrow_downward_rounded,
            isSelected: selectedType == RecordType.income,
            onTap: () => onTypeSelected(RecordType.income),
            activeColor: AppColors.income,
          ),
          const SizedBox(width: 8),
          _buildFilterChip(
            label: 'Gastos (-)',
            icon: Icons.arrow_upward_rounded,
            isSelected: selectedType == RecordType.expense,
            onTap: () => onTypeSelected(RecordType.expense),
            activeColor: AppColors.expense,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color activeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withAlpha(40) : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? activeColor : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
