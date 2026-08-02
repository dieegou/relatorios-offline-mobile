import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/core/models/entrega_iah_model.dart';
import 'package:relatoriooffline/services/entregas_iah_service.dart';
import 'dart:convert';

class MenuFormularioPage extends StatefulWidget {
  const MenuFormularioPage({super.key});

  @override
  State<MenuFormularioPage> createState() => _MenuFormularioPageState();
}

class _MenuFormularioPageState extends State<MenuFormularioPage> {
  bool _isLoading = false;
  List<EntregaIah> _entregas = [];
  Map<int, List<EntregaIah>> _entregasPorDesastre = {};

  @override
  void initState() {
    super.initState();
    _verificarPermissoesLocalizacao();
    _carregarDadosIniciais();
  }

  Future<void> _verificarPermissoesLocalizacao() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _mostrarAvisoLocalizacao(
          'Serviço de Localização Desativado',
          'O GPS está desativado. Para preencher os formulários, você precisará ativá-lo.',
        );
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          _mostrarAvisoLocalizacao(
            'Permissão Negada',
            'A permissão de localização é obrigatória para registrar as entregas e cadastros.',
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _mostrarAvisoLocalizacao(
          'Permissão Bloqueada',
          'As permissões de localização estão permanentemente negadas. Por favor, habilite-as nas configurações do sistema.',
        );
      }
      return;
    }
  }

  void _mostrarAvisoLocalizacao(String titulo, String mensagem) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.red),
            const SizedBox(width: 10),
            Text(titulo),
          ],
        ),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openAppSettings();
            },
            child: const Text('CONFIGURAÇÕES'),
          ),
        ],
      ),
    );
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    await _carregarCache();
    await _sincronizar();
    setState(() => _isLoading = false);
  }

  Future<void> _carregarCache() async {
    final cached = await AppDatabase.instance.obterEntregasIah();
    final list = cached.map((c) => EntregaIah.fromJson(jsonDecode(c['dados_json']))).toList();
    _processarEntregas(list);
  }

  Future<void> _sincronizar() async {
    final auth = await AppDatabase.instance.obterToken();
    final token = auth?['token'];
    if (token != null) {
      final result = await EntregasIahService.instance.sincronizarEntregas(token);
      if (result != null) {
        _processarEntregas(result);
      }
    }
  }

  void _processarEntregas(List<EntregaIah> list) {
    final Map<int, List<EntregaIah>> grouped = {};
    for (var e in list) {
      grouped.putIfAbsent(e.desastre.id, () => []).add(e);
    }

    for (final familias in grouped.values) {
      familias.sort(
        (a, b) => a.nomeResponsavel.toLowerCase().compareTo(b.nomeResponsavel.toLowerCase()),
      );
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) {
        final desastreA = a.value.first.desastre;
        final desastreB = b.value.first.desastre;
        final byDate = desastreB.dataDesastre.compareTo(desastreA.dataDesastre);
        if (byDate != 0) return byDate;
        return desastreA.id.compareTo(desastreB.id);
      });

    setState(() {
      _entregas = list;
      _entregasPorDesastre = Map.fromEntries(sortedEntries);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibos'),
        backgroundColor: const Color(0xFF3A3F7A),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _carregarDadosIniciais,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _sincronizar,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Formulários'),
            _buildFormButton(
              context: context,
              icon: Icons.house,
              title: 'Cadastro Família Atingida',
              subtitle: 'Registrar família e necessidades',
              onTap: () {
                Navigator.pushNamed(context, '/cadastro_familia');
              },
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('Entregas IAH'),
            if (_entregasPorDesastre.isEmpty && !_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32.0),
                child: Center(
                  child: Text(
                    'Nenhuma entrega disponível',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ..._entregasPorDesastre.entries.map((entry) {
              final desastre = entry.value.first.desastre;
              final total = entry.value.length;
              final pendentes = entry.value.where((e) => e.statusEntrega == 'LIBERADA').length;
              
              return _buildDisasterCard(
                desastre: desastre,
                total: total,
                pendentes: pendentes,
                familias: entry.value,
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3A3F7A),
        ),
      ),
    );
  }

  Widget _buildDisasterCard({
    required Desastre desastre,
    required int total,
    required int pendentes,
    required List<EntregaIah> familias,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: () async {
          await Navigator.pushNamed(
            context,
            '/entregas_desastre',
            arguments: {'desastre': desastre, 'familias': familias},
          );
          if (mounted) await _carregarCache();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF616595)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20616595),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      desastre.cobrade,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A3F7A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: pendentes > 0 ? Colors.orange.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$pendentes/$total pendentes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: pendentes > 0 ? Colors.orange.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(desastre.dataDesastre),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                desastre.descricao,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Text(
                    'Ver famílias',
                    style: TextStyle(
                      color: Color(0xFF3A3F7A),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFF3A3F7A),
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF616595)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x20616595),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFb0b2ca),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: const Color(0xFF3A3F7A),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF3A3F7A),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
