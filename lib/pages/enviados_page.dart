import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/pages/dynamic_form_page.dart';
import 'package:relatoriooffline/pages/familia_form_page.dart';

class EnviadosPage extends StatefulWidget {
  const EnviadosPage({super.key});

  @override
  State<EnviadosPage> createState() => _EnviadosPageState();
}

class _EnviadosPageState extends State<EnviadosPage> {
  List<Map<String, dynamic>> _formularios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarFormularios();
  }

  Future<void> _carregarFormularios() async {
    setState(() => _isLoading = true);

    final formularios = await AppDatabase.instance.obterFormularios(
      sincronizado: true,
      incluirDadosJson: true,
    );

    if (mounted) {
      setState(() {
        _formularios = formularios;
        _isLoading = false;
      });
    }
  }

  Future<void> _abrirFormulario(Map<String, dynamic> form) async {
    final tipo = form['tipo'] as String;
    final dadosJson = form['dados_json'] as String;
    final templateId = form['template_id'] as int?;

    // Se o dados_json for apenas o placeholder antigo, não conseguimos mostrar os dados.
    if (dadosJson == '{"sincronizado":true}') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este relatório foi sincronizado em uma versão anterior e seus dados locais foram removidos.')),
        );
      }
      return;
    }

    final initialData = jsonDecode(dadosJson) as Map<String, dynamic>;

    Widget? page;

    if (templateId != null) {
      final templates = await AppDatabase.instance.obterTemplates();
      final templateRecord = templates.firstWhere((t) => t['id'] == templateId);
      final templateData = jsonDecode(templateRecord['dados_json']);

      page = DynamicFormPage(
        template: templateData,
        initialData: initialData,
        readOnly: true,
      );
    } else if (tipo == 'familia') {
      page = FamiliaFormPage(
        initialData: initialData,
        readOnly: true,
      );
    }

    if (page != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page!),
      );
    }
  }

  Future<void> _confirmarLimparEnviados() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Enviados'),
        content: const Text('Deseja realmente remover todos os formulários já enviados da lista local? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AppDatabase.instance.limparEnviados();
      _carregarFormularios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lista de enviados limpa com sucesso.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulários Enviados'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _formularios.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_off,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum formulário enviado',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregarFormularios,
                  color: Colors.orange.shade700,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _formularios.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _formularios.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: OutlinedButton.icon(
                            onPressed: _confirmarLimparEnviados,
                            icon: const Icon(Icons.delete_sweep, color: Colors.red),
                            label: const Text(
                              'LIMPAR RELATÓRIOS ENVIADOS',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        );
                      }

                      final form = _formularios[index];
                      final tipo = form['tipo'] as String;
                      final dataCriacao = DateTime.parse(
                        form['data_criacao'] as String,
                      );

                      String nomeExibicao = tipo;
                      if (tipo == 'familia_atingida') nomeExibicao = 'Família Atingida';
                      if (tipo == 'familia') nomeExibicao = 'Família (Legado)';
                      if (tipo == 'recibo_iah') nomeExibicao = 'Recibo de Entrega IAH';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => _abrirFormulario(form),
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.assignment_turned_in,
                              color: Colors.green.shade700,
                              size: 28,
                            ),
                          ),
                          title: Text(
                            nomeExibicao,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'Enviado em: ${dataCriacao.day.toString().padLeft(2, '0')}/${dataCriacao.month.toString().padLeft(2, '0')}/${dataCriacao.year} às ${dataCriacao.hour.toString().padLeft(2, '0')}:${dataCriacao.minute.toString().padLeft(2, '0')}',
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sincronizado',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

