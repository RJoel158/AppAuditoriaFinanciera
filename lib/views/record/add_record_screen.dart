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
import '../../services/exchange_rate_service.dart';
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
  double _exchangeRate = ExchangeRateService.fallbackRate; // 10.50

  File? _selectedImage;
  CompressionResult? _compressionResult;
  bool _isCompressing = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadExchangeRate();
  }

  Future<void> _loadExchangeRate() async {
    final rate = await ExchangeRateService.fetchUsdToBobRate();
    if (mounted) {
      setState(() {
        _exchangeRate = rate;
      });
    }
  }

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

                  // 2. Campo de Monto con Selector Integrado (USD / BOB)
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(12),
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto de la transacción *',
                      // Selector elegante BOB / USD integrado
                      prefixIcon: Container(
                        margin: const EdgeInsets.only(left: 8, right: 10, top: 6, bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _selectedCurrency == 'USD'
                              ? AppColors.accent.withAlpha(25)
                              : AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _selectedCurrency == 'USD'
                                ? AppColors.accent.withAlpha(70)
                                : AppColors.primary.withAlpha(70),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCurrency,
                            dropdownColor: AppColors.surface,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                            items: const [
                              DropdownMenuItem(
                                value: 'BOB',
                                child: Text(
                                  'BOB',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'USD',
                                child: Text(
                                  'USD',
                                  style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCurrency = val;
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      hintText: '0.00',
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

                  // Caja de conversión responsiva para USD (Sin desbordamientos)
                  if (_selectedCurrency == 'USD' && enteredAmount > 0) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.accent.withAlpha(40)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'T.C. Referencial: 1 USD = ${_exchangeRate.toStringAsFixed(2)} Bs',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                              ),
                              const Text(
                                'Mercado Actual',
                                style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '≈ Bs ${NumberFormat("#,##0.00", "es_BO").format(convertedAmountBob)}',
                              style: const TextStyle(
                                color: AppColors.accent,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 3. Título / Concepto (Con límite de 50 caracteres)
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

                  // 4. Selector de Categoría
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

                  // 5. Selector de Miembro Familiar y Fecha
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

                  // 6. Comprobante fotográfico con compresión
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

                  // 7. Notas adicionales / Descripción (Con límite de 250 caracteres)
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

                  // 8. Botón de Guardado
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
