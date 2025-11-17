import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/reasignar_tecnicos_screen.dart';
import 'screens/admin/historial_reasignaciones_screen.dart';
import 'screens/supervisor/supervisor_home_screen.dart';
import 'screens/tecnico/tecnico_home_screen.dart';
import 'utils/app_theme.dart';

// Handler para notificaciones en background
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('📱 Notificación en background: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Configurar handler de background para notificaciones
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Inicializar servicio de notificaciones
  final notificationService = NotificationService();
  await notificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'AST Móvil V2.0',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin-home': (context) => const AdminHomeScreen(),
          '/reasignar-tecnicos': (context) => const ReasignarTecnicosScreen(),
          '/historial_reasignaciones': (context) => const HistorialReasignacionesScreen(),
          '/supervisor-home': (context) => const SupervisorHomeScreen(),
          '/tecnico-home': (context) => const TecnicoHomeScreen(),
        },
      ),
    );
  }
}
