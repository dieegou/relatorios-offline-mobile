import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/api_service.dart';
import 'package:relatoriooffline/services/log_service.dart';
import 'package:relatoriooffline/services/recibo_iah_multipart.dart';
import 'package:relatoriooffline/core/models/entrega_iah_model.dart';

class EntregasIahService {
  static final EntregasIahService instance = EntregasIahService._init();
  EntregasIahService._init();

  IOClient _createClient() {
    final httpClient = HttpClient();
    if (ApiService.allowSelfSignedCert) {
      final expectedHost = Uri.parse(ApiService.getBaseUrl()).host;
      httpClient.badCertificateCallback = (cert, host, port) => host == expectedHost;
    }
    return IOClient(httpClient);
  }

  Future<List<EntregaIah>?> sincronizarEntregas(String token) async {
    try {
      await LogService.instance.info('Sincronizando entregas IAH', tag: 'EntregasIahService');
      final apiUrl = ApiService.getBaseUrl();
      final client = _createClient();
      
      final response = await client.get(
        Uri.parse('$apiUrl/entregas-iah/sincronizar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));
      client.close();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        await AppDatabase.instance.salvarEntregasIah(data);
        final merged = await AppDatabase.instance.obterEntregasIah();
        return merged
            .map((row) => EntregaIah.fromJson(
                jsonDecode(row['dados_json'] as String) as Map<String, dynamic>))
            .toList();
      }
      
      await LogService.instance.warning(
        'Falha ao sincronizar entregas IAH',
        tag: 'EntregasIahService',
        extra: 'Status: ${response.statusCode}, Body: ${response.body}',
      );
      return null;
    } catch (e, stack) {
      await LogService.instance.error(
        'Erro ao sincronizar entregas IAH',
        tag: 'EntregasIahService',
        extra: '$e\n$stack',
      );
      return null;
    }
  }

  Future<bool> enviarReciboIah({
    required String token,
    required Map<String, dynamic> requestData,
    required List<File> fotosEntrega,
    required File assinaturaResponsavel,
    required File assinaturaAgente,
  }) async {
    try {
      await LogService.instance.info('Enviando recibo IAH', tag: 'EntregasIahService');
      final apiUrl = ApiService.getBaseUrl();
      
      final uri = Uri.parse('$apiUrl/relatorios/recibo-iah');
      final request = await ReciboIahMultipart.buildFromFiles(
        uri: uri,
        token: token,
        requestData: requestData,
        fotosEntrega: fotosEntrega,
        assinaturaResponsavel: assinaturaResponsavel,
        assinaturaAgente: assinaturaAgente,
      );

      // Use IOClient if needed for self-signed certificates
      final httpClient = HttpClient();
      if (ApiService.allowSelfSignedCert) {
        final expectedHost = uri.host;
        httpClient.badCertificateCallback = (cert, host, port) => host == expectedHost;
      }
      final ioClient = IOClient(httpClient);
      
      final streamedResponse = await ioClient.send(request).timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamedResponse);
      ioClient.close();

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await LogService.instance.info('Recibo IAH enviado com sucesso', tag: 'EntregasIahService');
        return true;
      }

      await LogService.instance.error(
        'Erro ao enviar recibo IAH',
        tag: 'EntregasIahService',
        extra: 'Status: ${response.statusCode}, Body: ${response.body}',
      );
      
      if (response.body.contains('Já existe recibo') || response.body.contains('recebimento encerrado')) {
        throw Exception(response.body);
      }
      
      return false;
    } catch (e, stack) {
      await LogService.instance.error(
        'Exceção ao enviar recibo IAH',
        tag: 'EntregasIahService',
        extra: '$e\n$stack',
      );
      rethrow;
    }
  }
}
