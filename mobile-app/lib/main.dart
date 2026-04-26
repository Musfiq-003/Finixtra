import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/network_service.dart';
import 'core/services/transaction_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/auth_service.dart';
import 'ui/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Services
  final networkService = NetworkService();
  final transactionService = TransactionService(networkService);
  final syncService = SyncService();
  final authService = AuthService();
  
  await transactionService.initDB();
  await syncService.init();
  // In production: await networkService.initializeMesh();

  runApp(
    MultiProvider(
      providers: [
        Provider<NetworkService>.value(value: networkService),
        Provider<TransactionService>.value(value: transactionService),
        Provider<SyncService>.value(value: syncService),
        Provider<AuthService>.value(value: authService),
      ],
      child: const FinixtraApp(),
    ),
  );
}

class FinixtraApp extends StatelessWidget {
  const FinixtraApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FINIXTRA',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Premium deep blue/black
        primaryColor: const Color(0xFF38BDF8),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
        ),
        // fontFamily: 'Inter', // Assuming Inter font is configured
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
