import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/api_service.dart';
import 'package:relatoriooffline/services/log_service.dart';

class SyncService {
  static final SyncService instance = SyncService._init();

  SyncService._init();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _monitoringStarted = false;
  bool _isSyncing = false;
  final Set<int> _inFlightIds = <int>{};

  static const Duration _connectionStabilizationDelay = Duration(seconds: 3);
  static const Duration _requestTimeout = Duration(seconds: 60);

  bool _hasConnection(dynamic status) {
    if (status is ConnectivityResult) {
      return status != ConnectivityResult.none;
    }
    if (status is List<ConnectivityResult>) {
      return status.any((result) => result != ConnectivityResult.none);
    }
    return false;
  }

  Future<void> startMonitoring() async {
    if (_monitoringStarted) return;
    _monitoringStarted = true;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (status) async {
        if (_hasConnection(status)) {
          await Future.delayed(_connectionStabilizationDelay);
          final current = await _connectivity.checkConnectivity();
          if (_hasConnection(current)) {
            unawaited(syncPending());
          }
        }
      },
    );

    final current = await _connectivity.checkConnectivity();
    if (_hasConnection(current)) {
      syncPending();
    }
  }

  Future<Map<String, dynamic>?> _getAuth() async {
    return await AppDatabase.instance.obterToken();
  }

  Future<bool> trySendRelatorio(
    Map<String, dynamic> dadosBrutos, {
    int? localId,
    int? templateId,
  }) async {
    if (localId != null) {
      if (_inFlightIds.contains(localId)) return false;
      _inFlightIds.add(localId);
    }

    try {
      final auth = await _getAuth();
      final token = auth?['token'] as String?;
      if (token == null || token.isEmpty) {
        await LogService.instance.warning('Tentativa de envio sem token', tag: 'SyncService');
        return false;
      }

      final uri = Uri.parse('${ApiService.getBaseUrl()}/relatorios/criar');
      var request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';

      final Map<String, dynamic> dadosParaJson = Map.from(dadosBrutos);
      
      // Remove IDs de dentro dos dados para não enviar duplicado
      dadosParaJson.remove('municipalId');
      dadosParaJson.remove('regionalId');
      
      int filesCount = 0;
      dadosBrutos.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is String && first.length > 100) {
            for (int i = 0; i < value.length; i++) {
              try {
                final bytes = base64Decode(value[i] as String);
                request.files.add(http.MultipartFile.fromBytes(
                  key, // Removido o [] para ficar igual ao fixo
                  bytes,
                  filename: '${key}_$i.jpg',
                ));
                filesCount++;
              } catch (e) {
                LogService.instance
                    .error('Erro ao decodificar imagem: $e', tag: 'SyncService');
              }
            }
            dadosParaJson[key] = "[ENVIADO_COMO_ARQUIVO]";
          }
        }
      });

      // Monta o payload exatamente como o servidor espera
      final Map<String, dynamic> requestPayload = {
        "templateId": templateId,
        "dados": dadosParaJson,
      };

      if (auth?['municipal_id'] != null) {
        requestPayload["municipalId"] = auth!['municipal_id'];
        requestPayload["cidade"] = auth['municipal_nome'] ?? "Cidade";
      } else if (auth?['regional_id'] != null) {
        requestPayload["regionalId"] = auth!['regional_id'];
        requestPayload["cidade"] = auth['regional_nome'] ?? "Regional";
      }

      request.fields['request'] = jsonEncode(requestPayload);

      await LogService.instance.info('Iniciando envio de relatório dinâmico',
          tag: 'SyncService',
          extra: 'LocalID: $localId, TemplateID: $templateId');

      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await LogService.instance.info('Relatório enviado com sucesso', tag: 'SyncService', extra: 'Status: ${response.statusCode}');
        return true;
      }
      
      await LogService.instance.error(
        'Erro ao enviar relatório', 
        tag: 'SyncService', 
        extra: 'Status: ${response.statusCode}, Body: ${response.body}'
      );
      print('Erro ao enviar relatório (${response.statusCode}): ${response.body}');
      return false;
    } catch (e, stack) {
      await LogService.instance.error('Exceção ao enviar relatório', tag: 'SyncService', extra: '$e\n$stack');
      return false;
    } finally {
      if (localId != null) _inFlightIds.remove(localId);
    }
  }

  Future<void> syncPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    
    await LogService.instance.info(
      'Iniciando processo de sincronização de pendentes',
      tag: 'SyncService',
    );

    try {
      final pendentes = await AppDatabase.instance.obterFormularios(
        sincronizado: false,
        incluirDadosJson: true,
      );

      await LogService.instance.info(
        'Sincronização: ${pendentes.length} formulário(s) pendente(s) encontrado(s)',
        tag: 'SyncService',
      );

      for (final form in pendentes) {
        final id = form['id'] as int;
        final tipo = form['tipo'] as String;
        final templateId = form['template_id'] as int?;
        final dadosBrutos = jsonDecode(form['dados_json'] as String);

        bool success = false;
        if (tipo == 'familia_atingida') {
          success = await trySendFamiliaAtingida(dadosBrutos, localId: id);
        } else {
          success = await trySendRelatorio(
            dadosBrutos,
            localId: id,
            templateId: templateId,
          );
        }

        if (success) {
          await AppDatabase.instance.marcarComoSincronizado(id);
        }
      }
    } catch (e, stack) {
      await LogService.instance.error(
        'Erro inesperado no processo de sincronização',
        tag: 'SyncService',
        extra: '$e\n$stack',
      );
    } finally {
      _isSyncing = false;
      await LogService.instance.info(
        'Processo de sincronização de pendentes finalizado',
        tag: 'SyncService',
      );
    }
  }

  Future<bool> trySendFamiliaAtingida(
    Map<String, dynamic> dadosBrutos, {
    int? localId,
  }) async {
    if (localId != null) {
      if (_inFlightIds.contains(localId)) return false;
      _inFlightIds.add(localId);
    }

    try {
      final auth = await _getAuth();
      final token = auth?['token'] as String?;
      if (token == null || token.isEmpty) {
        return false;
      }

      final uri = Uri.parse(
          '${ApiService.getBaseUrl()}/relatorios/familia-atingida');
      var request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      final Map<String, dynamic> requestJson = Map.from(dadosBrutos);
      final fotos = requestJson.remove('fotosResidencia') as List?;

      if (fotos != null) {
        for (int i = 0; i < fotos.length; i++) {
          final bytes = base64Decode(fotos[i] as String);
          request.files.add(http.MultipartFile.fromBytes(
            'RESIDENCIA',
            bytes,
            filename: 'residencia_$i.jpg',
          ));
        }
      }

      request.fields['request'] = jsonEncode(requestJson);

      await LogService.instance.info(
          'Iniciando envio de relatório Família Atingida',
          tag: 'SyncService',
          extra: 'LocalID: $localId');

      final streamedResponse = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        await LogService.instance.info(
            'Relatório Família Atingida enviado com sucesso',
            tag: 'SyncService');
        return true;
      }

      await LogService.instance.error('Erro ao enviar relatório Família Atingida',
          tag: 'SyncService',
          extra: 'Status: ${response.statusCode}, Body: ${response.body}');
      return false;
    } catch (e, stack) {
      await LogService.instance.error(
          'Exceção ao enviar relatório Família Atingida',
          tag: 'SyncService',
          extra: '$e\n$stack');
      return false;
    } finally {
      if (localId != null) _inFlightIds.remove(localId);
    }
  }
}
