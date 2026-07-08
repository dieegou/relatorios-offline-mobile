import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:share_plus/share_plus.dart';

class LogService {
  static final LogService instance = LogService._init();
  LogService._init();

  Future<void> info(String mensagem, {String? tag, String? extra}) async {
    await _salvar('INFO', mensagem, tag, extra);
  }

  Future<void> warning(String mensagem, {String? tag, String? extra}) async {
    await _salvar('WARN', mensagem, tag, extra);
  }

  Future<void> error(String mensagem, {String? tag, String? extra}) async {
    await _salvar('ERROR', mensagem, tag, extra);
  }

  Future<void> _salvar(String nivel, String mensagem, String? tag, String? extra) async {
    try {
      await AppDatabase.instance.salvarLog(
        nivel: nivel,
        mensagem: mensagem,
        tag: tag,
        extra: extra,
      );
    } catch (e) {
      print('Erro ao salvar log no banco de dados: $e');
    }
  }

  Future<void> exportarLogs() async {
    try {
      final logs = await AppDatabase.instance.obterLogs(limit: 1000);
      if (logs.isEmpty) return;

      final StringBuffer buffer = StringBuffer();
      buffer.writeln('=== LOGS DO APLICATIVO - RELATORIO OFFLINE ===');
      buffer.writeln('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('--------------------------------------------------\n');

      for (final log in logs) {
        final dataStr = log['data_hora'] as String;
        final data = DateTime.tryParse(dataStr);
        final formatada = data != null 
            ? DateFormat('dd/MM/yyyy HH:mm:ss').format(data) 
            : dataStr;
        
        buffer.writeln('[$formatada] [${log['nivel']}] ${log['tag'] ?? ''}');
        buffer.writeln('Mensagem: ${log['mensagem']}');
        if (log['extra'] != null && log['extra'].toString().isNotEmpty) {
          buffer.writeln('Extra: ${log['extra']}');
        }
        buffer.writeln('---');
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/logs_defesa_civil.txt');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], text: 'Logs do sistema - Defesa Civil');
    } catch (e) {
      // ignore
    }
  }

  Future<void> limpar() async {
    await AppDatabase.instance.limparLogs();
  }
}
