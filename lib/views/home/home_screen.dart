import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/financial_record.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../record/add_record_screen.dart';
import 'widgets/balance_header.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/record_detail_sheet.dart';
import 'widgets/record_tile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();
  final ScrollController _scrollController = ScrollController();

  // Paginación y filtros
  int _currentLimit = 15;
  static const int _pageSize = 15;
  bool _isLoadingMore = false;
  RecordType? _selectedType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentLimit += _pageSize;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
            SizedBox(width: 10),
            Text('Auditoría Familiar'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restablecer paginación',
            onPressed: () {
              setState(() {
                _currentLimit = 15;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sincronizando registros en tiempo real...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 1. Cabecera de Balance en Tiempo Real
          SliverToBoxAdapter(
            child: StreamBuilder<Map<String, double>>(
              stream: _firestoreService.getSummaryStream(),
              builder: (context, snapshot) {
                final data = snapshot.data ?? {
                  'totalIncome': 0.0,
                  'totalExpense': 0.0,
                  'balance': 0.0,
                };
                return BalanceHeader(
                  balance: data['balance'] ?? 0.0,
                  totalIncome: data['totalIncome'] ?? 0.0,
                  totalExpense: data['totalExpense'] ?? 0.0,
                );
              },
            ),
          ),

          // 2. Barra de Filtros
          SliverToBoxAdapter(
            child: CategoryFilterBar(
              selectedType: _selectedType,
              onTypeSelected: (type) {
                setState(() {
                  _selectedType = type;
                  _currentLimit = 15; // Resetear límite al cambiar de filtro
                });
              },
            ),
          ),

          // 3. Título de sección de registros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Registros y Comprobantes',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Límite: $_currentLimit',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Lista Reactiva en Tiempo Real con StreamBuilder
          StreamBuilder<List<FinancialRecord>>(
            stream: _firestoreService.getRecordsStream(
              limit: _currentLimit,
              filterType: _selectedType,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }

              if (snapshot.hasError) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.cloud_off_rounded, color: AppColors.expense, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Error al conectar con Firestore:\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              final records = snapshot.data ?? [];

              if (records.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: AppColors.textMuted.withAlpha(120),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay registros para mostrar',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Presiona el botón "+" para registrar un ingreso o gasto',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = records[index];
                    return RecordTile(
                      record: record,
                      onTap: () => _openRecordDetail(record),
                    );
                  },
                  childCount: records.length,
                ),
              );
            },
          ),

          // 5. Indicador de Carga de más elementos (Paginación)
          if (_isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddRecordScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Nuevo Registro',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _openRecordDetail(FinancialRecord record) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordDetailSheet(
        record: record,
        firestoreService: _firestoreService,
        storageService: _storageService,
      ),
    );
  }
}
