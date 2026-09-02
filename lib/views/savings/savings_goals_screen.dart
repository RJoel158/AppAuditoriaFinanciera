import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_members.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/savings_goal.dart';
import '../../services/auth_service.dart';
import '../../services/savings_goal_service.dart';

class SavingsGoalsScreen extends StatefulWidget {
  const SavingsGoalsScreen({super.key});

  @override
  State<SavingsGoalsScreen> createState() => _SavingsGoalsScreenState();
}

class _SavingsGoalsScreenState extends State<SavingsGoalsScreen> {
  final SavingsGoalService _savingsService = SavingsGoalService();
  final AuthService _authService = AuthService();

  static const List<Map<String, dynamic>> _availableIcons = [
    {'name': 'savings', 'icon': Icons.savings_rounded, 'label': 'Ahorro General'},
    {'name': 'beach_access', 'icon': Icons.beach_access_rounded, 'label': 'Vacaciones / Viaje'},
    {'name': 'directions_car', 'icon': Icons.directions_car_rounded, 'label': 'Vehículo / Auto'},
    {'name': 'home', 'icon': Icons.home_rounded, 'label': 'Hogar / Casa'},
    {'name': 'shield', 'icon': Icons.shield_rounded, 'label': 'Fondo Emergencia'},
    {'name': 'school', 'icon': Icons.school_rounded, 'label': 'Educación / Cursos'},
    {'name': 'devices', 'icon': Icons.devices_rounded, 'label': 'Tecnología'},
    {'name': 'celebration', 'icon': Icons.celebration_rounded, 'label': 'Fiesta / Evento'},
  ];

  static const List<int> _availableColors = [
    0xFF10B981, // Emerald Green
    0xFF06B6D4, // Cyan
    0xFF3B82F6, // Blue
    0xFF8B5CF6, // Purple
    0xFFEC4899, // Pink
    0xFFF59E0B, // Amber
    0xFFEF4444, // Red
  ];

  IconData _getGoalIcon(String iconName) {
    final item = _availableIcons.firstWhere(
      (e) => e['name'] == iconName,
      orElse: () => _availableIcons.first,
    );
    return item['icon'] as IconData;
  }

  void _showCreateGoalDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetAmountController = TextEditingController();
    DateTime? selectedDeadline;
    String selectedIcon = 'savings';
    int selectedColor = _availableColors.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.add_task_rounded, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Nueva Meta de Ahorro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Meta *',
                        hintText: 'Ej: Vacaciones Familiares 2026',
                        prefixIcon: Icon(Icons.flag_rounded),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre de la meta' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: targetAmountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Monto Objetivo (Bs) *',
                        hintText: 'Ej: 5000',
                        prefixIcon: Icon(Icons.attach_money_rounded),
                      ),
                      validator: (v) {
                        final val = double.tryParse(v ?? '');
                        if (val == null || val <= 0) return 'Ingresa un monto válido mayor a 0';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción / Motivo (Opcional)',
                        hintText: 'Ej: Viaje a la playa en diciembre',
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selector de Fecha Límite
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDeadline = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppColors.textSecondary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDeadline != null
                                    ? 'Fecha Límite: ${DateFormatter.formatFull(selectedDeadline!)}'
                                    : 'Seleccionar Fecha Límite (Opcional)',
                                style: TextStyle(
                                  color: selectedDeadline != null ? AppColors.textPrimary : AppColors.textMuted,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (selectedDeadline != null)
                              IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => setDialogState(() => selectedDeadline = null),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Selector de Icono
                    const Text('Icono:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableIcons.map((item) {
                        final isSelected = selectedIcon == item['name'];
                        return InkWell(
                          onTap: () => setDialogState(() => selectedIcon = item['name'] as String),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withAlpha(40) : AppColors.surfaceLight.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
                            ),
                            child: Icon(item['icon'] as IconData, size: 20, color: isSelected ? AppColors.primary : AppColors.textSecondary),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    // Selector de Color
                    const Text('Color:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: _availableColors.map((colorInt) {
                        final isSelected = selectedColor == colorInt;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = colorInt),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Color(colorInt),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.transparent,
                                width: 2.5,
                              ),
                            ),
                            child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nav = Navigator.of(ctx);
                  final currentUser = _authService.currentUser;
                  final newGoal = SavingsGoal(
                    id: '',
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    targetAmount: double.parse(targetAmountController.text.trim()),
                    deadline: selectedDeadline,
                    iconName: selectedIcon,
                    colorValue: selectedColor,
                    createdBy: currentUser?.displayName ?? currentUser?.alias ?? 'Papá',
                    createdAt: DateTime.now(),
                  );

                  await _savingsService.createGoal(newGoal);
                  nav.pop();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text('¡Meta de ahorro familiar creada exitosamente!'),
                      ),
                    );
                  }
                }
              },
              child: const Text('Crear Meta'),
            ),
          ],
        ),
      ),
    );
  }

  void _showContributeDialog(SavingsGoal goal) {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final currentUser = _authService.currentUser;
    var selectedMember = AppMembers.members.firstWhere(
      (m) => m.id == (currentUser?.id ?? 'admin_papa'),
      orElse: () => AppMembers.members.first,
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(_getGoalIcon(goal.iconName), color: Color(goal.colorValue)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Aportar a: ${goal.title}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de Miembro Aportante
                DropdownButtonFormField<FamilyMember>(
                  initialValue: selectedMember,
                  decoration: const InputDecoration(
                    labelText: 'Integrante que Aporta',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  items: AppMembers.members.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          Icon(m.icon, color: m.color, size: 18),
                          const SizedBox(width: 8),
                          Text(m.name, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedMember = val);
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Monto del Aporte (Bs) *',
                    hintText: 'Ej: 100',
                    prefixIcon: Icon(Icons.attach_money_rounded),
                  ),
                  validator: (v) {
                    final val = double.tryParse(v ?? '');
                    if (val == null || val <= 0) return 'Ingresa un monto válido';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Nota (Opcional)',
                    hintText: 'Ej: Ahorro de la semana',
                    prefixIcon: Icon(Icons.edit_note_rounded),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Color(goal.colorValue)),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final nav = Navigator.of(ctx);
                  final amount = double.parse(amountController.text.trim());
                  final contribution = GoalContribution(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    memberId: selectedMember.id,
                    memberName: selectedMember.name,
                    amount: amount,
                    date: DateTime.now(),
                    note: noteController.text.trim(),
                  );

                  await _savingsService.addContribution(
                    goalId: goal.id,
                    contribution: contribution,
                  );

                  nav.pop();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: Color(goal.colorValue),
                        content: Text('¡Aporte de ${CurrencyFormatter.format(amount)} registrado con éxito!'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.volunteer_activism_rounded, size: 16),
              label: const Text('Registrar Aporte', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalHistorySheet(SavingsGoal goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(_getGoalIcon(goal.iconName), color: Color(goal.colorValue), size: 24),
                          const SizedBox(width: 8),
                          Text(goal.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.expense),
                        onPressed: () => _confirmDeleteGoal(goal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Meta: ${CurrencyFormatter.format(goal.targetAmount)} • Recaudado: ${CurrencyFormatter.format(goal.currentAmount)} (${(goal.progressPercentage * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 12),
                  const Text('Historial de Aportes Familiares:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  if (goal.contributions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Center(
                        child: Text('Aún no hay aportes registrados. ¡Sé el primero!', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: goal.contributions.length,
                      itemBuilder: (_, index) {
                        final c = goal.contributions.reversed.toList()[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight.withAlpha(30),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(DateFormatter.formatFull(c.date), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                  if (c.note.isNotEmpty)
                                    Text('"${c.note}"', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontStyle: FontStyle.italic)),
                                ],
                              ),
                              Text(
                                '+ ${CurrencyFormatter.format(c.amount)}',
                                style: const TextStyle(color: AppColors.income, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteGoal(SavingsGoal goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Eliminar meta de ahorro?'),
        content: Text('Se eliminará la meta "${goal.title}" y su historial de aportes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.expense),
            onPressed: () async {
              Navigator.pop(ctx); // Cierra dialog
              Navigator.pop(context); // Cierra sheet
              await _savingsService.deleteGoal(goal.id);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Metas de Ahorro Familiar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateGoalDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.savings_rounded, color: Colors.white),
        label: const Text('Nueva Meta', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<SavingsGoal>>(
        stream: _savingsService.getGoalsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final goals = snapshot.data ?? [];

          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.savings_outlined, size: 64, color: AppColors.primary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Sin Metas de Ahorro Activas',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea una meta colaborativa para vacaciones, compras importantes o un fondo de emergencia familiar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _showCreateGoalDialog,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Crear Primera Meta'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Header con Resumen General
          final totalTarget = goals.fold<double>(0.0, (sum, g) => sum + g.targetAmount);
          final totalSaved = goals.fold<double>(0.0, (sum, g) => sum + g.currentAmount);
          final globalProgress = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              // Tarjeta Resumen Global
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2A1D), Color(0xFF1E3A2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ahorro Familiar Acumulado',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(40),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${goals.length} ${goals.length == 1 ? "Meta" : "Metas"}',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(totalSaved),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Objetivo total: ${CurrencyFormatter.format(totalTarget)} (${(globalProgress * 100).toStringAsFixed(0)}% alcanzado)',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: globalProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              const Text('Tus Metas Familiares', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              // Lista de Metas
              ...goals.map((goal) => _buildGoalCard(goal)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalCard(SavingsGoal goal) {
    final color = Color(goal.colorValue);
    final isCompleted = goal.isCompleted || goal.currentAmount >= goal.targetAmount;
    final progress = goal.progressPercentage;
    final days = goal.daysRemaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCompleted ? AppColors.income.withAlpha(120) : AppColors.border,
          width: isCompleted ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showGoalHistorySheet(goal),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Icono + Título + Badge de Estado
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getGoalIcon(goal.iconName), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                            ),
                            if (goal.description.isNotEmpty)
                              Text(
                                goal.description,
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ],
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.income.withAlpha(25),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle_rounded, size: 14, color: AppColors.income),
                            SizedBox(width: 4),
                            Text('¡Completada!', style: TextStyle(color: AppColors.income, fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    else if (days != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (days <= 15 ? AppColors.expense : AppColors.surfaceLight).withAlpha(40),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          days < 0 ? 'Vencida' : '$days días rest.',
                          style: TextStyle(
                            color: days <= 15 ? AppColors.expense : AppColors.textSecondary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Montos Recaudado vs Objetivo
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ahorrado:', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        Text(
                          CurrencyFormatter.format(goal.currentAmount),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Meta:', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        Text(
                          CurrencyFormatter.format(goal.targetAmount),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Barra de Progreso
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceLight.withAlpha(60),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),

                const SizedBox(height: 12),

                // Botones y Desglose de Aportes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${goal.contributions.length} ${goal.contributions.length == 1 ? "aporte" : "aportes"} • ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showContributeDialog(goal),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Aportar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
