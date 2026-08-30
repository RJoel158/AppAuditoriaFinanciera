import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/family_user.dart';
import '../../../services/auth_service.dart';

class PinRecoveryDialog extends StatefulWidget {
  final FamilyUser? initialUser;

  const PinRecoveryDialog({
    super.key,
    this.initialUser,
  });

  @override
  State<PinRecoveryDialog> createState() => _PinRecoveryDialogState();
}

class _PinRecoveryDialogState extends State<PinRecoveryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final AuthService _authService = AuthService();

  List<FamilyUser> _users = [];
  FamilyUser? _selectedUser;
  bool _isLoadingUsers = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _authService.getActiveUsers();
    if (mounted) {
      setState(() {
        _users = users;
        if (widget.initialUser != null) {
          _selectedUser = users.firstWhere(
            (u) => u.alias == widget.initialUser!.alias,
            orElse: () => users.isNotEmpty ? users.first : widget.initialUser!,
          );
        } else if (users.isNotEmpty) {
          _selectedUser = users.first;
        }
        _isLoadingUsers = false;
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (_selectedUser == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService.requestPinResetForUser(
        user: _selectedUser!,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.primary,
            content: Text(
              'Solicitud de reseteo para "${_selectedUser!.displayName}" enviada al Administrador.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.expense,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.lock_reset_rounded, color: AppColors.accent, size: 24),
          SizedBox(width: 8),
          Text(
            'Recuperar PIN',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Selecciona tu usuario familiar para que el Administrador te asigne un nuevo PIN:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),

              // Selector de Usuario (Combobox)
              if (_isLoadingUsers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight.withAlpha(50),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUser?.alias,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary),
                      items: _users.map((user) {
                        final color = _getAvatarColor(user);
                        final icon = _getAvatarIcon(user.avatarIcon);
                        return DropdownMenuItem<String>(
                          value: user.alias,
                          child: Row(
                            children: [
                              Icon(icon, color: color, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  user.displayName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (alias) {
                        if (alias != null) {
                          setState(() {
                            _selectedUser = _users.firstWhere((u) => u.alias == alias);
                          });
                        }
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 2,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Mensaje u observación (Opcional)',
                  hintText: 'ej. Olvidé mi PIN ayer...',
                  counterStyle: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _isLoading || _selectedUser == null ? null : _submitRequest,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar Solicitud'),
        ),
      ],
    );
  }
}
