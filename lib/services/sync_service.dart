import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/api_service.dart';
import 'package:relatoriooffline/services/log_service.dart';
import 'package:relatoriooffline/services/recibo_iah_multipart.dart';

class SyncService {
  static final SyncService instance = SyncService._init();

  SyncService._init();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _connectivitySubscription;
  bool _monitoringStarted = false;
  bool _isSyncing = false;
  final Set<int> _inFlightIds = <int>{};
  Timer? _retryTimer;
  int _backoffLevel = 0;

  static const Duration _connectionStabilizationDelay = Duration(seconds: 3);
  static const Duration _requestTimeout = Duration(minutes: 3);
  static const Duration _reachabilityTimeout = Duration(seconds: 8);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 3);

  static const List<Duration> _backoffDelays = [
    Duration(seconds: 15),
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 5),
  ];

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
          _backoffLevel = 0;
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

  IOClient _createClient(Uri uri) {
    final httpClient = HttpClient();
    if (ApiService.allowSelfSignedCert) {
      httpClient.badCertificateCallback = (cert, host, port) => host == uri.host;
    }
    return IOClient(httpClient);
  }

  bool _isNetworkError(Object error) {
    return error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  String _extrairMensagemErro(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        final message = body['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }
        final error = body['error'];
        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }
      }
    } catch (_) {
    }
    if (response.statusCode == 401 || response.statusCode == 403) {
      return 'Sessão expirada ou sem permissão. Faça login novamente.';
    }
    return 'Erro no servidor (HTTP ${response.statusCode}).';
  }

  String _mensagemErroRede(Object e) {
    if (e is TimeoutException) {
      return 'O servidor demorou para responder. Será reenviado automaticamente.';
    }
    if (e is SocketException) {
      return 'Sem conexão com o servidor. Será reenviado automaticamente.';
    }
    if (e is http.ClientException) {
      return 'Falha de comunicação com o servidor. Será reenviado automaticamente.';
    }
    return 'Erro inesperado ao enviar: $e';
  }

  Future<void> _registrarErroPendencia(int? localId, String mensagem) async {
    if (localId == null) return;
    try {
      await AppDatabase.instance.salvarErroSincronizacao(localId, mensagem);
    } catch (e) {
      await LogService.instance.error(
        'Falha ao registrar motivo da pendência',
        tag: 'SyncService',
        extra: e.toString(),
      );
    }
  }

  void _scheduleSyncRetry() {
    final delay = _backoffDelays[_backoffLevel.clamp(0, _backoffDelays.length - 1)];
    if (_backoffLevel < _backoffDelays.length - 1) _backoffLevel++;

    LogService.instance.info(
      'Nova tentativa de sincronização em ${delay.inSeconds}s',
      tag: 'SyncService',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () {
      if (!_isSyncing) {
        unawaited(syncPending());
      }
    });
  }

  Future<bool> _canReachServer() async {
    final uri = Uri.parse(ApiService.getBaseUrl());
    final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
    try {
      final socket = await Socket.connect(uri.host, port, timeout: _reachabilityTimeout);
      socket.destroy();
      return true;
    } catch (e) {
      await LogService.instance.warning(
        'Servidor inacessível no momento',
        tag: 'SyncService',
        extra: '${uri.host}:$port - $e',
      );
      return false;
    }
  }

  Future<http.Response?> _sendMultipartWithRetry({
    required Uri uri,
    required http.MultipartRequest Function() buildRequest,
    required String logTag,
    int? localId,
  }) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (attempt > 0) {
        await Future.delayed(_retryDelay * attempt);
        await LogService.instance.info(
          'Repetindo envio ($logTag), tentativa ${attempt + 1}',
          tag: 'SyncService',
        );
      }

      IOClient? client;
      try {
        client = _createClient(uri);
        final request = buildRequest();
        final streamedResponse = await client.send(request).timeout(_requestTimeout);
        return await http.Response.fromStream(streamedResponse);
      } catch (e, stack) {
        await LogService.instance.error(
          'Exceção ao enviar ($logTag)',
          tag: 'SyncService',
          extra: '$e\n$stack',
        );
        if (!_isNetworkError(e)) {
          await _registrarErroPendencia(localId, _mensagemErroRede(e));
          return null;
        }
        if (attempt == _maxRetries - 1) {
          await _registrarErroPendencia(localId, _mensagemErroRede(e));
          _scheduleSyncRetry();
          return null;
        }
      } finally {
        client?.close();
      }
    }
    return null;
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
        await _registrarErroPendencia(
            localId, 'Sessão expirada. Faça login novamente para enviar.');
        return false;
      }

      final uri = Uri.parse('${ApiService.getBaseUrl()}/relatorios/criar');
      var request = http.MultipartRequest('POST', uri);
      
      request.headers['Authorization'] = 'Bearer $token';

      final Map<String, dynamic> dadosParaJson = Map.from(dadosBrutos);
      
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
                  key,
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
      await _registrarErroPendencia(localId, _extrairMensagemErro(response));
      return false;
    } catch (e, stack) {
      await LogService.instance.error('Exceção ao enviar relatório', tag: 'SyncService', extra: '$e\n$stack');
      await _registrarErroPendencia(localId, _mensagemErroRede(e));
      if (_isNetworkError(e)) {
        _scheduleSyncRetry();
      }
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

      if (pendentes.isEmpty) {
        _retryTimer?.cancel();
        _backoffLevel = 0;
        return;
      }

      if (!await _canReachServer()) {
        _scheduleSyncRetry();
        return;
      }

      await LogService.instance.info(
        'Sincronização: ${pendentes.length} formulário(s) pendente(s) encontrado(s)',
        tag: 'SyncService',
      );

      var teveFalhaRede = false;

      for (final form in pendentes) {
        final id = form['id'] as int;
        final tipo = form['tipo'] as String;
        final templateId = form['template_id'] as int?;
        final dadosBrutos = jsonDecode(form['dados_json'] as String);

        bool success = false;
        if (tipo == 'familia_atingida') {
          success = await trySendFamiliaAtingida(dadosBrutos, localId: id);
        } else if (tipo == 'recibo_iah') {
          success = await trySendReciboIah(dadosBrutos, localId: id);
        } else {
          success = await trySendRelatorio(
            dadosBrutos,
            localId: id,
            templateId: templateId,
          );
        }

        if (success) {
          await AppDatabase.instance.marcarComoSincronizado(id);
        } else {
          teveFalhaRede = true;
        }
      }

      if (teveFalhaRede) {
        final restantes = await AppDatabase.instance.obterFormularios(sincronizado: false);
        if (restantes.isNotEmpty) {
          _scheduleSyncRetry();
        }
      } else {
        _backoffLevel = 0;
        _retryTimer?.cancel();
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
        await _registrarErroPendencia(
            localId, 'Sessão expirada. Faça login novamente para enviar.');
        return false;
      }

      final uri = Uri.parse('${ApiService.getBaseUrl()}/relatorios/familia-atingida');

      await LogService.instance.info(
        'Iniciando envio de relatório Família Atingida',
        tag: 'SyncService',
        extra: 'LocalID: $localId',
      );

      final response = await _sendMultipartWithRetry(
        uri: uri,
        logTag: 'Família Atingida',
        localId: localId,
        buildRequest: () {
          final request = http.MultipartRequest('POST', uri);
          request.headers['Authorization'] = 'Bearer $token';

          final requestJson = Map<String, dynamic>.from(dadosBrutos);
          final fotos = requestJson.remove('fotosResidencia') as List?;

          if (fotos != null) {
            for (int i = 0; i < fotos.length; i++) {
              request.files.add(http.MultipartFile.fromBytes(
                'RESIDENCIA',
                base64Decode(fotos[i] as String),
                filename: 'residencia_$i.jpg',
              ));
            }
          }

          request.fields['request'] = jsonEncode(requestJson);
          return request;
        },
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        await LogService.instance.info(
          'Relatório Família Atingida enviado com sucesso',
          tag: 'SyncService',
        );
        return true;
      }

      if (response != null) {
        await LogService.instance.error(
          'Erro ao enviar relatório Família Atingida',
          tag: 'SyncService',
          extra: 'Status: ${response.statusCode}, Body: ${response.body}',
        );
        await _registrarErroPendencia(localId, _extrairMensagemErro(response));
      }
      return false;
    } finally {
      if (localId != null) _inFlightIds.remove(localId);
    }
  }

  Future<bool> trySendReciboIah(
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
        await _registrarErroPendencia(
            localId, 'Sessão expirada. Faça login novamente para enviar.');
        return false;
      }

      final uri = Uri.parse('${ApiService.getBaseUrl()}/relatorios/recibo-iah');

      await LogService.instance.info(
        'Iniciando envio de recibo IAH',
        tag: 'SyncService',
        extra: 'LocalID: $localId',
      );

      final response = await _sendMultipartWithRetry(
        uri: uri,
        logTag: 'Recibo IAH',
        localId: localId,
        buildRequest: () => ReciboIahMultipart.buildFromPayload(
          uri: uri,
          token: token,
          dadosBrutos: dadosBrutos,
        ),
      );

      if (response != null && response.statusCode >= 200 && response.statusCode < 300) {
        await LogService.instance.info(
          'Recibo IAH enviado com sucesso',
          tag: 'SyncService',
        );
        return true;
      }

      if (response != null) {
        await LogService.instance.error(
          'Erro ao enviar recibo IAH',
          tag: 'SyncService',
          extra: 'Status: ${response.statusCode}, Body: ${response.body}',
        );

        if (response.body.contains('Já existe recibo') ||
            response.body.contains('recebimento encerrado')) {
          return true;
        }

        await _registrarErroPendencia(localId, _extrairMensagemErro(response));
      }

      return false;
    } finally {
      if (localId != null) _inFlightIds.remove(localId);
    }
  }
}
