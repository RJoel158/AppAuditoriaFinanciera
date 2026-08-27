import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'services/firestore_service.dart';
import 'views/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inicialización de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // 2. Configurar persistencia en caché local de Firestore
    FirestoreService.configurePersistence();
  } catch (e) {
    debugPrint('Nota de inicialización de Firebase: $e');
  }

  runApp(const AuditoriaFinancieraApp());
}

class AuditoriaFinancieraApp extends StatelessWidget {
  const AuditoriaFinancieraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auditoría y Ahorro Familiar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
