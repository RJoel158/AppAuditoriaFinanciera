import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_members.dart';
import '../../../services/auth_service.dart';
import '../../admin/admin_panel_screen.dart';
import '../../ai_advisor/financial_advisor_chat_screen.dart';
import '../../reports/reports_screen.dart';
import '../../savings/savings_goals_screen.dart';

class HomeDrawer extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onSync;
  final VoidCallback onLogout;

  const HomeDrawer({
    super.key,
    required this.authService,
    required this.onSync,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = authService.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;


    Color userColor = AppColors.primary;
    IconData userIcon = Icons.person_rounded;

    if (currentUser != null) {
      final nameLower = currentUser.displayName.toLowerCase();
      for (final m in AppMembers.members) {
        if (m.name.toLowerCase() == nameLower || nameLower.contains(m.name.toLowerCase())) {
          userColor = m.color;
          userIcon = m.icon;
          break;
        }
      }
    }

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Cabecera de Perfil de Usuario Elegante
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    userColor.withAlpha(45),
                    AppColors.surfaceLight.withAlpha(80),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: const Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: userColor.withAlpha(35),
                    child: Icon(userIcon, color: userColor, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.displayName ?? 'Usuario Familiar',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: isAdmin ? AppColors.primary.withAlpha(50) : userColor.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isAdmin ? AppColors.primary : userColor,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                isAdmin ? 'ADMINISTRADOR' : 'MIEMBRO FAMILIAR',
                                style: TextStyle(
                                  color: isAdmin ? AppColors.primary : userColor,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Lista de Opciones y Accesos Rápidos
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // Asesor IA
                  _buildDrawerItem(
                    icon: Icons.auto_awesome_rounded,
                    iconColor: AppColors.primary,
                    title: 'Asesor Familiar IA',
                    subtitle: 'Consultas y recomendaciones con IA',
                    badge: 'Gemini AI',
                    badgeColor: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FinancialAdvisorChatScreen()),
                      );
                    },
                  ),

                  // Metas de Ahorro
                  _buildDrawerItem(
                    icon: Icons.savings_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: 'Metas de Ahorro',
                    subtitle: 'Objetivos financieros en familia',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SavingsGoalsScreen()),
                      );
                    },
                  ),

                  // Reportes
                  _buildDrawerItem(
                    icon: Icons.bar_chart_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: 'Reportes y Estadísticas',
                    subtitle: 'Gráficos y desglose mensual',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.border, height: 1),
                  ),

                  // Sincronizar
                  _buildDrawerItem(
                    icon: Icons.sync_rounded,
                    iconColor: AppColors.textSecondary,
                    title: 'Sincronizar Datos',
                    subtitle: 'Actualizar balance en tiempo real',
                    onTap: () {
                      Navigator.pop(context);
                      onSync();
                    },
                  ),

                  // Panel de Admin (Solo si es Administrador)
                  if (isAdmin)
                    _buildDrawerItem(
                      icon: Icons.admin_panel_settings_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: 'Panel de Administración',
                      subtitle: 'Usuarios, PINs y auditoría general',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                        );
                      },
                    ),
                ],
              ),
            ),

            // 3. Botón de Cerrar Sesión y Pie de Página
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.expense,
                  side: BorderSide(color: AppColors.expense.withAlpha(120)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Cerrar Sesión / Cambiar PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  Navigator.pop(context);
                  onLogout();
                },
              ),
            ),

            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Center(
                child: Text(
                  'FamFinance • Auditoría Inteligente v2.0',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withAlpha(25),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.primary).withAlpha(40),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: badgeColor ?? AppColors.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
        onTap: onTap,
      ),
    );
  }
}
