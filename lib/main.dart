import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/app_lock_wrapper.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar formato de fechas
  try {
    await initializeDateFormatting('es', null);
  } catch (_) {}

  // Inicializar Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirestoreService.configurePersistence();
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }

  // Inicializar notificaciones en segundo plano sin bloquear el arranque
  NotificationService().initialize().catchError((e) {
    debugPrint('Notification init note: $e');
  });

  // Verificar sesión previa de forma asíncrona
  final savedUser = await AuthService().checkSavedSession();

  runApp(FamFinanceApp(initialLoggedIn: savedUser != null));
}

class FamFinanceApp extends StatelessWidget {
  final bool initialLoggedIn;

  const FamFinanceApp({super.key, required this.initialLoggedIn});

  @override
  Widget build(BuildContext context) {
    return AppLockWrapper(
      child: MaterialApp(
        title: 'FamFinance',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: initialLoggedIn ? const HomeScreen() : const LoginScreen(),
      ),
    );
  }
}



