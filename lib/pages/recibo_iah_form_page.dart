import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/core/models/entrega_iah_model.dart';
import 'package:relatoriooffline/services/location_service.dart';
import 'package:relatoriooffline/services/sync_service.dart';
import 'package:relatoriooffline/widgets/app_form_widgets.dart';
import 'package:relatoriooffline/widgets/signature_pad.dart';

class ReciboIahFormPage extends StatefulWidget {
  const ReciboIahFormPage({super.key});

  @override
  State<ReciboIahFormPage> createState() => _ReciboIahFormPageState();
}

class _ReciboIahFormPageState extends State<ReciboIahFormPage> {
  late EntregaIah _familia;
  bool _isLoading = false;
  bool _isSubmitting = false;

  double? _latitude;
  double? _longitude;
  double? _precisaoGps;
  bool _capturandoGps = false;

  final List<Uint8List> _fotosEntrega = [];
  int _fotosProcessando = 0;
  Uint8List? _assinaturaResponsavelBytes;
  Uint8List? _assinaturaAgenteBytes;

  final Map<String, bool> _itensEntregues = {};
  final TextEditingController _obsController = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _familia = ModalRoute.of(context)!.settings.arguments as EntregaIah;

    final available = _familia.itensAssistencia.getAvailableItens();
    for (var key in available.keys) {
      _itensEntregues.putIfAbsent(key, () => true);
    }
  }

  StreamSubscription<Position>? _gpsSubscription;

  @override
  void initState() {
    super.initState();
    _capturarLocalizacao();
    _gpsSubscription = LocationService.instance.updates.listen((position) {
      if (!mounted) return;
      if (_precisaoGps != null &&
          position.accuracy > 0 &&
          position.accuracy >= _precisaoGps!) {
        return;
      }
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _precisaoGps = position.accuracy;
      });
    });
  }

  @override
  void dispose() {
    _gpsSubscription?.cancel();
    _obsController.dispose();
    super.dispose();
  }

  Future<bool> _capturarLocalizacao({bool showFeedback = true}) async {
    if (_capturandoGps) return false;
    if (mounted) setState(() => _capturandoGps = true);

    try {
      final posicao = await LocationService.instance.getPosition();
      if (posicao == null) {
        if (mounted && showFeedback) {
          _mostrarSnack(
            'Não foi possível obter a localização. '
            'Verifique o GPS e tente novamente em local aberto.',
            sucesso: false,
          );
        }
        return false;
      }

      if (!mounted) return false;
      setState(() {
        _latitude = posicao.latitude;
        _longitude = posicao.longitude;
        _precisaoGps = posicao.accuracy;
      });
      return true;
    } finally {
      if (mounted) setState(() => _capturandoGps = false);
    }
  }

  Future<void> _selecionarFotoEntrega(ImageSource source) async {
    final endereco = _familia.enderecoResponsavel;
    if (source == ImageSource.camera) {
      try {
        final bytes = await ImageHelper.pickAndCompress(
          ImageSource.camera,
          endereco: endereco,
          latitude: _latitude,
          longitude: _longitude,
          precisaoGps: _precisaoGps,
          onProcessingStarted: () {
            if (mounted) setState(() => _fotosProcessando = 1);
          },
        );
        if (!mounted) return;
        setState(() {
          _fotosProcessando = 0;
          if (bytes != null) _fotosEntrega.add(bytes);
        });
      } catch (_) {
        if (mounted) setState(() => _fotosProcessando = 0);
      }
    } else {
      try {
        final novasFotos = await ImageHelper.pickMultiAndCompress(
          endereco: endereco,
          latitude: _latitude,
          longitude: _longitude,
          precisaoGps: _precisaoGps,
          onProcessingStarted: (count) {
            if (mounted) setState(() => _fotosProcessando = count);
          },
        );
        if (!mounted) return;
        setState(() {
          _fotosProcessando = 0;
          if (novasFotos.isNotEmpty) _fotosEntrega.addAll(novasFotos);
        });
      } catch (_) {
        if (mounted) setState(() => _fotosProcessando = 0);
      }
    }
  }

  void _abrirPreviewFoto(int index) {
    if (index < 0 || index >= _fotosEntrega.length) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.memory(
                  _fotosEntrega[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _abrirAssinatura(bool isResponsavel) async {
    await showDialog(
      context: context,
      builder: (context) => SignaturePad(
        onSignatureGenerated: (bytes) {
          setState(() {
            if (isResponsavel) {
              _assinaturaResponsavelBytes = bytes;
            } else {
              _assinaturaAgenteBytes = bytes;
            }
          });
        },
      ),
    );
  }

  void _mostrarSnack(String mensagem, {bool sucesso = true}) {
    if (!mounted) return;
    final cor = sucesso ? Colors.green.shade600 : Colors.red.shade700;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: cor,
        content: Row(
          children: [
            Icon(
              sucesso ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(mensagem)),
          ],
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _enviar() async {
    if (_isSubmitting) return;

    if (_familia.statusEntrega != 'LIBERADA') {
      _mostrarSnack('Esta entrega já foi registrada.', sucesso: false);
      return;
    }

    final reciboPendente = await AppDatabase.instance.obterReciboIahPendentePorFamilia(_familia.id);
    if (reciboPendente != null) {
      _mostrarSnack('Já existe um recibo pendente de envio para esta família.', sucesso: false);
      return;
    }

    if (_latitude == null || _longitude == null) {
      final sucessoLocalizacao = await _capturarLocalizacao(showFeedback: false);
      if (!sucessoLocalizacao && mounted) {
        _mostrarSnack(
          'Localização não capturada. O recibo será enviado sem coordenadas.',
          sucesso: false,
        );
      }
    }
    if (_fotosEntrega.isEmpty) {
      _mostrarSnack('Adicione pelo menos 1 foto da entrega.', sucesso: false);
      return;
    }
    if (_assinaturaResponsavelBytes == null || _assinaturaAgenteBytes == null) {
      _mostrarSnack('As duas assinaturas são obrigatórias.', sucesso: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSubmitting = true;
    });
    try {
      final auth = await AppDatabase.instance.obterToken();
      if (auth?['token'] == null) {
        _mostrarSnack('Token não encontrado.', sucesso: false);
        return;
      }

      final Map<String, dynamic> requestData = {
        'familiaAtingidaId': _familia.id,
        'desastreId': _familia.desastre.id,
        'municipalId': auth?['municipal_id'],
        'latitude': _latitude,
        'longitude': _longitude,
        'precisaoGps': _precisaoGps,
        'observacoes': _obsController.text,
      };

      final available = _familia.itensAssistencia.getAvailableItens();
      available.forEach((key, quantity) {
        requestData[key] = (_itensEntregues[key] == true) ? quantity : 0;
      });

      const allKeys = [
        'quantidadeAguaPotavel5L',
        'quantidadeCestaBasicaAlimentos',
        'quantidadeKitHigienePessoal',
        'quantidadeKitLimpezaDomestica',
        'quantidadeColchaoSolteiro',
        'quantidadeColchaoCasal',
        'quantidadeKitAcomodacaoSolteiro',
        'quantidadeKitAcomodacaoCasal',
        'quantidadeTelhaFibrocimento4mm',
        'quantidadeCumeeiraTelhaFibrocimento4mm',
        'quantidadeTelhaFibrocimento6mm',
        'quantidadeCumeeiraTelhaFibrocimento6mm',
      ];
      for (final key in allKeys) {
        requestData.putIfAbsent(key, () => 0);
      }

      final payload = Map<String, dynamic>.from(requestData);
      payload['fotosEntrega'] = _fotosEntrega.map(base64Encode).toList();
      payload['ASSINATURA_RESPONSAVEL'] = base64Encode(_assinaturaResponsavelBytes!);
      payload['ASSINATURA_AGENTE'] = base64Encode(_assinaturaAgenteBytes!);

      final localId = await AppDatabase.instance.salvarOuAtualizarReciboIahPendente(
        familiaAtingidaId: _familia.id,
        dadosJson: jsonEncode(payload),
      );

      await AppDatabase.instance.marcarEntregaComoEntregue(_familia.id, auth);

      final enviado = await SyncService.instance.trySendReciboIah(payload, localId: localId);

      if (enviado) {
        await AppDatabase.instance.marcarComoSincronizado(localId);
      }

      if (!mounted) return;
      _mostrarSnack(
        enviado
            ? 'Recibo enviado com sucesso!'
            : 'Sem conexão: recibo salvo como pendente.',
        sucesso: enviado,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        _mostrarSnack('Erro ao salvar recibo: $e', sucesso: false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSubmitting = false;
        });
      } else {
        _isLoading = false;
        _isSubmitting = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibo de Entrega IAH'),
        backgroundColor: const Color(0xFF3A3F7A),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInfoSection(),
                  const SizedBox(height: 16),
                  _buildItemsSection(),
                  const SizedBox(height: 16),
                  _buildGpsSection(),
                  const SizedBox(height: 16),
                  _buildPhotosSection(),
                  const SizedBox(height: 16),
                  _buildSignatureSection(
                    'Assinatura do Responsável',
                    _assinaturaResponsavelBytes,
                    () => _abrirAssinatura(true),
                  ),
                  const SizedBox(height: 16),
                  _buildSignatureSection(
                    'Assinatura do Agente de Campo',
                    _assinaturaAgenteBytes,
                    () => _abrirAssinatura(false),
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    controller: _obsController,
                    label: 'Observações',
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _enviar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A3F7A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'ENVIAR RECIBO',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection() {
    return AppFormSection(
      title: 'Dados da Entrega',
      children: [
        _buildReadOnlyField('Responsável', _familia.nomeResponsavel),
        _buildReadOnlyField('Endereço', _familia.enderecoResponsavel),
        _buildReadOnlyField('Desastre', _familia.desastre.cobrade),
        _buildReadOnlyField('Descrição', _familia.desastre.descricao),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    final available = _familia.itensAssistencia.getAvailableItens();
    return AppFormSection(
      title: 'Itens de Assistência',
      children: [
        const Text(
          'Marque os itens que foram entregues:',
          style: TextStyle(fontSize: 13, color: Colors.blueGrey),
        ),
        const SizedBox(height: 8),
        ...available.entries.map((entry) {
          return CheckboxListTile(
            title: Text(ItensAssistencia.getLabel(entry.key)),
            subtitle: Text('Quantidade autorizada: ${entry.value}'),
            value: _itensEntregues[entry.key] ?? false,
            onChanged: (val) {
              setState(() {
                _itensEntregues[entry.key] = val ?? false;
              });
            },
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }

  Widget _buildGpsSection() {
    return AppFormSection(
      title: 'Localização da Entrega',
      children: [
        if (_latitude != null && _longitude != null) ...[
          Text(
            'Latitude: $_latitude',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            'Longitude: $_longitude',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          if (_precisaoGps != null)
            Text(
              'Precisão: ${_precisaoGps!.toStringAsFixed(1)}m',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          const SizedBox(height: 12),
        ] else if (_capturandoGps)
          const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Capturando localização...',
                style: TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ],
          )
        else
          const Text(
            'Localização não capturada. Toque em "Capturar localização".',
            style: TextStyle(fontSize: 13, color: Colors.red),
          ),
        OutlinedButton.icon(
          onPressed: _capturandoGps ? null : () => _capturarLocalizacao(),
          icon: const Icon(Icons.my_location),
          label: Text(
            _capturandoGps
                ? 'Capturando...'
                : (_latitude == null ? 'Capturar localização' : 'Atualizar localização'),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection() {
    final totalVisivel = _fotosEntrega.length + _fotosProcessando;
    return AppFormSection(
      title: 'Fotos da Entrega',
      children: [
        AppImagePickerButtons(
          label: 'Adicionar Foto',
          obrigatorio: true,
          enabled: _fotosProcessando == 0,
          onCamera: () => _selecionarFotoEntrega(ImageSource.camera),
          onGallery: () => _selecionarFotoEntrega(ImageSource.gallery),
        ),
        if (totalVisivel > 0) ...[
          const SizedBox(height: 16),
          Text(
            _fotosProcessando > 0
                ? 'Processando foto…'
                : '${_fotosEntrega.length} imagem(ns) selecionada(s)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: totalVisivel,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index >= _fotosEntrega.length) {
                  return const AppPhotoProcessingTile(width: 120, height: 120);
                }
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _abrirPreviewFoto(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _fotosEntrega[index],
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => setState(() => _fotosEntrega.removeAt(index)),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_fotosEntrega.isNotEmpty && _fotosProcessando == 0)
            TextButton.icon(
              onPressed: () => setState(_fotosEntrega.clear),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Remover todas', style: TextStyle(color: Colors.red)),
            ),
        ],
      ],
    );
  }

  Widget _buildSignatureSection(String label, Uint8List? bytes, VoidCallback onTap) {
    return AppFormSection(
      title: label,
      children: [
        if (bytes != null)
          Container(
            height: 90,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Image.memory(bytes, fit: BoxFit.contain),
          )
        else
          const Text('Assinatura pendente', style: TextStyle(color: Colors.red, fontSize: 12)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.edit),
          label: Text(bytes == null ? 'Colher Assinatura' : 'Refazer Assinatura'),
        ),
      ],
    );
  }
}
