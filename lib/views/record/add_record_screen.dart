import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_categories.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/image_compressor.dart';
import '../../models/financial_record.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'widgets/category_dropdown.dart';
import 'widgets/image_upload_card.dart';
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
  final _registeredByController = TextEditingController(text: 'Familia');

  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  RecordType _selectedType = RecordType.expense;
  String _selectedCategory = AppCategories.expenseCategories.first.id;
  DateTime _selectedDate = DateTime.now();

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
    _registeredByController.dispose();
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

      // 2. Crear objeto del registro
      final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
      final newRecord = FinancialRecord(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: amount,
        type: _selectedType,
        category: _selectedCategory,
        imageUrl: imageUrl,
        storagePath: storagePath,
        date: _selectedDate,
        createdAt: DateTime.now(),
        registeredBy: _registeredByController.text.trim().isEmpty
            ? 'Familia'
            : _registeredByController.text.trim(),
      );

      // 3. Guardar en Firestore
      await _firestoreService.addRecord(newRecord);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              '${_selectedType.label} guardado y sincronizado correctamente.',
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

                  // 2. Campo de Monto ($)
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Monto de la transacción *',
                      prefixIcon: const Icon(Icons.attach_money_rounded, size: 28),
                      hintText: '0.00',
                      suffixText: 'USD',
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
                  const SizedBox(height: 14),

                  // 3. Título / Concepto
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Concepto / Título *',
                      hintText: 'Ej. Compra semanal en supermercado',
                      prefixIcon: Icon(Icons.edit_note_rounded),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'El concepto es obligatorio';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

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

                  // 5. Selector de Fecha y Responsable (Diseño Responsivo)
                  Row(
                    children: [
                      // Fecha
                      Expanded(
                        flex: 5,
                        child: InkWell(
                          onTap: _selectDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Fecha',
                              prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            ),
                            child: Text(
                              DateFormat('dd/MM/yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Registrado por
                      Expanded(
                        flex: 5,
                        child: TextFormField(
                          controller: _registeredByController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            labelText: 'Miembro / Autor',
                            prefixIcon: Icon(Icons.person_rounded, size: 18),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                          ),
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

                  // 7. Notas adicionales / Descripción
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notas adicionales (Opcional)',
                      hintText: 'Detalles de la auditoría, observaciones...',
                      alignLabelWithHint: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 24),

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
