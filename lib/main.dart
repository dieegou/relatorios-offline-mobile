import 'package:flutter/material.dart';
import 'package:relatoriooffline/pages/login_page.dart';
import 'package:relatoriooffline/pages/home_page.dart';
import 'package:relatoriooffline/pages/menu_formulario_page.dart';
import 'package:relatoriooffline/pages/pendentes_page.dart';
import 'package:relatoriooffline/pages/enviados_page.dart';
import 'package:relatoriooffline/pages/logs_page.dart';
import 'package:relatoriooffline/pages/cadastro_familia_page.dart';
import 'package:relatoriooffline/pages/relatorios_dinamicos_page.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SyncService.instance.startMonitoring();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Defesa Civil Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A3F7A),
          primary: const Color(0xFF3A3F7A),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF3A3F7A),
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const HomePage(),
        '/menu_formularios': (context) => const MenuFormularioPage(),
        '/pendentes': (context) => const PendentesPage(),
        '/enviados': (context) => const EnviadosPage(),
        '/logs': (context) => const LogsPage(),
        '/cadastro_familia': (context) => const CadastroFamiliaPage(),
        '/relatorios_dinamicos': (context) => const RelatoriosDinamicosPage(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarAutenticacao();
  }

  Future<void> _verificarAutenticacao() async {
    await Future.delayed(const Duration(milliseconds: 500));

    final auth = await AppDatabase.instance.obterToken();
    final token = (auth?['token'] as String?)?.trim();

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade700,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Image.asset(
                'lib/assets/logodc.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Defesa Civil',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Relatórios Offline',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
