import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_categories.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_members.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/image_compressor.dart';
import '../../models/financial_record.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'widgets/category_dropdown.dart';
import 'widgets/image_upload_card.dart';
import 'widgets/member_dropdown.dart';
import 'widgets/transaction_type_toggle.dart';

class AddRecordScreen extends StatefulWidget {
  const AddRecordScreen({super.key});

  @override
  State<AddRecordScreen> createState() => _AddRecordScreenState();
}

class _AddRecordScreenState extends State<AddRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  RecordType _selectedType = RecordType.expense;
  String _selectedCategory = AppCategories.expenseCategories.first.id;
  DateTime _selectedDate = DateTime.now();
  FamilyMember _selectedMember = AppMembers.members.first;

  // Moneda: 'BOB' (Bolivianos) o 'USD' (Dólares)
  String _selectedCurrency = 'BOB';
  final double _exchangeRate = CurrencyFormatter.defaultUsdRate; // 6.96

  File? _selectedImage;
  CompressionResult? _compressionResult;
  bool _isCompressing = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onTypeChanged(RecordType type) {
    setState(() {
      _selectedType = type;
      _selectedCategory = type == RecordType.expense
          ? AppCategories.expenseCategories.first.id
          : AppCategories.incomeCategories.first.id;
    });
  }

  Future<void> _handleImageSelected(File file) async {
    setState(() {
      _selectedImage = file;
      _isCompressing = true;
    });

    final result = await ImageCompressorUtil.compressImage(file);

    if (mounted) {
      setState(() {
        _compressionResult = result;
        _isCompressing = false;
      });
    }
  }

  void _handleRemoveImage() {
    setState(() {
      _selectedImage = null;
      _compressionResult = null;
    });
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      String? imageUrl;
      String? storagePath;

      // 1. Subir imagen comprimida
      if (_selectedImage != null) {
        final uploadResult = await _storageService.uploadReceiptImage(
          imageFile: _selectedImage!,
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _uploadProgress = progress;
              });
            }
          },
        );
        imageUrl = uploadResult.downloadUrl;
        storagePath = uploadResult.storagePath;
      }

      // 2. Calcular montos con tipo de cambio
      final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      final amountInBob = _selectedCurrency == 'USD'
          ? CurrencyFormatter.usdToBob(enteredAmount, rate: _exchangeRate)
          : enteredAmount;

      final newRecord = FinancialRecord(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: amountInBob,
        originalAmount: enteredAmount,
        currency: _selectedCurrency,
        exchangeRate: _exchangeRate,
        type: _selectedType,
        category: _selectedCategory,
        imageUrl: imageUrl,
        storagePath: storagePath,
        date: _selectedDate,
        createdAt: DateTime.now(),
        registeredBy: _selectedMember.name,
        memberId: _selectedMember.id,
      );

      // 3. Guardar en Firestore
      await _firestoreService.addRecord(newRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              '${_selectedType.label} guardado por ${_selectedMember.name} correctamente.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expense,
            content: Text('Error al guardar registro: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cálculo en vivo de conversión
    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final convertedAmountBob = CurrencyFormatter.usdToBob(enteredAmount, rate: _exchangeRate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Registro Financiero'),
      ),
      body: _isSaving
          ? _buildSavingOverlay()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // 1. Selector de Tipo (Ingreso / Egreso)
                  TransactionTypeToggle(
                    selectedType: _selectedType,
                    onChanged: _onTypeChanged,
                  ),
                  const SizedBox(height: 18),

                  // 2. Selector de Moneda (Bolivianos Bs / Dólares USD)
                  Row(
                    children: [
                      const Text(
                        'Moneda:',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildCurrencyChip(
                        label: 'Bolivianos (Bs)',
                        code: 'BOB',
                        icon: Icons.monetization_on_outlined,
                      ),
                      const SizedBox(width: 8),
                      _buildCurrencyChip(
                        label: 'Dólares (\$)',
                        code: 'USD',
                        icon: Icons.attach_money_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3. Campo de Monto ($) con validación y formateo
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto de la transacción *',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        child: Text(
                          _selectedCurrency == 'USD' ? '\$' : 'Bs',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      hintText: '0.00',
                      suffixText: _selectedCurrency,
                      suffixStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Ingresa un monto válido';
                      }
                      final parsed = double.tryParse(val.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'El monto debe ser mayor a 0';
                      }
                      return null;
                    },
                  ),

                  // Indicador de conversión en vivo si es USD
                  if (_selectedCurrency == 'USD' && enteredAmount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withAlpha(60)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'T.C. Referencial: 1 USD = $_exchangeRate Bs',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                          Text(
                            '≈ Bs ${convertedAmountBob.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 14),

                  // 4. Título / Concepto (Con límite de 50 caracteres)
                  TextFormField(
                    controller: _titleController,
                    maxLength: 50,
                    decoration: const InputDecoration(
                      labelText: 'Concepto / Título *',
                      hintText: 'Ej. Compra semanal en supermercado',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El concepto es obligatorio';
                      }
                      if (val.trim().length < 3) {
                        return 'Debe tener al menos 3 caracteres';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),

                  // 5. Selector de Categoría
                  const Text(
                    'Categoría',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CategoryDropdown(
                    recordType: _selectedType,
                    selectedCategory: _selectedCategory,
                    onCategoryChanged: (cat) {
                      setState(() {
                        _selectedCategory = cat;
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  // 6. Selector de Miembro Familiar y Fecha
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Miembro
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Miembro',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            MemberDropdown(
                              selectedMemberId: _selectedMember.id,
                              onMemberChanged: (member) {
                                setState(() {
                                  _selectedMember = member;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Selector de Fecha
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Fecha',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight.withAlpha(80),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 7. Comprobante fotográfico con compresión
                  const Text(
                    'Comprobante o Factura (Opcional)',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ImageUploadCard(
                    selectedImageFile: _selectedImage,
                    compressionResult: _compressionResult,
                    isCompressing: _isCompressing,
                    onImageSelected: _handleImageSelected,
                    onRemoveImage: _handleRemoveImage,
                  ),
                  const SizedBox(height: 14),

                  // 8. Notas adicionales / Descripción (Con límite de 250 caracteres)
                  TextFormField(
                    controller: _descriptionController,
                    maxLength: 250,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notas adicionales (Opcional)',
                      hintText: 'Detalles de la auditoría, observaciones...',
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 9. Botón de Guardado
                  ElevatedButton.icon(
                    onPressed: _submitForm,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text(
                      'Guardar y Sincronizar Registro',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCurrencyChip({
    required String label,
    required String code,
    required IconData icon,
  }) {
    final isSelected = _selectedCurrency == code;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCurrency = code;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : AppColors.surfaceLight.withAlpha(60),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            const Text(
              'Guardando y Sincronizando...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_selectedImage != null) ...[
              Text(
                'Subiendo comprobante optimizado: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ] else
              const Text(
                'Enviando a Firebase Firestore...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
