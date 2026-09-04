import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/financial_record.dart';

class RecordTile extends StatelessWidget {
  final FinancialRecord record;
  final VoidCallback onTap;

  const RecordTile({
    super.key,
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = AppCategories.getCategoryById(record.category);
    final isIncome = record.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;
    final sign = isIncome ? '+' : '-';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // 1. Icono de Categoría o Miniatura de Comprobante (Fijo)
                _buildLeadingImageOrIcon(category),
                const SizedBox(width: 12),

                // 2. Información Principal (Título, Categoría, Fecha)
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        record.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        softWrap: true,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 5),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: category.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              category.name,
                              style: TextStyle(
                                color: category.color,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            DateFormatter.formatShort(record.date),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (record.paymentMethod == 'qr' || record.paymentMethod == 'card')
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight.withAlpha(90),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    record.paymentMethod == 'qr'
                                        ? Icons.qr_code_rounded
                                        : Icons.credit_card_rounded,
                                    size: 10,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    record.paymentMethod == 'qr' ? 'QR' : 'Tarjeta',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // 3. Monto e Indicador (Escala responsiva sin aplastar el título)
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        alignment: Alignment.centerRight,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$sign${CurrencyFormatter.format(record.amount)}',
                          style: TextStyle(
                            color: color,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_outlined,
                              size: 13,
                              color: AppColors.accent,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'Comprobante',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          record.registeredBy,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeadingImageOrIcon(CategoryItem category) {
    if (record.imageUrl != null && record.imageUrl!.isNotEmpty) {
      final img = record.imageUrl!;
      final lower = img.toLowerCase();
      final isPdf = lower.contains('.pdf') || lower.contains('application/pdf') || lower.contains('/pdf') || lower.contains('factura_siat');

      if (isPdf) {
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.expense.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.expense.withAlpha(60),
              width: 1,
            ),
          ),
          child: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.expense, size: 22),
        );
      }

      if (img.startsWith('data:image')) {
        try {
          final base64Content = img.split(',').last;
          final bytes = base64Decode(base64Content);
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                cacheWidth: 88,
                cacheHeight: 88,
                errorBuilder: (_, __, ___) => _buildFallbackCategoryIcon(category),
              ),
            ),
          );
        } catch (_) {
          return _buildFallbackCategoryIcon(category);
        }
      }

      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 44,
          height: 44,
          child: CachedNetworkImage(
            imageUrl: img,
            fit: BoxFit.cover,
            memCacheWidth: 88,
            memCacheHeight: 88,
            placeholder: (context, url) => Container(
              color: AppColors.surfaceLight,
              child: const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildFallbackCategoryIcon(category),
          ),
        ),
      );
    }

    return _buildFallbackCategoryIcon(category);
  }

  Widget _buildFallbackCategoryIcon(CategoryItem category) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: category.color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: category.color.withAlpha(60),
          width: 1,
        ),
      ),
      child: Icon(category.icon, color: category.color, size: 22),
    );
  }

}
