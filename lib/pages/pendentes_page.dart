import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/log_service.dart';
import 'package:relatoriooffline/services/sync_service.dart';
import 'package:relatoriooffline/pages/dynamic_form_page.dart';
import 'package:relatoriooffline/pages/familia_form_page.dart';
import 'package:relatoriooffline/pages/cadastro_familia_page.dart';

class PendentesPage extends StatefulWidget {
  const PendentesPage({super.key});

  @override
  State<PendentesPage> createState() => _PendentesPageState();
}

class _PendentesPageState extends State<PendentesPage> {
  List<Map<String, dynamic>> _formularios = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarFormularios();
  }

  Future<void> _carregarFormularios() async {
    setState(() => _isLoading = true);

    await LogService.instance.info('Acessando formulários pendentes', tag: 'UI');
    await SyncService.instance.syncPending();

    final formularios = await AppDatabase.instance.obterFormularios(
      sincronizado: false,
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
    final idLocal = form['id'] as int;
    final dadosJson = form['dados_json'] as String;
    final templateId = form['template_id'] as int?;

    final initialData = jsonDecode(dadosJson) as Map<String, dynamic>;

    Widget? page;

    if (templateId != null) {
      final templates = await AppDatabase.instance.obterTemplates();
      final templateRecord = templates.cast<Map<String, dynamic>?>().firstWhere(
            (t) => t?['id'] == templateId,
            orElse: () => null,
          );

      if (templateRecord != null) {
        final templateData = jsonDecode(templateRecord['dados_json']);

        page = DynamicFormPage(
          template: templateData,
          initialData: initialData,
          localId: idLocal,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Erro: Template do formulário não encontrado.')),
          );
        }
      }
    } else if (tipo == 'familia') {
      page = FamiliaFormPage(
        initialData: initialData,
        localId: idLocal,
      );
    } else if (tipo == 'familia_atingida') {
      page = CadastroFamiliaPage(
        initialData: initialData,
        localId: idLocal,
      );
    }

    if (page != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => page!),
      );
      _carregarFormularios();
    }
  }

  Future<void> _deletarFormulario(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Formulário'),
        content: const Text('Deseja realmente excluir este formulário pendente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await AppDatabase.instance.deletarFormulario(id);
      _carregarFormularios();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Formulário excluído.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulários Pendentes'),
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
                        Icons.check_circle_outline,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum formulário pendente',
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
                    itemCount: _formularios.length,
                    itemBuilder: (context, index) {
                      final form = _formularios[index];
                      final id = form['id'] as int;
                      final tipo = form['tipo'] as String;
                      final dataCriacao = DateTime.parse(
                        form['data_criacao'] as String,
                      );

                      String nomeExibicao = tipo;
                      if (tipo == 'familia_atingida') nomeExibicao = 'Família Atingida';
                      if (tipo == 'familia') nomeExibicao = 'Família (Legado)';

                      return Dismissible(
                        key: Key('pendente_$id'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (direction) async {
                          await _deletarFormulario(id);
                          return false; // Sempre retorna false porque o _deletarFormulario já atualiza a lista
                        },
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white, size: 32),
                        ),
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.orange.shade200,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            onTap: () => _abrirFormulario(form),
                            contentPadding: const EdgeInsets.all(16),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.assignment,
                                color: Colors.orange.shade700,
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
                                  'Criado em: ${dataCriacao.day.toString().padLeft(2, '0')}/${dataCriacao.month.toString().padLeft(2, '0')}/${dataCriacao.year} às ${dataCriacao.hour.toString().padLeft(2, '0')}:${dataCriacao.minute.toString().padLeft(2, '0')}',
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.sync_disabled,
                                        size: 14,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Não sincronizado',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade700,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

