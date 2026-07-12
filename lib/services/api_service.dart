import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:http/io_client.dart';
import 'package:flutter/foundation.dart';
import 'package:relatoriooffline/services/log_service.dart';

class ApiService {
  //static const String _baseUrl = 'https://relatoriosoffline.app/api';
  //static const String _baseUrl = 'http://10.112.2.151/api';
  static const String _baseUrl = 'http://192.168.1.136:8084/api';
  //static const String _baseUrl = 'http://10.80.110.243:8084/api';
  static String customBaseUrl = '';
  static bool allowSelfSignedCert = !kReleaseMode;

  static String getBaseUrl() {
    if (customBaseUrl.isNotEmpty) {
      return customBaseUrl;
    }
    return _baseUrl;
  }

  IOClient _createClient() {
    final httpClient = HttpClient();
    if (allowSelfSignedCert) {
      final expectedHost = Uri.parse(getBaseUrl()).host;
      httpClient.badCertificateCallback = (cert, host, port) => host == expectedHost;
    }
    return IOClient(httpClient);
  }

  Future<List<dynamic>?> getTemplates(String token) async {
    try {
      await LogService.instance.info('Iniciando busca de templates no servidor', tag: 'ApiService');
      final apiUrl = getBaseUrl();
      final client = _createClient();
      final response = await client.get(
        Uri.parse('$apiUrl/templates'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));
      client.close();

      if (response.statusCode == 200) {
        final List<dynamic> templates = jsonDecode(response.body);
        await LogService.instance.info(
          'Templates buscados com sucesso',
          tag: 'ApiService',
          extra: 'Quantidade: ${templates.length}',
        );
        return templates;
      }
      
      await LogService.instance.warning(
        'Falha ao buscar templates',
        tag: 'ApiService',
        extra: 'Status: ${response.statusCode}, Body: ${response.body}',
      );
      return null;
    } catch (e, stack) {
      await LogService.instance.error(
        'Erro ao buscar templates',
        tag: 'ApiService',
        extra: '$e\n$stack',
      );
      return null;
    }
  }

  Future<Map<String, dynamic>?> getRegionalConfig(String token) async {
    try {
      final apiUrl = getBaseUrl();
      final client = _createClient();
      final response = await client.get(
        Uri.parse('$apiUrl/configuracoes/regional'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
      client.close();

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      await LogService.instance.error('Erro ao buscar config regional',
          tag: 'ApiService', extra: e.toString());
      return null;
    }
  }

  String? _asNonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<Map<String, dynamic>?> login(String username, String password) async {
    try {
      await LogService.instance.info('Tentativa de login iniciada', tag: 'ApiService', extra: 'Usuário: $username');
      final apiUrl = getBaseUrl();

      final requestBody = jsonEncode({
        'username': username,
        'password': password,
      });

      final client = _createClient();
      final response = await client.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 10));
      client.close();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        final token = _asNonEmptyString(data['token']) ??
            _asNonEmptyString(data['access_token']) ??
            _asNonEmptyString(data['accessToken']) ??
            (data['user'] is Map ? _asNonEmptyString(data['user']['token']) : null);
        
        final nome = _asNonEmptyString(data['nome']) ??
            _asNonEmptyString(data['name']) ??
            _asNonEmptyString(data['username']) ??
            (data['user'] is Map ? (_asNonEmptyString(data['user']['nome']) ?? _asNonEmptyString(data['user']['name'])) : null);

        var municipalId = data['municipalId'] ??
                         data['municipal_id'] ?? 
                         data['cidade_id'] ??
                         data['municipio_id'] ??
                         (data['user'] is Map ? (
                           data['user']['municipalId'] ?? 
                           data['user']['municipal_id'] ?? 
                           data['user']['cidade_id'] ??
                           data['user']['municipio_id']
                         ) : null);
                           
        final municipalNome = _asNonEmptyString(data['municipalNome']) ??
                             _asNonEmptyString(data['municipal_nome']) ??
                             _asNonEmptyString(data['cidade']) ??
                             _asNonEmptyString(data['municipio']) ??
                             _asNonEmptyString(data['cidade_nome']) ??
                             (data['user'] is Map ? (
                               _asNonEmptyString(data['user']['municipalNome']) ?? 
                               _asNonEmptyString(data['user']['municipal_nome']) ?? 
                               _asNonEmptyString(data['user']['cidade']) ??
                               _asNonEmptyString(data['user']['cidade_nome'])
                             ) : null);

        final bool habilitaRelatoriosDinamicos =
            data['habilitaRelatoriosDinamicos'] == true ||
                (data['user'] is Map &&
                    data['user']['habilitaRelatoriosDinamicos'] == true);

        final regionalId = data['regionalId'] ?? (data['user'] is Map ? data['user']['regionalId'] : null);
        final regionalNome = _asNonEmptyString(data['regionalNome']) ?? (data['user'] is Map ? _asNonEmptyString(data['user']['regionalNome']) : null);

        if (token == null) {
          await LogService.instance.warning('Login retornou sucesso mas sem token', tag: 'ApiService');
          return null;
        }

        await LogService.instance.info('Login realizado com sucesso', tag: 'ApiService', extra: 'Cidade: $municipalNome');

        return {
          'token': token,
          'nome': nome,
          'municipalId': municipalId is String ? int.tryParse(municipalId) : municipalId,
          'municipalNome': municipalNome,
          'regionalId': regionalId is String ? int.tryParse(regionalId) : regionalId,
          'regionalNome': regionalNome,
          'habilitaRelatoriosDinamicos': habilitaRelatoriosDinamicos,
        };
      }

      await LogService.instance.warning(
        'Falha no login',
        tag: 'ApiService',
        extra: 'Status: ${response.statusCode}, Body: ${response.body}',
      );
      return null;
    } on SocketException catch (e) {
      await LogService.instance.error('Erro de rede no login', tag: 'ApiService', extra: e.toString());
      throw Exception(
        'Sem conexão com a internet. Verifique sua rede e tente novamente.',
      );
    } on TimeoutException catch (e) {
      await LogService.instance.error('Timeout no login', tag: 'ApiService', extra: e.toString());
      throw Exception(
        'O servidor demorou para responder. Tente novamente em instantes.',
      );
    } on http.ClientException catch (e) {
      await LogService.instance.error('Erro de cliente no login', tag: 'ApiService', extra: e.toString());
      throw Exception(
        'Não conseguimos comunicar com o servidor. Por favor, tente novamente.',
      );
    } catch (e, stack) {
      await LogService.instance.error('Exceção inesperada no login', tag: 'ApiService', extra: '$e\n$stack');
      rethrow;
    }
  }

  Future<bool> sincronizarFormulario({
    required String token,
    required String tipo,
    required Map<String, dynamic> dados,
  }) async {
    const int maxRetries = 3;
    const Duration initialDelay = Duration(seconds: 2);
    const Duration timeout = Duration(seconds: 30);

    final apiUrl = getBaseUrl();

    await LogService.instance.info(
      'Iniciando sincronização de formulário',
      tag: 'ApiService',
      extra: 'Tipo: $tipo',
    );

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          await LogService.instance.info(
            'Tentativa ${attempt + 1} de sincronização',
            tag: 'ApiService',
          );
        }

        final client = _createClient();
        try {
          final response = await client.post(
            Uri.parse('$apiUrl/formularios'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'tipo': tipo,
              'dados': dados,
            }),
          ).timeout(timeout);

          if (response.statusCode == 200 || response.statusCode == 201) {
            await LogService.instance.info(
              'Formulário sincronizado com sucesso',
              tag: 'ApiService',
            );
            return true;
          }

          await LogService.instance.warning(
            'Falha na sincronização',
            tag: 'ApiService',
            extra: 'Status: ${response.statusCode}, Body: ${response.body}',
          );

          if (response.statusCode >= 500 && attempt < maxRetries - 1) {
            await Future.delayed(initialDelay * (attempt + 1));
            continue;
          }

          return false;
        } finally {
          client.close();
        }
      } on TimeoutException catch (e) {
        await LogService.instance.error(
          'Timeout na sincronização',
          tag: 'ApiService',
          extra: e.toString(),
        );
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (attempt + 1));
          continue;
        }
        return false;
      } on SocketException catch (e) {
        await LogService.instance.error(
          'Erro de rede na sincronização',
          tag: 'ApiService',
          extra: e.toString(),
        );
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (attempt + 1));
          continue;
        }
        return false;
      } on http.ClientException catch (e) {
        await LogService.instance.error(
          'Erro de cliente HTTP na sincronização',
          tag: 'ApiService',
          extra: e.toString(),
        );
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (attempt + 1));
          continue;
        }
        return false;
      } catch (e, stack) {
        await LogService.instance.error(
          'Exceção inesperada na sincronização',
          tag: 'ApiService',
          extra: '$e\n$stack',
        );
        if (attempt < maxRetries - 1) {
          await Future.delayed(initialDelay * (attempt + 1));
          continue;
        }
        return false;
      }
    }
    return false;
  }
}
