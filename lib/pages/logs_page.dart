import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/log_service.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarLogs();
  }

  Future<void> _carregarLogs() async {
    setState(() => _isLoading = true);
    final logs = await AppDatabase.instance.obterLogs(limit: 500);
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmarLimpeza() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar Logs'),
        content: const Text('Deseja realmente apagar todos os logs?'),
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
      await LogService.instance.limpar();
      _carregarLogs();
    }
  }

  Color _getNivelColor(String nivel) {
    switch (nivel) {
      case 'ERROR':
        return Colors.red.shade700;
      case 'WARN':
        return Colors.orange.shade800;
      case 'INFO':
        return Colors.blue.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs do Sistema'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => LogService.instance.exportarLogs(),
            tooltip: 'Exportar Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _confirmarLimpeza,
            tooltip: 'Limpar Logs',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Nenhum log encontrado.'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    final dataStr = log['data_hora'] as String;
                    final data = DateTime.tryParse(dataStr);
                    final formatada = data != null 
                        ? DateFormat('HH:mm:ss dd/MM').format(data) 
                        : dataStr;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        leading: Icon(
                          log['nivel'] == 'ERROR' ? Icons.error : 
                          log['nivel'] == 'WARN' ? Icons.warning : Icons.info,
                          color: _getNivelColor(log['nivel']),
                        ),
                        title: Text(
                          log['mensagem'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getNivelColor(log['nivel']),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('$formatada | ${log['tag'] ?? 'Geral'}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Detalhes:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                SelectableText(log['mensagem']),
                                if (log['extra'] != null) ...[
                                  const SizedBox(height: 12),
                                  const Text('Extra:', style: TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: SelectableText(
                                      log['extra'].toString(),
                                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
