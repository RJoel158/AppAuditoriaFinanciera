import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/financial_record.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

class RecordDetailSheet extends StatelessWidget {
  final FinancialRecord record;
  final FirestoreService firestoreService;
  final StorageService storageService;

  const RecordDetailSheet({
    super.key,
    required this.record,
    required this.firestoreService,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    final category = AppCategories.getCategoryById(record.category);
    final isIncome = record.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de agarre superior
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabecera: Tipo e Icono
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: category.color.withAlpha(30),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(category.icon, color: category.color, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                record.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '${isIncome ? '+' : '-'}${CurrencyFormatter.format(record.amount)}',
                        style: TextStyle(
                          color: color,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  // Metadatos de Auditoría (Fecha, Registrado por)
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha y Hora',
                    value: DateFormatter.formatFull(record.date),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    icon: Icons.person_outline_rounded,
                    label: 'Registrado por',
                    value: record.registeredBy,
                  ),

                  if (record.description.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Notas / Descripción:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withAlpha(50),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        record.description,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],

                  // Sección Comprobante Adjunto
                  if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Comprobante o Factura:',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _buildReceiptViewer(record.imageUrl!),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  // Botón Eliminar Registro
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.expense,
                        side: const BorderSide(color: AppColors.expense),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                      label: const Text('Eliminar Registro'),
                      onPressed: () => _confirmDelete(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptViewer(String imgUrl) {
    if (imgUrl.startsWith('data:image')) {
      try {
        final base64Content = imgUrl.split(',').last;
        final bytes = base64Decode(base64Content);
        return Image.memory(bytes, fit: BoxFit.contain);
      } catch (_) {}
    }

    return CachedNetworkImage(
      imageUrl: imgUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 150,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image_outlined, color: AppColors.expense, size: 40),
              SizedBox(height: 8),
              Text(
                'No se pudo cargar la imagen del comprobante',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar este registro?'),
        content: const Text(
          'Esta acción borrará la transacción y el comprobante adjunto permanentemente.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              Navigator.pop(ctx);
              Navigator.pop(context);

              if (record.storagePath != null && record.storagePath!.isNotEmpty) {
                await storageService.deleteImage(record.storagePath!);
              }
              await firestoreService.deleteRecord(record.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}
