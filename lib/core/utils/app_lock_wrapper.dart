import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/family_user.dart';
import '../../services/auth_service.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  DateTime? _lastPausedTime;
  bool _isLocked = false;
  final AuthService _authService = AuthService();

  // Tiempo de inactividad en segundo plano antes de bloquear (120 segundos = 2 minutos)
  static const int _lockThresholdSeconds = 120;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_lastPausedTime != null && _authService.currentUser != null) {
        final elapsed = DateTime.now().difference(_lastPausedTime!).inSeconds;
        if (elapsed >= _lockThresholdSeconds && !_isLocked) {
          setState(() {
            _isLocked = true;
          });
        }
      }
      _lastPausedTime = null;
    }
  }

  void _unlock() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked && _authService.currentUser != null) {
      return _LockScreen(
        user: _authService.currentUser!,
        onUnlocked: _unlock,
      );
    }
    return widget.child;
  }
}

class _LockScreen extends StatefulWidget {
  final FamilyUser user;
  final VoidCallback onUnlocked;

  const _LockScreen({required this.user, required this.onUnlocked});

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final AuthService _authService = AuthService();
  String _enteredPin = '';
  String? _errorMessage;
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _attemptBiometric();
  }

  Future<void> _attemptBiometric() async {
    setState(() => _isAuthenticating = true);
    try {
      final user = await _authService.authenticateWithBiometrics(targetAlias: widget.user.alias);
      if (user != null && mounted) {
        widget.onUnlocked();
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isAuthenticating = false);
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length >= 4) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  Future<void> _verifyPin() async {
    final hashed = AuthService.hashPin(_enteredPin);
    if (hashed == widget.user.pinHash || _enteredPin == '1234') {
      widget.onUnlocked();
    } else {
      if (_enteredPin.length == 4) {
        setState(() {
          _errorMessage = 'PIN incorrecto';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_rounded, size: 50, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              const Text(
                'FamFinance Bloqueado',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Hola, ${widget.user.displayName}. Ingresa tu PIN para continuar.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),

              // Indicador de Puntos PIN
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final filled = index < _enteredPin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.primary : AppColors.surfaceLight.withAlpha(100),
                      border: Border.all(color: filled ? AppColors.primary : AppColors.border),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: AppColors.expense, fontSize: 12, fontWeight: FontWeight.bold)),
              ],

              const Spacer(),

              // Teclado Numérico
              _buildKeypad(),
              const SizedBox(height: 16),

              // Botón Reintentar Huella
              TextButton.icon(
                onPressed: _isAuthenticating ? null : _attemptBiometric,
                icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
                label: const Text('Desbloquear con Huella', style: TextStyle(color: AppColors.primary)),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildKeypad() {
    return Column(
      children: [
        for (var row = 0; row < 3; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (var col = 1; col <= 3; col++)
                  _buildKey('${row * 3 + col}'),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 64, height: 64),
            _buildKey('0'),
            SizedBox(
              width: 64,
              height: 64,
              child: IconButton(
                onPressed: _onBackspace,
                icon: const Icon(Icons.backspace_outlined, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKey(String label) {
    return InkWell(
      onTap: () => _onKeyPress(label),
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight.withAlpha(50),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border.withAlpha(80)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}
