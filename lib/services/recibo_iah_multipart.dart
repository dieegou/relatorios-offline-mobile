import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ReciboIahMultipart {
  static const String fieldEntrega = 'ENTREGA';
  static const String fieldAssinaturaResponsavel = 'ASSINATURA_RESPONSAVEL';
  static const String fieldAssinaturaAgente = 'ASSINATURA_AGENTE';

  static final MediaType _jpeg = MediaType('image', 'jpeg');
  static final MediaType _png = MediaType('image', 'png');

  static http.MultipartRequest buildFromPayload({
    required Uri uri,
    required String token,
    required Map<String, dynamic> dadosBrutos,
  }) {
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    final requestJson = Map<String, dynamic>.from(dadosBrutos);
    _attachFotos(request, requestJson);
    _attachAssinaturaResponsavel(request, requestJson);
    _attachAssinaturaAgente(request, requestJson);

    request.fields['request'] = jsonEncode(requestJson);
    return request;
  }

  static Future<http.MultipartRequest> buildFromFiles({
    required Uri uri,
    required String token,
    required Map<String, dynamic> requestData,
    required List<File> fotosEntrega,
    required File assinaturaResponsavel,
    required File assinaturaAgente,
  }) async {
    final request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $token';

    for (var i = 0; i < fotosEntrega.length; i++) {
      request.files.add(await http.MultipartFile.fromPath(
        fieldEntrega,
        fotosEntrega[i].path,
        filename: 'entrega_$i.jpg',
        contentType: _jpeg,
      ));
    }

    request.files.add(await http.MultipartFile.fromPath(
      fieldAssinaturaResponsavel,
      assinaturaResponsavel.path,
      filename: 'assinatura_responsavel.png',
      contentType: _png,
    ));

    request.files.add(await http.MultipartFile.fromPath(
      fieldAssinaturaAgente,
      assinaturaAgente.path,
      filename: 'assinatura_agente.png',
      contentType: _png,
    ));

    request.fields['request'] = jsonEncode(requestData);
    return request;
  }

  static void _attachFotos(http.MultipartRequest request, Map<String, dynamic> requestJson) {
    final fotos = requestJson.remove('fotosEntrega') as List?;
    if (fotos == null) return;

    for (var i = 0; i < fotos.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        fieldEntrega,
        base64Decode(fotos[i] as String),
        filename: 'entrega_$i.jpg',
        contentType: _jpeg,
      ));
    }
  }

  static void _attachAssinaturaResponsavel(
    http.MultipartRequest request,
    Map<String, dynamic> requestJson,
  ) {
    final assinatura = _extractSignature(
      requestJson,
      'assinaturaResponsavel',
      'ASSINATURA_RESPONSAVEL',
    );
    if (assinatura == null || assinatura.isEmpty) return;

    request.files.add(http.MultipartFile.fromBytes(
      fieldAssinaturaResponsavel,
      base64Decode(assinatura),
      filename: 'assinatura_responsavel.png',
      contentType: _png,
    ));
  }

  static void _attachAssinaturaAgente(
    http.MultipartRequest request,
    Map<String, dynamic> requestJson,
  ) {
    final assinatura = _extractSignature(
      requestJson,
      'assinaturaAgente',
      'ASSINATURA_AGENTE',
    );
    if (assinatura == null || assinatura.isEmpty) return;

    request.files.add(http.MultipartFile.fromBytes(
      fieldAssinaturaAgente,
      base64Decode(assinatura),
      filename: 'assinatura_agente.png',
      contentType: _png,
    ));
  }

  static String? _extractSignature(
    Map<String, dynamic> requestJson,
    String camelCaseKey,
    String upperCaseKey,
  ) {
    final value = requestJson.remove(camelCaseKey) ?? requestJson.remove(upperCaseKey);
    return value is String ? value : null;
  }
}
