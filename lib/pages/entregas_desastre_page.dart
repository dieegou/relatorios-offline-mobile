import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/core/models/entrega_iah_model.dart';

class EntregasDesastrePage extends StatefulWidget {
  const EntregasDesastrePage({super.key});

  @override
  State<EntregasDesastrePage> createState() => _EntregasDesastrePageState();
}

class _EntregasDesastrePageState extends State<EntregasDesastrePage> {
  late Desastre _desastre;
  late List<EntregaIah> _familias;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      _desastre = args['desastre'];
      _familias = List<EntregaIah>.from(args['familias']);
      _ordenarFamilias();
    }
  }

  void _ordenarFamilias() {
    _familias.sort(
      (a, b) => a.nomeResponsavel.toLowerCase().compareTo(b.nomeResponsavel.toLowerCase()),
    );
  }

  Future<void> _recarregarFamilias() async {
    final cached = await AppDatabase.instance.obterEntregasIahPorDesastre(_desastre.id);
    if (!mounted) return;
    setState(() {
      _familias = cached
          .map((c) => EntregaIah.fromJson(jsonDecode(c['dados_json'] as String)))
          .toList();
      _ordenarFamilias();
    });
  }

  Future<void> _abrirMapa(EntregaIah familia) async {
    final uris = <Uri>[];

    if (familia.latitudeColeta != null && familia.longitudeColeta != null) {
      final lat = familia.latitudeColeta!;
      final lng = familia.longitudeColeta!;
      uris.addAll([
        Uri.parse('geo:$lat,$lng?q=$lat,$lng'),
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        Uri.parse('https://maps.google.com/maps?q=$lat,$lng'),
      ]);
    } else {
      final endereco = familia.enderecoResponsavel.trim();
      if (endereco.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Endereço não disponível para abrir no mapa.')),
          );
        }
        return;
      }
      final query = Uri.encodeComponent(endereco);
      uris.addAll([
        Uri.parse('geo:0,0?q=$query'),
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
        Uri.parse('https://maps.google.com/maps?q=$query'),
      ]);
    }

    for (final uri in uris) {
      try {
        final abriu = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (abriu) return;
      } catch (_) {
        continue;
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o mapa. Verifique se há um app de mapas instalado.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendentes = _familias.where((f) => f.statusEntrega == 'LIBERADA').length;
    final entregues = _familias.length - pendentes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Famílias para Entrega'),
        backgroundColor: const Color(0xFF3A3F7A),
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(pendentes: pendentes, entregues: entregues),
          const SizedBox(height: 16),
          ..._familias.map(_buildFamilyCard),
        ],
      ),
    );
  }

  Widget _buildHeader({required int pendentes, required int entregues}) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFb0b2ca),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFF3A3F7A),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _desastre.cobrade,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3A3F7A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(_desastre.dataDesastre),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _desastre.descricao,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatChip(
                label: 'Pendentes',
                value: pendentes,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'Entregues',
                value: entregues,
                color: Colors.green,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: 'Total',
                value: _familias.length,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required int value,
    required MaterialColor color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color.shade800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyCard(EntregaIah familia) {
    final bool isLiberada = familia.statusEntrega == 'LIBERADA';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLiberada ? const Color(0xFF616595) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onTap: isLiberada 
            ? () async {
                final result = await Navigator.pushNamed(
                  context, 
                  '/recibo_iah_form',
                  arguments: familia,
                );
                if (result == true) {
                  await _recarregarFamilias();
                }
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            familia.nomeResponsavel,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusBadge(familia),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          familia.telefoneResponsavel ?? 'Sem telefone',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            familia.enderecoResponsavel,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                    if (!isLiberada && familia.usuarioEntrega != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Entregue por ${familia.usuarioEntrega!.nome} em ${DateFormat('dd/MM/yyyy HH:mm').format(familia.dataEntrega!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.map, color: Color(0xFF3A3F7A)),
                onPressed: () => _abrirMapa(familia),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(EntregaIah familia) {
    final bool isLiberada = familia.statusEntrega == 'LIBERADA';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isLiberada ? Colors.orange.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isLiberada ? 'Pendente' : 'Entregue',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isLiberada ? Colors.orange.shade900 : Colors.green.shade900,
        ),
      ),
    );
  }
}
