import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/family_user.dart';
import '../../models/financial_record.dart';
import '../../models/siat_invoice.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../services/storage_service.dart';
import '../admin/admin_panel_screen.dart';
import '../ai_advisor/financial_advisor_chat_screen.dart';
import '../auth/login_screen.dart';
import '../record/add_record_screen.dart';
import '../record/siat_qr_scanner_screen.dart';
import '../reports/reports_screen.dart';
import '../savings/savings_goals_screen.dart';

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

    // Iniciar escucha en tiempo real de notificaciones para movimientos de otros familiares
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      NotificationService().startFamilyListener(
        currentUserId: currentUser.id,
        currentUserAlias: currentUser.alias,
        currentUserDisplayName: currentUser.displayName,
      );
    }
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

  IconData _getUserIcon(FamilyUser? user) {
    if (user == null) return Icons.person_rounded;
    switch (user.avatarIcon) {
      case 'admin_panel_settings':
        return Icons.admin_panel_settings_rounded;
      case 'favorite':
        return Icons.favorite_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color _getUserColor(FamilyUser? user) {
    if (user == null) return AppColors.primary;
    if (user.isAdmin) return AppColors.primary;
    switch (user.avatarIcon) {
      case 'favorite':
        return const Color(0xFFEC4899);
      case 'school':
        return const Color(0xFF38BDF8);
      default:
        return const Color(0xFF8B5CF6);
    }
  }  Future<void> _openSiatScanner() async {
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
    final currentUser = _authService.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    final userColor = _getUserColor(currentUser);
    final userIcon = _getUserIcon(currentUser);

    return Scaffold(
      appBar: AppBar(
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
                      width: 28,
                      height: 28,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'FamFinance',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

        actions: [
          // Botón Escanear Factura QR (SIAT)
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
              tooltip: 'Escanear Factura QR (SIAT)',
              onPressed: _openSiatScanner,
            ),

          // Botón Activar Búsqueda
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppColors.textPrimary),
              tooltip: 'Buscar movimientos',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
              },
            ),

          if (!_isSearching) ...[
            // 1. Badge Informativo del Usuario Autenticado
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: userColor.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: userColor.withAlpha(70)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(userIcon, size: 15, color: userColor),
                  const SizedBox(width: 5),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 75),
                    child: Text(
                      currentUser?.displayName.split(' ').first ?? 'Usuario',
                      style: TextStyle(
                        color: userColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(40),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 2. Acceso al Asesor Financiero IA Interactivo
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
              tooltip: 'Asesor Familiar IA',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FinancialAdvisorChatScreen()),
                );
              },
            ),

            // 3. Menú de Opciones
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'scan_siat') {
                  _openSiatScanner();
                } else if (val == 'savings') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SavingsGoalsScreen()),
                  );
                } else if (val == 'chat') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FinancialAdvisorChatScreen()),
                  );
                } else if (val == 'reports') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportsScreen()),
                  );
                } else if (val == 'sync') {
                  setState(() {
                    _currentLimit = 15;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sincronizando registros en tiempo real...'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                } else if (val == 'admin' && isAdmin) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                  );
                } else if (val == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'scan_siat',
                  child: Row(
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Escanear Factura (SIAT)'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'savings',

                  child: Row(
                    children: [
                      Icon(Icons.savings_rounded, size: 18, color: Color(0xFF10B981)),
                      SizedBox(width: 8),
                      Text('Metas de Ahorro'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'chat',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Asesor Financiero IA'),
                    ],
                  ),
                ),

                const PopupMenuItem(
                  value: 'reports',
                  child: Row(
                    children: [
                      Icon(Icons.analytics_rounded, size: 18, color: AppColors.accent),
                      SizedBox(width: 8),
                      Text('Reportes & PDF'),
                    ],
                  ),
                ),

                if (isAdmin)
                  const PopupMenuItem(
                    value: 'admin',
                    child: Row(
                      children: [
                        Icon(Icons.admin_panel_settings_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Panel Admin Familiar'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'sync',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18, color: AppColors.textSecondary),
                      SizedBox(width: 8),
                      Text('Sincronizar'),
                    ],
                  ),
                ),

                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.accent),
                      SizedBox(width: 8),
                      Text('Cambiar Usuario', style: TextStyle(color: AppColors.accent)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, size: 18, color: AppColors.expense),
                      SizedBox(width: 8),
                      Text('Cerrar Sesión', style: TextStyle(color: AppColors.expense)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 4),
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
