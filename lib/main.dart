import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'views/auth/login_screen.dart';
import 'views/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 0. Inicializar soporte de idioma español para fechas (intl)
  await initializeDateFormatting('es', null);

  // 1. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 2. Configurar persistencia en caché local de Firestore
    FirestoreService.configurePersistence();

    // 3. Inicializar usuarios por defecto en Firestore si está vacío
    await AuthService().initializeDefaultUsersIfNeeded();
  } catch (e) {
    debugPrint('Nota de inicialización de Firebase: $e');
  }

  // 4. Verificar si existe sesión activa
  final savedUser = await AuthService().checkSavedSession();

  runApp(AuditoriaFinancieraApp(initialLoggedIn: savedUser != null));
}

class AuditoriaFinancieraApp extends StatelessWidget {
  final bool initialLoggedIn;

  const AuditoriaFinancieraApp({super.key, required this.initialLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditoría y Ahorro Familiar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initialLoggedIn ? const HomeScreen() : const LoginScreen(),
    );
  }
}
