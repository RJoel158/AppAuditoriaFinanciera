import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_categories.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_members.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/financial_record.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';

class RecordDetailSheet extends StatelessWidget {
  final FinancialRecord record;
  final FirestoreService firestoreService;
  final StorageService storageService;
  final String currentUserId;

  const RecordDetailSheet({
    super.key,
    required this.record,
    required this.firestoreService,
    required this.storageService,
    this.currentUserId = 'admin_papa',
  });

  bool get _canDelete {
    final currentMember = AppMembers.getMemberById(currentUserId);
    return currentMember.isAdmin || record.memberId == currentUserId || record.registeredBy == currentMember.name;
  }

  @override
  Widget build(BuildContext context) {
    final category = AppCategories.getCategoryById(record.category);
    final member = AppMembers.getMemberById(record.memberId);
    final isIncome = record.isIncome;
    final color = isIncome ? AppColors.income : AppColors.expense;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Cabecera Responsiva: Icono + Título + Monto
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icono de categoría
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: category.color.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(category.icon, color: category.color, size: 22),
                      ),
                      const SizedBox(width: 12),

                      // Título y Categoría (Flexible)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              record.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Monto en Bs + Detalle en USD si aplica
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              alignment: Alignment.centerRight,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${isIncome ? '+' : '-'}${CurrencyFormatter.format(record.amount)}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (record.currency == 'USD')
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent.withAlpha(25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${record.originalAmount.toStringAsFixed(2)} USD',
                                  style: const TextStyle(
                                    color: AppColors.accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 14),

                  // 2. Metadatos de Auditoría (Fecha y Miembro)
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha y Hora',
                    value: DateFormatter.formatFull(record.date),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(member.icon, size: 18, color: member.color),
                      const SizedBox(width: 10),
                      const Text(
                        'Registrado por: ',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: member.color.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                record.registeredBy,
                                style: TextStyle(
                                  color: member.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // 3. Notas / Descripción
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

                  // 4. Sección Comprobante Adjunto (Con soporte para Zoom Pantalla Completa)
                  if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Comprobante o Factura:',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _openFullscreenViewer(context, record.imageUrl!),
                          icon: const Icon(Icons.zoom_in_rounded, size: 16, color: AppColors.accent),
                          label: const Text(
                            'Ver con Zoom',
                            style: TextStyle(fontSize: 12, color: AppColors.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => _openFullscreenViewer(context, record.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 280),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _buildReceiptViewer(record.imageUrl!),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // 5. Botón Eliminar Registro
                  if (_canDelete)
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
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Solo el creador o el Administrador pueden eliminar este registro.',
                              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
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
        height: 180,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      errorWidget: (context, url, error) => const SizedBox(
        height: 140,
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

  void _openFullscreenViewer(BuildContext context, String imgUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text('Comprobante en Alta Resolución'),
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 5.0,
              child: _buildReceiptViewer(imgUrl),
            ),
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(width: 6),
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
