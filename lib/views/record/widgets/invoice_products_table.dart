import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/financial_record.dart';

class InvoiceProductsTable extends StatelessWidget {
  final List<InvoiceItem> items;
  final bool isEditable;
  final Function(int index)? onDeleteItem;

  const InvoiceProductsTable({
    super.key,
    required this.items,
    this.isEditable = false,
    this.onDeleteItem,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final total = items.fold<double>(0.0, (sum, i) => sum + i.subtotal);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(80), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Cabecera Responsiva (Sin Desbordamiento)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Detalle de Productos Facturados',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${items.length} ítems',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Tabla con Scroll Horizontal Responsivo
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Encabezados
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: AppColors.surfaceLight.withAlpha(60),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            'CANT.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 170,
                          child: Text(
                            'DESCRIPCIÓN',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        SizedBox(
                          width: 65,
                          child: Text(
                            'P. UNIT.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(
                            'SUBTOTAL',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.bold),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.border),

                  // Filas de productos
                  ...items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final isEven = idx % 2 == 0;

                    return Container(
                      color: isEven ? Colors.transparent : AppColors.surfaceLight.withAlpha(25),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      child: Row(
                        children: [
                          // Cantidad con Chip
                          SizedBox(
                            width: 46,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _formatQuantity(item.quantity),
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Descripción
                          SizedBox(
                            width: 170,
                            child: Text(
                              item.description,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Precio Unitario
                          SizedBox(
                            width: 65,
                            child: Text(
                              item.unitPrice.toStringAsFixed(2),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),

                          // Subtotal
                          SizedBox(
                            width: 75,
                            child: Text(
                              'Bs ${item.subtotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // 3. Pie de Tabla con Total Declarado
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(10),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.calculate_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Total Facturado:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Bs ${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double q) {
    if (q == q.roundToDouble()) {
      return q.toInt().toString();
    }
    return q.toStringAsFixed(2);
  }
}
