import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/family_user.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'widgets/pin_recovery_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  List<FamilyUser> _familyUsers = [];
  FamilyUser? _selectedUser;
  String _enteredPin = '';
  static const int _pinLength = 4;
  bool _isLoading = false;
  bool _isLoadingUsers = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsersAndInit();
  }

  Future<void> _loadUsersAndInit() async {
    // 1. Mostrar de inmediato los usuarios familiares por defecto
    final initialUsers = _authService.defaultFamilyUsers;
    if (mounted) {
      setState(() {
        _familyUsers = initialUsers;
        _selectedUser = initialUsers.firstWhere(
          (u) => u.isAdmin,
          orElse: () => initialUsers.first,
        );
        _isLoadingUsers = false;
      });
    }

    // 2. Sincronizar en segundo plano con Firestore
    try {
      await _authService.initializeDefaultUsersIfNeeded();
      final users = await _authService.getActiveUsers();

      if (mounted && users.isNotEmpty) {
        setState(() {
          _familyUsers = users;
          _selectedUser = users.firstWhere(
            (u) => u.alias == _selectedUser?.alias,
            orElse: () => users.first,
          );
        });
      }
    } catch (_) {}

    // 3. Si hay un usuario guardado previamente en el dispositivo, intentar biometría
    if (mounted) {
      _trySavedBiometrics();
    }
  }




  Future<void> _trySavedBiometrics() async {
    try {
      final savedUser = await _authService.getSavedBiometricUser();
      if (savedUser != null && _selectedUser?.alias == savedUser.alias) {
        final user = await _authService.authenticateWithBiometrics(targetAlias: savedUser.alias);
        if (user != null && mounted) {
          _navigateToHome(user);
        }
      }
    } catch (_) {}
  }

  Future<void> _onBiometricPressed() async {
    if (_selectedUser == null) return;

    setState(() {
      _errorMessage = null;
    });

    try {
      final user = await _authService.authenticateWithBiometrics(
        targetAlias: _selectedUser!.alias,
      );
      if (user != null && mounted) {
        _navigateToHome(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _enteredPin = '';
        });
      }
    }
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < _pinLength) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == _pinLength) {
        _handleLogin();
      }
    }
  }

  void _onDelete() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleLogin() async {
    if (_selectedUser == null) {
      setState(() {
        _errorMessage = 'Selecciona un usuario en la lista';
        _enteredPin = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.loginWithPin(
        alias: _selectedUser!.alias,
        pin: _enteredPin,
      );

      if (mounted) {
        _navigateToHome(user);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _enteredPin = '';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToHome(FamilyUser user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  void _showRecoveryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => PinRecoveryDialog(
        initialUser: _selectedUser,
      ),
    );
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // 1. Encabezado y Logo Oficial FamFinance
              Container(
                width: 76,
                height: 76,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha(80),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/app_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: AppColors.primary,
                      size: 38,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'FamFinance',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Auditoría y Gestión Financiera Familiar',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 20),

              // 2. Selector de Usuario en COMBOBOX Elegante (Sin chips)
              if (_isLoadingUsers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedUser?.alias,
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
                      items: _familyUsers.map((user) {
                        final color = _getAvatarColor(user);
                        final icon = _getAvatarIcon(user.avatarIcon);
                        return DropdownMenuItem<String>(
                          value: user.alias,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: color.withAlpha(30),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(icon, color: color, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '@${user.alias}',
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (user.isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withAlpha(30),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'ADMIN',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (alias) {
                        if (alias != null) {
                          setState(() {
                            _selectedUser = _familyUsers.firstWhere((u) => u.alias == alias);
                            _enteredPin = '';
                            _errorMessage = null;
                          });
                        }
                      },
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // 3. Indicador de Puntos del PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pinLength, (index) {
                  final isFilled = index < _enteredPin.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled ? AppColors.primary : AppColors.surfaceLight,
                      border: Border.all(
                        color: isFilled ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withAlpha(100),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),

              // 4. Mensaje de Error
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.expense, fontSize: 12, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (_isLoading)
                const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                const SizedBox(height: 18),

              // 5. Teclado Numérico Interactivo
              _buildNumericKeypad(),

              const SizedBox(height: 14),

              // 6. Botones de Olvidé mi PIN y Huella
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _showRecoveryDialog,
                      icon: const Icon(Icons.help_outline_rounded, size: 15, color: AppColors.textSecondary),
                      label: const Text(
                        '¿Olvidaste tu PIN?',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Flexible(
                    child: TextButton.icon(
                      onPressed: _onBiometricPressed,
                      icon: const Icon(Icons.fingerprint_rounded, size: 16, color: AppColors.primary),
                      label: const Text(
                        'Usar Huella',
                        style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumericKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        const SizedBox(height: 10),
        _buildKeypadRow(['4', '5', '6']),
        const SizedBox(height: 10),
        _buildKeypadRow(['7', '8', '9']),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Botón Huella dactilar
            _buildActionKey(
              icon: Icons.fingerprint_rounded,
              color: AppColors.primary,
              onTap: _onBiometricPressed,
            ),
            _buildDigitKey('0'),
            // Botón Borrar
            _buildActionKey(
              icon: Icons.backspace_outlined,
              color: AppColors.textSecondary,
              onTap: _onDelete,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildDigitKey(d)).toList(),
    );
  }

  Widget _buildDigitKey(String digit) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : () => _onKeyPress(digit),
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Center(
            child: Text(
              digit,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceLight.withAlpha(50),
          ),
          child: Center(
            child: Icon(icon, color: color, size: 26),
          ),
        ),
      ),
    );
  }
}
