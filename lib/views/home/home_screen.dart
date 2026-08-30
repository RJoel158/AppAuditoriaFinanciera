import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/family_user.dart';
import '../../models/financial_record.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../admin/admin_panel_screen.dart';
import '../auth/login_screen.dart';
import '../record/add_record_screen.dart';
import '../reports/reports_screen.dart';
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

  Future<void> _handleLogout() async {
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
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _authService.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;
    final userColor = _getUserColor(currentUser);
    final userIcon = _getUserIcon(currentUser);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Auditoría Familiar',
                style: TextStyle(fontSize: 18),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // 1. Badge Informativo del Usuario Autenticado (Protegido contra cambios sin PIN)
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
                  constraints: const BoxConstraints(maxWidth: 80),
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

          // 2. Acceso a Reportes y Diagnóstico IA
          IconButton(
            icon: const Icon(Icons.analytics_outlined, color: AppColors.accent),
            tooltip: 'Reportes e IA',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportsScreen()),
              );
            },
          ),

          // 3. Acceso al Panel de Administración (ESTRICTAMENTE SOLO PARA ADMIN)
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
              tooltip: 'Panel de Administración',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
                );
              },
            ),

          // 4. Menú de Opciones
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'reports') {
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
                value: 'reports',
                child: Row(
                  children: [
                    Icon(Icons.analytics_rounded, size: 18, color: AppColors.accent),
                    SizedBox(width: 8),
                    Text('Reportes & Diagnóstico IA'),
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

          // 2. Barra de Filtros
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

          // 3. Título de sección de registros (Sin desbordamientos)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Registros y Comprobantes',
                      style: TextStyle(
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
