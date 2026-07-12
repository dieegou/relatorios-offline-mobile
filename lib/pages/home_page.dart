import 'dart:async';
import 'package:flutter/material.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/log_service.dart';
import 'package:relatoriooffline/services/sync_service.dart';

import '../services/api_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _username = '';
  String _municipalNome = '';
  String _regionalNome = '';
  int _pendentesCount = 0;
  int _enviadosCount = 0;
  bool _isRefreshing = false;
  bool _habilitaDinamicos = false;
  Timer? _refreshTimer;
  int _tapCount = 0;
  Timer? _tapTimer;

  String _resolveDisplayName(Map<String, dynamic>? auth) {
    final nome = (auth?['nome'] as String?)?.trim();
    if (nome != null && nome.isNotEmpty) return nome;

    final username = (auth?['username'] as String?)?.trim();
    if (username != null && username.isNotEmpty) return username;

    return 'Usuário';
  }

  @override
  void initState() {
    super.initState();
    LogService.instance.info('Página Inicial carregada', tag: 'UI');
    _carregarDados(forceApi: true);
    unawaited(SyncService.instance.syncPending());
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted && !_isRefreshing) {
        _carregarDados();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tapTimer?.cancel();
    super.dispose();
  }

  Future<void> _atualizarConfigApi() async {
    final auth = await AppDatabase.instance.obterToken();
    final token = auth?['token'];
    if (token == null) return;

    final config = await ApiService().getRegionalConfig(token);
    if (config == null || !mounted) return;

    final habilitaDinamicos = config['habilitaRelatoriosDinamicos'] == true;
    await AppDatabase.instance.atualizarConfigRegional(
      regionalId: config['regionalId'],
      regionalNome: config['regionalNome'],
      habilitaDinamicos: habilitaDinamicos,
    );

    if (!mounted) return;
    setState(() {
      _habilitaDinamicos = habilitaDinamicos;
      final regionalNome = (config['regionalNome'] as String?)?.trim();
      if (regionalNome != null && regionalNome.isNotEmpty) {
        _regionalNome = regionalNome;
      }
    });
  }

  Future<void> _carregarDados({bool forceApi = false}) async {
    final auth = await AppDatabase.instance.obterToken();

    if (mounted) {
      setState(() {
        _username = _resolveDisplayName(auth);
        _municipalNome = (auth?['municipal_nome'] as String?)?.trim() ?? '';
        _regionalNome = (auth?['regional_nome'] as String?)?.trim() ?? '';
        _habilitaDinamicos = auth?['habilitaRelatoriosDinamicos'] ?? false;
      });
    }

    final results = await Future.wait([
      AppDatabase.instance.obterFormularios(sincronizado: false),
      AppDatabase.instance.obterFormularios(sincronizado: true),
    ]);

    if (mounted) {
      setState(() {
        _pendentesCount = results[0].length;
        _enviadosCount = results[1].length;
      });
    }

    if (forceApi) {
      unawaited(_atualizarConfigApi());
    }
  }

  Future<void> _realizarLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Logout'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.limparToken();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) {
      _showSnack('Sincronização em andamento, aguarde.');
      return;
    }
    setState(() => _isRefreshing = true);
    try {
      final pendentesAntes = _pendentesCount;
      await SyncService.instance.syncPending();
      await _carregarDados();
      await _atualizarConfigApi();
      if (!mounted) return;
      final pendentesDepois = _pendentesCount;

      if (pendentesAntes == 0) {
        _showSnack('Nenhum formulário pendente para sincronizar.');
      } else if (pendentesDepois < pendentesAntes) {
        final sincronizados = pendentesAntes - pendentesDepois;
        _showSnack('$sincronizados formulário(s) pendente(s) sincronizado(s).');
      } else {
        _showSnack('Ainda restam $pendentesDepois formulário(s) pendente(s).', sucesso: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Não foi possível sincronizar agora. Tente novamente.', sucesso: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      } else {
        _isRefreshing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Defesa Civil - Formulários'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _realizarLogout,
            tooltip: 'Sair',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: Colors.orange.shade700,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            GestureDetector(
              onTap: () {
                _tapCount++;
                _tapTimer?.cancel();
                _tapTimer = Timer(const Duration(milliseconds: 500), () {
                  _tapCount = 0;
                });
                if (_tapCount >= 3) {
                  _tapCount = 0;
                  _tapTimer?.cancel();
                  Navigator.pushNamed(context, '/logs').then((_) => _carregarDados(forceApi: true));
                }
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF272F68),
                      Color(0xFF3A3F7A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF3A3F7A),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bem-vindo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_municipalNome.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.location_city, size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _municipalNome,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (_regionalNome.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.map_outlined, size: 14, color: Colors.white70),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _regionalNome,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Menu Principal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              context: context,
              icon: Icons.pending_actions,
              title: 'Pendentes',
              subtitle: '$_pendentesCount formulário(s) não sincronizado(s)',
              badge: _pendentesCount > 0 ? _pendentesCount.toString() : null,
              onTap: () {
                Navigator.pushNamed(context, '/pendentes')
                    .then((_) => _carregarDados(forceApi: true));
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              context: context,
              icon: Icons.check_circle,
              title: 'Enviados',
              subtitle: '$_enviadosCount formulário(s) sincronizado(s)',
              onTap: () {
                Navigator.pushNamed(context, '/enviados')
                    .then((_) => _carregarDados(forceApi: true));
              },
            ),
            const SizedBox(height: 16),
            _buildMenuButton(
              context: context,
              icon: Icons.description,
              title: 'Formulários',
              subtitle: 'Criar novo formulário',
              color: const Color(0xFF3A3F7A),
              onTap: () {
                Navigator.pushNamed(context, '/menu_formularios')
                    .then((_) => _carregarDados(forceApi: true));
              },
            ),
            if (_habilitaDinamicos) ...[
              const SizedBox(height: 16),
              _buildMenuButton(
                context: context,
                icon: Icons.assignment_turned_in,
                title: 'Relatórios Dinâmicos',
                subtitle: 'Acesse formulários customizados',
                color: Colors.orange.shade800,
                onTap: () {
                  Navigator.pushNamed(context, '/relatorios_dinamicos')
                      .then((_) => _carregarDados(forceApi: true));
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? color,
    String? badge,
  }) {
    final buttonColor = color ?? Colors.grey.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color?.withValues(alpha: 0.3) ?? Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (color ?? Colors.grey).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: buttonColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 32,
                    color: buttonColor,
                  ),
                ),
                if (badge != null)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: buttonColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: buttonColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String mensagem, {bool sucesso = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: sucesso ? Colors.green.shade600 : Colors.red.shade700,
        content: Row(
          children: [
            Icon(
              sucesso ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensagem)),
          ],
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
