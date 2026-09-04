import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/financial_record.dart';
import '../../models/siat_invoice.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import '../record/add_record_screen.dart';
import '../record/siat_qr_scanner_screen.dart';
import '../savings/savings_goals_screen.dart';


import 'widgets/balance_header.dart';
import 'widgets/category_filter_bar.dart';
import 'widgets/home_drawer.dart';
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
  final AuthService _authService = AuthService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Búsqueda en tiempo real
  bool _isSearching = false;
  String _searchQuery = '';

  // Paginación y filtros
  int _currentLimit = 15;
  static const int _pageSize = 15;
  bool _isLoadingMore = false;
  RecordType? _selectedType;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Iniciar escucha en tiempo real de notificaciones para movimientos de todos los miembros familiares
    final currentUser = _authService.currentUser;
    NotificationService().startFamilyListener(
      currentUserId: currentUser?.id ?? '',
      currentUserAlias: currentUser?.alias,
      currentUserDisplayName: currentUser?.displayName,
    );
  }

  @override
  void dispose() {
    NotificationService().stopFamilyListener();
    _scrollController.dispose();
    _searchController.dispose();
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

  Future<void> _handleLogout() async {
    NotificationService().stopFamilyListener();
    await _authService.logout();
    if (mounted) {

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  Future<void> _openSiatScanner() async {
    final invoice = await Navigator.push<SiatInvoice>(
      context,
      MaterialPageRoute(builder: (context) => const SiatQrScannerScreen()),
    );
    if (!mounted || invoice == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddRecordScreen(initialSiatInvoice: invoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      drawer: HomeDrawer(
        authService: _authService,
        onSync: () {
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
        onLogout: _handleLogout,
      ),
      appBar: AppBar(
        leading: _isSearching
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              )
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary, size: 24),
                  tooltip: 'Menú principal',
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Buscar por concepto, notas, autor...',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  border: InputBorder.none,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                    onPressed: () {
                      setState(() {
                        if (_searchQuery.isNotEmpty) {
                          _searchQuery = '';
                          _searchController.clear();
                        } else {
                          _isSearching = false;
                        }
                      });
                    },
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              )
            : Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 26,
                      height: 26,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'FamFinance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                  ),
                ],
              ),
        actions: [
          if (!_isSearching) ...[
            // 1. Escanear QR SIAT
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              tooltip: 'Escanear Factura QR (SIAT)',
              onPressed: _openSiatScanner,
            ),
            // 2. Buscar
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
              tooltip: 'Buscar movimientos',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),
            const SizedBox(width: 4),
          ],
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

          // 2. Banner de Acceso Rápido a Metas de Ahorro Familiar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavingsGoalsScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C2419), Color(0xFF133624)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.savings_rounded, color: Color(0xFF10B981), size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Metas de Ahorro Familiar',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            Text(
                              'Planifica vacaciones, emergencias y compras',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF10B981)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Barra de Filtros por Categoría/Tipo
          SliverToBoxAdapter(
            child: CategoryFilterBar(
              selectedType: _selectedType,
              onTypeSelected: (type) {
                setState(() {
                  _selectedType = type;
                  _currentLimit = 15;
                });
              },
            ),
          ),

          // 4. Título de sección de registros
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchQuery.isNotEmpty
                          ? 'Resultados de "$_searchQuery"'
                          : 'Registros y Comprobantes',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Mostrando $_currentLimit',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 5. Lista Reactiva en Tiempo Real con Búsqueda Inteligente
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

              var records = snapshot.data ?? [];

              // Filtrado en vivo de búsqueda inteligente
              if (_searchQuery.trim().isNotEmpty) {
                final query = _searchQuery.trim().toLowerCase();
                records = records.where((r) {
                  final titleMatch = r.title.toLowerCase().contains(query);
                  final descMatch = r.description.toLowerCase().contains(query);
                  final catMatch = r.category.toLowerCase().contains(query);
                  final authorMatch = r.registeredBy.toLowerCase().contains(query);
                  final amountMatch = r.amount.toString().contains(query);
                  return titleMatch || descMatch || catMatch || authorMatch || amountMatch;
                }).toList();
              }


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
                      key: ValueKey(record.id),
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
    final currentUserId = _authService.currentUser?.id ?? '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RecordDetailSheet(
        record: record,
        firestoreService: _firestoreService,
        storageService: _storageService,
        currentUserId: currentUserId,
      ),
    );
  }
}
