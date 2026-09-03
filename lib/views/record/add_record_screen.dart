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
import '../../models/siat_invoice.dart';
import '../../services/auth_service.dart';
import '../../services/duplicate_checker_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'siat_qr_scanner_screen.dart';
import 'widgets/category_dropdown.dart';

import 'widgets/image_upload_card.dart';
import 'widgets/member_dropdown.dart';
import 'widgets/transaction_type_toggle.dart';

class AddRecordScreen extends StatefulWidget {
  final SiatInvoice? initialSiatInvoice;

  const AddRecordScreen({super.key, this.initialSiatInvoice});

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
  final AuthService _authService = AuthService();
  final DuplicateCheckerService _duplicateChecker = DuplicateCheckerService();

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
    _initLoggedInUser();
    if (widget.initialSiatInvoice != null) {
      _applySiatInvoice(widget.initialSiatInvoice!);
    }
  }

  void _applySiatInvoice(SiatInvoice result) {
    _titleController.text = result.vendorName;
    if (result.amount > 0) {
      _amountController.text = result.amount.toStringAsFixed(2);
    }
    _selectedCurrency = 'BOB';
    _selectedDate = result.date;
    _selectedType = RecordType.expense;
    _selectedCategory = result.suggestedCategory;

    final auditInfo = StringBuffer();
    auditInfo.writeln('Factura N°: ${result.invoiceNumber}');
    if (result.nit.isNotEmpty) auditInfo.writeln('NIT Emisor: ${result.nit}');
    if (result.cuf.isNotEmpty) auditInfo.writeln('CUF: ${result.cuf}');
    if (result.buyerNit != null && result.buyerNit!.isNotEmpty) auditInfo.writeln('NIT Comprador: ${result.buyerNit}');
    _descriptionController.text = auditInfo.toString().trim();

    if (result.downloadedPdfPath != null) {
      _selectedImage = File(result.downloadedPdfPath!);
      _compressionResult = null;
    }
  }


  void _initLoggedInUser() {
    final authUser = _authService.currentUser;
    if (authUser != null) {
      final member = AppMembers.members.firstWhere(
        (m) => m.id == authUser.id || m.name.toLowerCase().contains(authUser.alias),
        orElse: () => FamilyMember(
          id: authUser.id,
          name: authUser.displayName,
          role: authUser.role.label,
          icon: authUser.isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
          color: authUser.isAdmin ? AppColors.primary : const Color(0xFF8B5CF6),
          isAdmin: authUser.isAdmin,
        ),
      );
      setState(() {
        _selectedMember = member;
      });
    }
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

  /// Escanear factura electrónica SIAT de Bolivia y autocompletar el formulario
  Future<void> _scanSiatQrInvoice() async {
    final result = await Navigator.push<SiatInvoice>(
      context,
      MaterialPageRoute(builder: (context) => const SiatQrScannerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _applySiatInvoice(result);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text('¡Factura de "${result.vendorName}" importada y autocompletada!'),
        ),
      );
    }
  }


  Future<void> _submitForm({bool forceSave = false}) async {

    // 1. Bloqueo inmediato anti-doble clic
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final amountInBob = _selectedCurrency == 'USD'
        ? CurrencyFormatter.usdToBob(enteredAmount, rate: _exchangeRate)
        : enteredAmount;

    // 2. Validación Heurística de Duplicados (si no es guardado forzado)
    if (!forceSave) {
      setState(() {
        _isSaving = true; // Bloquea el botón mientras verifica
      });

      final duplicate = await _duplicateChecker.checkPotentialDuplicate(
        amount: amountInBob,
        category: _selectedCategory,
        type: _selectedType,
        date: _selectedDate,
      );

      if (duplicate != null && mounted) {
        setState(() {
          _isSaving = false; // Desbloquea para interactuar con el diálogo
        });

        final categoryItem = AppCategories.getCategoryById(_selectedCategory);
        final diffMinutes = _selectedDate.difference(duplicate.date).inMinutes.abs();
        final timeText = diffMinutes == 0 ? 'hace unos momentos' : 'hace $diffMinutes min';

        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Posible Registro Duplicado',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(
              'Existe un ${_selectedType.label.toLowerCase()} similar de Bs ${amountInBob.toStringAsFixed(2)} en "${categoryItem.name}" registrado $timeText por ${duplicate.registeredBy}.\n\n¿Deseas guardarlo de todos modos?',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar de todos modos', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );

        if (shouldProceed != true) {
          return;
        }
      }
    }

    // 3. Proceso de Guardado
    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      String? imageUrl;
      String? storagePath;

      // Subir imagen si existe
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

      // Crear objeto del registro
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

      // Guardar en Firestore
      await _firestoreService.addRecord(newRecord);

      nav.pop();


      messenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          content: Text(
            '${_selectedType.label} guardado por ${_selectedMember.name} correctamente.',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expense,
            content: Text('Error al guardar registro: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final convertedAmountBob = CurrencyFormatter.usdToBob(enteredAmount, rate: _exchangeRate);
    final isAdmin = _authService.currentUser?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Registro Financiero'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
            tooltip: 'Escanear Factura QR (SIAT)',
            onPressed: _isSaving ? null : _scanSiatQrInvoice,
          ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Banner Destacado: Escanear Factura QR (SIAT Bolivia)
                InkWell(
                  onTap: _isSaving ? null : _scanSiatQrInvoice,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0C2419), Color(0xFF133624)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withAlpha(90)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Escanear Factura QR (SIAT Bolivia)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Autocompleta monto, comercio, NIT y adjunta comprobante',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Selector de Tipo (Ingreso / Egreso)
                TransactionTypeToggle(
                  selectedType: _selectedType,
                  onChanged: _isSaving ? (_) {} : _onTypeChanged,
                ),
                const SizedBox(height: 18),


                // 2. Campo de Monto con Selector Integrado (USD / BOB)
                TextFormField(
                  controller: _amountController,
                  enabled: !_isSaving,
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
                          onChanged: _isSaving
                              ? null
                              : (val) {
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

                // Caja de conversión responsiva para USD
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
                  enabled: !_isSaving,
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
                  onCategoryChanged: _isSaving
                      ? (_) {}
                      : (cat) {
                          setState(() {
                            _selectedCategory = cat;
                          });
                        },
                ),
                const SizedBox(height: 14),

                // 5. Miembro Familiar y Fecha
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Miembro
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Registrado por',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (isAdmin)
                            MemberDropdown(
                              selectedMemberId: _selectedMember.id,
                              onMemberChanged: _isSaving
                                  ? (_) {}
                                  : (member) {
                                      setState(() {
                                        _selectedMember = member;
                                      });
                                    },
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                color: _selectedMember.color.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _selectedMember.color.withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  Icon(_selectedMember.icon, size: 16, color: _selectedMember.color),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedMember.name,
                                      style: TextStyle(
                                        color: _selectedMember.color,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
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
                            onTap: _isSaving ? null : _selectDate,
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
                  onImageSelected: _isSaving ? (_) {} : _handleImageSelected,
                  onRemoveImage: _isSaving ? () {} : _handleRemoveImage,
                ),
                const SizedBox(height: 14),

                // 7. Notas adicionales / Descripción (Con límite de 250 caracteres)
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_isSaving,
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

                // 8. Botón de Guardado con Protección Anti Doble Click
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : () => _submitForm(),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(
                    _isSaving ? 'Guardando...' : 'Guardar y Sincronizar Registro',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // 9. Overlay semi-transparente durante el guardado
          if (_isSaving)
            Container(
              color: Colors.black.withAlpha(160),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                      const SizedBox(height: 16),
                      const Text(
                        'Guardando en Firestore...',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                      ),
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Subiendo comprobante: ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
