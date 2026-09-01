import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_categories.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/family_user.dart';
import '../../models/financial_record.dart';
import '../../models/pin_reset_request.dart';
import '../../services/admin_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final AdminService _adminService = AdminService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String _auditFilter = 'all'; // 'all', 'active', 'deleted'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }


  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getAvatarIcon(String name) {
    switch (name) {
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

  Color _getAvatarColor(FamilyUser user) {
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

  void _showAddMemberDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final aliasController = TextEditingController();
    final pinController = TextEditingController(text: '1234');
    UserRole selectedRole = UserRole.member;
    const selectedAvatar = 'person';
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Nuevo Integrante Familiar',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            content: SizedBox(
              width: MediaQuery.of(ctx).size.width,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo *',
                          hintText: 'ej. Tía Carmen',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Alias único (Login) *',
                          hintText: 'ej. carmen',
                          prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un alias' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'PIN Inicial (4-6 dígitos) *',
                          hintText: '1234',
                          prefixIcon: Icon(Icons.pin_outlined, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 10),
                        ),
                        validator: (v) => v == null || v.trim().length < 4 ? 'Mínimo 4 dígitos' : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol en la Familia',
                          prefixIcon: Icon(Icons.security_rounded, size: 20),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        dropdownColor: AppColors.surface,
                        items: const [
                          DropdownMenuItem(
                            value: UserRole.member,
                            child: Text('Familiar (Registro & Vista)', style: TextStyle(fontSize: 13)),
                          ),
                          DropdownMenuItem(
                            value: UserRole.admin,
                            child: Text('Administrador (Acceso total)', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                        onChanged: (r) {
                          if (r != null) {
                            setDialogState(() => selectedRole = r);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => nav.pop(),
                child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      await _adminService.createFamilyMember(
                        displayName: nameController.text.trim(),
                        alias: aliasController.text.trim(),
                        role: selectedRole,
                        initialPin: pinController.text.trim(),
                        avatarIcon: selectedAvatar,
                      );
                      nav.pop();
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.primary,
                          content: Text('Integrante "${nameController.text.trim()}" agregado exitosamente.'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(backgroundColor: AppColors.expense, content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePinDialog(FamilyUser user) {
    final pinController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Cambiar PIN de ${user.displayName}'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Nuevo PIN (4 a 6 dígitos)',
              hintText: 'ej. 5678',
              prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => nav.pop(),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final newPin = pinController.text.trim();
                if (newPin.length >= 4) {
                  await _adminService.changeUserPin(user.id, newPin);
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('PIN de ${user.displayName} actualizado a "$newPin".'),
                    ),
                  );
                }
              },
              child: const Text('Actualizar'),
            ),
          ],
        );
      },
    );
  }

  void _showResolveResetDialog(PinResetRequest request) {
    final newPinController = TextEditingController(text: '1234');
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Restablecer PIN de ${request.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Alias: @${request.alias}', style: const TextStyle(color: AppColors.textSecondary)),
              if (request.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Mensaje: "${request.note}"', style: const TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: newPinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Asignar Nuevo PIN',
                  prefixIcon: Icon(Icons.key_rounded, size: 20),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final adminName = _authService.currentUser?.displayName ?? 'Admin';
                await _adminService.rejectPinReset(requestId: request.id, resolvedBy: adminName);
                nav.pop();
              },
              child: const Text('Rechazar', style: TextStyle(color: AppColors.expense)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                final newPin = newPinController.text.trim();
                if (newPin.length >= 4) {
                  final adminName = _authService.currentUser?.displayName ?? 'Admin';
                  await _adminService.resolvePinReset(
                    requestId: request.id,
                    userId: request.userId,
                    newPin: newPin,
                    resolvedBy: adminName,
                  );
                  nav.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.primary,
                      content: Text('PIN restablecido a "$newPin" para @${request.alias}.'),
                    ),
                  );
                }
              },
              child: const Text('Aprobar y Asignar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            const Tab(
              icon: Icon(Icons.people_outline_rounded, size: 20),
              text: 'Integrantes',
            ),
            Tab(
              child: StreamBuilder<List<PinResetRequest>>(
                stream: _adminService.getPendingRequestsStream(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_reset_rounded, size: 20),
                      const SizedBox(width: 6),
                      const Text('Solicitudes'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: AppColors.expense,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const Tab(
              icon: Icon(Icons.history_edu_rounded, size: 20),
              text: 'Auditoría',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMembersTab(),
          _buildRequestsTab(),
          _buildAuditTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _showAddMemberDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              label: const Text('Nuevo Integrante', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }


  Widget _buildMembersTab() {
    return StreamBuilder<List<FamilyUser>>(
      stream: _adminService.getFamilyUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final users = snapshot.data ?? [];
        if (users.isEmpty) {
          return const Center(
            child: Text('No hay integrantes registrados.', style: TextStyle(color: AppColors.textSecondary)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final color = _getAvatarColor(user);
            final icon = _getAvatarIcon(user.avatarIcon);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: user.isActive ? AppColors.border : AppColors.expense.withAlpha(80),
                ),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: TextStyle(
                          color: user.isActive ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: user.isAdmin ? AppColors.primary.withAlpha(25) : AppColors.surfaceLight.withAlpha(60),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        user.role.label,
                        style: TextStyle(
                          color: user.isAdmin ? AppColors.primary : AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Alias: @${user.alias} • ${user.isActive ? "Activo" : "Desactivado"}',
                  style: TextStyle(
                    color: user.isActive ? AppColors.textMuted : AppColors.expense,
                    fontSize: 12,
                  ),
                ),
                trailing: PopupMenuButton<String>(
                  color: AppColors.surface,
                  icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                  onSelected: (val) {
                    if (val == 'pin') {
                      _showChangePinDialog(user);
                    } else if (val == 'status') {
                      _adminService.updateUserStatus(user.id, !user.isActive);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(Icons.key_rounded, size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Cambiar PIN'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'status',
                      child: Row(
                        children: [
                          Icon(
                            user.isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded,
                            size: 18,
                            color: user.isActive ? AppColors.expense : AppColors.income,
                          ),
                          SizedBox(width: 8),
                          Text(user.isActive ? 'Desactivar Cuenta' : 'Activar Cuenta'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    return StreamBuilder<List<PinResetRequest>>(
      stream: _adminService.getAllRequestsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final requests = snapshot.data ?? [];
        if (requests.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mark_email_read_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: 12),
                Text('No hay solicitudes de recuperación.', style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final isPending = req.isPending;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPending ? AppColors.accent.withAlpha(120) : AppColors.border,
                  width: isPending ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isPending ? Icons.pending_actions_rounded : Icons.task_alt_rounded,
                            color: isPending ? AppColors.accent : AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            req.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isPending ? AppColors.accent.withAlpha(25) : AppColors.primary.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          req.status.label,
                          style: TextStyle(
                            color: isPending ? AppColors.accent : AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Alias: @${req.alias} • Solicitado: ${DateFormatter.formatShort(req.requestedAt)}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  if (req.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Mensaje: "${req.note}"',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ],
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                          onPressed: () => _showResolveResetDialog(req),
                          icon: const Icon(Icons.key_rounded, size: 16),
                          label: const Text('Asignar Nuevo PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditTab() {
    return StreamBuilder<List<FinancialRecord>>(
      stream: _firestoreService.getAuditRecordsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final allRecords = snapshot.data ?? [];
        final activeRecords = allRecords.where((r) => !r.isDeleted).toList();
        final deletedRecords = allRecords.where((r) => r.isDeleted).toList();

        List<FinancialRecord> displayedRecords;
        if (_auditFilter == 'active') {
          displayedRecords = activeRecords;
        } else if (_auditFilter == 'deleted') {
          displayedRecords = deletedRecords;
        } else {
          displayedRecords = allRecords;
        }

        return Column(
          children: [
            // Filtros de Auditoría
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildAuditFilterChip('all', 'Todos (${allRecords.length})', Icons.list_alt_rounded),
                    const SizedBox(width: 8),
                    _buildAuditFilterChip('active', '🟢 Activos (${activeRecords.length})', Icons.check_circle_rounded),
                    const SizedBox(width: 8),
                    _buildAuditFilterChip('deleted', '🗑️ Eliminados (${deletedRecords.length})', Icons.delete_sweep_rounded),
                  ],
                ),
              ),
            ),

            if (displayedRecords.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _auditFilter == 'deleted' ? Icons.delete_outline_rounded : Icons.history_rounded,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _auditFilter == 'deleted'
                            ? 'No hay registros en la papelera de eliminación lógica.'
                            : 'No hay registros en el historial.',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: displayedRecords.length,
                  itemBuilder: (context, index) {
                    final record = displayedRecords[index];
                    return _buildAuditRecordCard(record);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAuditFilterChip(String key, String label, IconData icon) {
    final isSelected = _auditFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
      backgroundColor: AppColors.surfaceLight.withAlpha(50),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        setState(() {
          _auditFilter = key;
        });
      },
    );
  }

  Widget _buildAuditRecordCard(FinancialRecord record) {
    final isDeleted = record.isDeleted;
    final isIncome = record.isIncome;
    final category = AppCategories.getCategoryById(record.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDeleted ? AppColors.expense.withAlpha(100) : AppColors.border,
          width: isDeleted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera con Estado y Monto
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: (isDeleted ? AppColors.expense : (isIncome ? AppColors.income : AppColors.primary)).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDeleted ? Icons.delete_outline_rounded : category.icon,
                      color: isDeleted ? AppColors.expense : category.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.title.isNotEmpty ? record.title : category.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDeleted ? AppColors.textMuted : AppColors.textPrimary,
                          decoration: isDeleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      Text(
                        category.name,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(record.amount)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDeleted
                          ? AppColors.textMuted
                          : (isIncome ? AppColors.income : AppColors.expense),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (isDeleted ? AppColors.expense : AppColors.income).withAlpha(25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isDeleted ? 'ELIMINADO' : 'ACTIVO',
                      style: TextStyle(
                        color: isDeleted ? AppColors.expense : AppColors.income,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 8),

          // 2. Trazabilidad: Quién lo creó
          Row(
            children: [
              const Icon(Icons.person_add_alt_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Creado por: ${record.registeredBy} • ${DateFormatter.formatFull(record.createdAt)}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ),
            ],
          ),

          // 3. Trazabilidad: Quién lo eliminó (si aplica)
          if (isDeleted) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.expense.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.expense.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever_rounded, size: 15, color: AppColors.expense),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Eliminado por: ${record.deletedBy ?? "Usuario"} • ${record.deletedAt != null ? DateFormatter.formatFull(record.deletedAt!) : "Recientemente"}',
                      style: const TextStyle(
                        color: AppColors.expense,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],


          // 4. Notas y Comprobante
          if (record.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nota: "${record.description}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],

          if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: CachedNetworkImage(
                    imageUrl: record.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(color: AppColors.surfaceLight, width: 44, height: 44),
                    errorWidget: (_, __, ___) => const Icon(Icons.receipt_long_rounded, size: 24),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Comprobante adjunto', style: TextStyle(color: AppColors.accent, fontSize: 11)),
              ],
            ),
          ],

          // 5. Botones de Acción para Administrador
          if (isDeleted) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.expense,
                    side: const BorderSide(color: AppColors.expense),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => _confirmHardDelete(record),
                  icon: const Icon(Icons.delete_forever_rounded, size: 14),
                  label: const Text('Purgar', style: TextStyle(fontSize: 11)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => _confirmRestore(record),
                  icon: const Icon(Icons.restore_from_trash_rounded, size: 14),
                  label: const Text('Restaurar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRestore(FinancialRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Restaurar movimiento?'),
        content: Text(
          'El registro de "${record.title.isNotEmpty ? record.title : record.category}" por ${CurrencyFormatter.format(record.amount)} volverá a sumarse en los balances familiares y estará visible nuevamente en la pantalla principal.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),

        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.income),
            onPressed: () async {
              Navigator.pop(ctx);
              await _firestoreService.restoreRecord(record.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.income,
                    content: Text('Movimiento restaurado exitosamente.'),
                  ),
                );
              }
            },
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  void _confirmHardDelete(FinancialRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Purgar permanentemente?'),
        content: const Text(
          'Esta acción eliminará el registro de forma definitiva de la base de datos y no se podrá recuperar de ningún historial.',
          style: TextStyle(color: AppColors.expense, fontSize: 13),
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
              await _firestoreService.hardDeleteRecord(record.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.expense,
                    content: Text('Registro purgado de forma definitiva.'),
                  ),
                );
              }
            },
            child: const Text('Purgar Definitivo'),
          ),
        ],
      ),
    );
  }
}

