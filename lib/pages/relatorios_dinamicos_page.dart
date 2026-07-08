import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/api_service.dart';
import 'package:relatoriooffline/services/log_service.dart';
import 'package:relatoriooffline/pages/dynamic_form_page.dart';

class RelatoriosDinamicosPage extends StatefulWidget {
  const RelatoriosDinamicosPage({super.key});

  @override
  State<RelatoriosDinamicosPage> createState() => _RelatoriosDinamicosPageState();
}

class _RelatoriosDinamicosPageState extends State<RelatoriosDinamicosPage> {
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates().then((_) => _syncTemplates());
  }

  Future<void> _loadTemplates() async {
    final templates = await AppDatabase.instance.obterTemplates();
    setState(() {
      _templates = templates;
    });
  }

  Future<void> _syncTemplates() async {
    setState(() => _isLoading = true);
    await LogService.instance.info('Iniciando sincronização de templates', tag: 'UI');
    try {
      final auth = await AppDatabase.instance.obterToken();
      final token = auth?['token'];
      if (token == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Usuário não autenticado')),
          );
        }
        return;
      }

      final api = ApiService();
      final templates = await api.getTemplates(token);

      if (templates != null) {
        await AppDatabase.instance.salvarTemplates(templates);
        await _loadTemplates();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Templates sincronizados com sucesso!')),
          );
        }
      }
    } catch (e, stack) {
      await LogService.instance.error('Exceção na sincronização de templates', tag: 'UI', extra: '$e\n$stack');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatórios Dinâmicos'),
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isLoading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.sync),
            onPressed: _isLoading ? null : _syncTemplates,
          ),
        ],
      ),
      body: _templates.isEmpty && !_isLoading
          ? const Center(child: Text('Nenhum formulário dinâmico disponível.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _templates.length,
              itemBuilder: (context, index) {
                final templateRecord = _templates[index];
                final templateData = jsonDecode(templateRecord['dados_json']);

                return _buildFormButton(
                  context: context,
                  icon: Icons.assignment,
                  title: templateRecord['nome'],
                  subtitle: templateRecord['descricao'] ?? 'Toque para preencher',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DynamicFormPage(template: templateData),
                      ),
                    );
                  },
                );
              },
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
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: Colors.orange.shade800),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.orange.shade800, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
