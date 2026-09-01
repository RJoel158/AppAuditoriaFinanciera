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
import '../../services/storage_service.dart';


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
  final StorageService _storageService = StorageService();
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
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre Completo / Rol',
                          hintText: 'Ej: Tío Carlos, Hermana',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Alias / Usuario (Login)',
                          hintText: 'Ej: carlos',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Ingresa el alias';
                          if (v.contains(' ')) return 'No uses espacios';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pinController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          labelText: 'PIN de Acceso Inicial',
                          hintText: '4 a 6 dígitos',
                          prefixIcon: Icon(Icons.pin_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 4) return 'Mínimo 4 dígitos';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<UserRole>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Rol en la Familia',
                          prefixIcon: Icon(Icons.shield_outlined),
                        ),

                        items: const [
                          DropdownMenuItem(value: UserRole.member, child: Text('Integrante Familiar')),
                          DropdownMenuItem(value: UserRole.admin, child: Text('Administrador (Acceso Total)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedRole = val);
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
                    nav.pop();
                    try {
                      await _adminService.createFamilyMember(
                        alias: aliasController.text.trim(),
                        displayName: nameController.text.trim(),
                        initialPin: pinController.text.trim(),
                        role: selectedRole,
                        avatarIcon: selectedAvatar,
                      );
                      messenger.showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.primary,
                          content: Text('Integrante creado exitosamente.'),
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.expense,
                          content: Text('Error: $e'),
                        ),
                      );
                    }
                  }
                },
                child: const Text('Crear Integrante'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showChangePinDialog(FamilyUser user) {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Cambiar PIN: ${user.displayName}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nuevo PIN',
                hintText: '4 a 6 dígitos',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              validator: (v) {
                if (v == null || v.length < 4) return 'Mínimo 4 dígitos';
                return null;
              },
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
                  nav.pop();
                  try {
                    await _adminService.changeUserPin(user.id, pinController.text.trim());
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text('PIN de ${user.displayName} actualizado.'),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.expense,
                        content: Text('Error al cambiar PIN: $e'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  void _showResolveResetDialog(PinResetRequest request) {
    final pinController = TextEditingController(text: '1234');
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) {
        final nav = Navigator.of(ctx);
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Resolver Solicitud: ${request.displayName}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'El usuario solicita un nuevo PIN. Puedes asignarle uno provisional o rechazar la solicitud.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: pinController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo PIN Asignado',
                    hintText: '4 a 6 dígitos',
                    prefixIcon: Icon(Icons.key_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 4) return 'Mínimo 4 dígitos';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                nav.pop();
                try {
                  final adminName = _authService.currentUser?.displayName ?? 'Admin';
                  await _adminService.rejectPinReset(
                    requestId: request.id,
                    resolvedBy: adminName,
                  );
                  messenger.showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.surfaceLight,
                      content: Text('Solicitud rechazada.'),
                    ),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.expense,
                      content: Text('Error: $e'),
                    ),
                  );
                }
              },
              child: const Text('Rechazar', style: TextStyle(color: AppColors.expense)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  nav.pop();
                  try {
                    final adminName = _authService.currentUser?.displayName ?? 'Admin';
                    await _adminService.resolvePinReset(
                      requestId: request.id,
                      userId: request.userId,
                      newPin: pinController.text.trim(),
                      resolvedBy: adminName,
                    );
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text('PIN de ${request.displayName} resuelto a: ${pinController.text.trim()}'),
                      ),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.expense,
                        content: Text('Error: $e'),
                      ),
                    );
                  }
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAuditDetailSheet(record),
        borderRadius: BorderRadius.circular(16),
        child: Container(
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

              // 4. Notas y Comprobante (Preview)
              if (record.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Nota: "${record.description}"',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
                    const Text('Comprobante adjunto (Toca para ver)', style: TextStyle(color: AppColors.accent, fontSize: 11)),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔍 Toca para ver detalle completo',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  if (isDeleted)
                    Row(
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.expense,
                            side: const BorderSide(color: AppColors.expense),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _confirmHardDelete(record),
                          child: const Text('Purgar', style: TextStyle(fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.income,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _confirmRestore(record),
                          child: const Text('Restaurar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditDetailSheet(FinancialRecord record) {
    final isDeleted = record.isDeleted;
    final isIncome = record.isIncome;
    final category = AppCategories.getCategoryById(record.category);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barra de arrastre
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 1. Cabecera con Estado
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDeleted ? AppColors.expense : AppColors.income).withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDeleted ? AppColors.expense : AppColors.income),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isDeleted ? Icons.delete_outline_rounded : Icons.check_circle_rounded,
                              size: 14,
                              color: isDeleted ? AppColors.expense : AppColors.income,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isDeleted ? 'REGISTRO ELIMINADO' : 'REGISTRO ACTIVO',
                              style: TextStyle(
                                color: isDeleted ? AppColors.expense : AppColors.income,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // 2. Monto y Tipo
                  Text(
                    '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(record.amount)}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(category.icon, size: 18, color: category.color),
                      const SizedBox(width: 6),
                      Text(
                        category.name,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  // 3. Concepto y Descripción
                  const Text('Concepto:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    record.title.isNotEmpty ? record.title : 'Sin título',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  if (record.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text('Notas / Descripción:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        record.description,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 4. Bloque de Trazabilidad y Auditoría
                  const Text('Historial de Auditoría:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _buildAuditInfoRow(Icons.calendar_today_rounded, 'Fecha de Transacción', DateFormatter.formatFull(record.date)),
                        const Divider(height: 16, color: AppColors.border),
                        _buildAuditInfoRow(Icons.person_outline_rounded, 'Registrado por', '${record.registeredBy}\n${DateFormatter.formatFull(record.createdAt)}'),
                        if (isDeleted) ...[
                          const Divider(height: 16, color: AppColors.border),
                          _buildAuditInfoRow(
                            Icons.delete_forever_rounded,
                            'Eliminado por',
                            '${record.deletedBy ?? "Usuario"}\n${record.deletedAt != null ? DateFormatter.formatFull(record.deletedAt!) : "Recientemente"}',
                            color: AppColors.expense,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 5. Comprobante / Factura con Zoom
                  if (record.imageUrl != null && record.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Comprobante Adjunto:', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: GestureDetector(
                        onTap: () => _openFullscreenImage(record.imageUrl!),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CachedNetworkImage(
                              imageUrl: record.imageUrl!,
                              width: double.infinity,
                              height: 220,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 220,
                                color: AppColors.surfaceLight,
                                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 140,
                                color: AppColors.surfaceLight,
                                child: const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.expense)),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.all(10),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(180),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in_rounded, size: 16, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Toca para ampliar', style: TextStyle(color: Colors.white, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // 6. Botones de Acción
                  if (isDeleted)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.expense,
                              side: const BorderSide(color: AppColors.expense),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmHardDelete(record);
                            },
                            icon: const Icon(Icons.delete_forever_rounded),
                            label: const Text('Borrar Definitivo'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.income,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _confirmRestore(record);
                            },
                            icon: const Icon(Icons.restore_from_trash_rounded),
                            label: const Text('Restaurar', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.expense,
                          side: const BorderSide(color: AppColors.expense),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmSoftDeleteFromAdmin(record);
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Mover a Papelera (Eliminar Lógico)'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color ?? AppColors.textMuted),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: color ?? AppColors.textMuted, fontSize: 12)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color ?? AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _openFullscreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: AppColors.primary),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 50),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSoftDeleteFromAdmin(FinancialRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Archivar este movimiento?'),
        content: const Text(
          'El registro se moverá a la papelera lógica y dejará de sumarse en los balances familiares.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
              final adminUser = _authService.currentUser;
              await _firestoreService.softDeleteRecord(
                record.id,
                deletedBy: adminUser?.displayName ?? 'Administrador',
                deletedByMemberId: adminUser?.id ?? 'admin_user',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.surfaceLight,
                    content: Text('Movimiento archivado en la papelera lógica.'),
                  ),
                );
              }
            },
            child: const Text('Archivar'),
          ),
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
        title: const Text('¿Borrar definitivamente?'),
        content: const Text(
          'Esta acción eliminará el registro y su comprobante permanentemente de la base de datos de Firebase y Cloudinary. No se podrá recuperar.',
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

              if (record.storagePath != null && record.storagePath!.isNotEmpty) {
                await _storageService.deleteImage(record.storagePath!);
              }
              await _firestoreService.hardDeleteRecord(record.id);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: AppColors.expense,
                    content: Text('Registro borrado definitivamente.'),
                  ),
                );
              }
            },
            child: const Text('Borrar Definitivo'),
          ),
        ],
      ),
    );
  }
}


