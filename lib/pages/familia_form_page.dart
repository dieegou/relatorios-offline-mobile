import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:relatoriooffline/widgets/app_form_widgets.dart';
import 'package:relatoriooffline/widgets/custom_dropdown.dart';
import 'package:relatoriooffline/widgets/custon_item_quantidade.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/sync_service.dart';

class FamiliaFormPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final int? localId;
  final bool readOnly;

  const FamiliaFormPage({
    super.key,
    this.initialData,
    this.localId,
    this.readOnly = false,
  });

  @override
  State<FamiliaFormPage> createState() => _FamiliaFormPageState();
}

class _FamiliaFormPageState extends State<FamiliaFormPage> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {
    'nomeAtingido': TextEditingController(),
    'cpfAtingido': TextEditingController(),
    'rgAtingido': TextEditingController(),
    'dataNascimentoAtingido': TextEditingController(),
    'enderecoAtingido': TextEditingController(),
    'bairroAtingido': TextEditingController(),
    'cidadeAtingido': TextEditingController(),
    'complementoAtingido': TextEditingController(),

    'localizacao': TextEditingController(),
    'moradia': TextEditingController(),
    'danoResidencia': TextEditingController(),
    'estimativaDanoMoveis': TextEditingController(),
    'estimativaDanoEdificacao': TextEditingController(),
    'ocupacao': TextEditingController(),
    'tipoConstrucao': TextEditingController(),
    'alternativaMoradia': TextEditingController(),
    'observacaoImovel': TextEditingController(),

    'numeroTotalPessoas': TextEditingController(),
    'menores0a12': TextEditingController(),
    'menores13a17': TextEditingController(),
    'maiores18a59': TextEditingController(),
    'idosos60mais': TextEditingController(),
    'possuiNecessidadesEspeciais': TextEditingController(),
    'quantidadeNecessidadesEspeciais': TextEditingController(),
    'observacaoNecessidades': TextEditingController(),
    'usoMedicamentoContinuo': TextEditingController(),
    'medicamento': TextEditingController(),
    'possuiDesaparecidos': TextEditingController(),
    'quantidadeDesaparecidos': TextEditingController(),
    'possuiFeridos': TextEditingController(),
    'quantidadeFeridos': TextEditingController(),
    'quantidadeObitos': TextEditingController(),

    'outrasNecessidades': TextEditingController(),
    'observacaoAssistencia': TextEditingController(),

    'qtdAguaPotavel5L': TextEditingController(),
    'qtdColchoesSolteiro': TextEditingController(),
    'qtdColchoesCasal': TextEditingController(),
    'qtdCestasBasicas': TextEditingController(),
    'qtdKitHigienePessoal': TextEditingController(),
    'qtdKitLimpeza': TextEditingController(),
    'qtdMoveis': TextEditingController(),
    'qtdRoupas': TextEditingController(),
    'qtdTelhas6mm': TextEditingController(),
    'qtdTelhas4mm': TextEditingController(),

    'qtdAguaPotavel5LQtd': TextEditingController(),
    'qtdColchoesSolteiroQtd': TextEditingController(),
    'qtdColchoesCasalQtd': TextEditingController(),
    'qtdCestasBasicasQtd': TextEditingController(),
    'qtdKitHigienePessoalQtd': TextEditingController(),
    'qtdKitLimpezaQtd': TextEditingController(),
    'qtdMoveisQtd': TextEditingController(),
    'qtdRoupasQtd': TextEditingController(),
    'qtdTelhas6mmQtd': TextEditingController(),
    'qtdTelhas4mmQtd': TextEditingController(),

    'coordenadoriaMunicipalId': TextEditingController(),
  };

  DateTime? _dataNascimentoSelecionada;
  double? _latitude;
  double? _longitude;
  final List<Uint8List> _fotosResidencia = <Uint8List>[];
  bool _possuiNecessidadesEspeciais = false;
  bool _possuiDesaparecidos = false;
  bool _possuiFeridos = false;
  bool _isSubmitting = false;

  final _cpfFormatter = _CpfInputFormatter();
  late final NumberFormat _currencyFormat;
  late final _CurrencyInputFormatter _currencyInputFormatter;
  final Set<String> _camposObrigatorios = {
    'nomeAtingido',
    'cpfAtingido',
    'dataNascimentoAtingido',
    'enderecoAtingido',
    'cidadeAtingido',
    'localizacao',
    'moradia',
    'danoResidencia',
    'numeroTotalPessoas',
    'usoMedicamentoContinuo',
  };

  @override
  void initState() {
    super.initState();
    _currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    _currencyInputFormatter = _CurrencyInputFormatter(_currencyFormat);

    if (widget.initialData != null) {
      _preencherCampos(widget.initialData!);
    } else {
      _capturarLocalizacao();
    }
  }

  void _preencherCampos(Map<String, dynamic> data) {
    data.forEach((key, value) {
      if (_controllers.containsKey(key)) {
        if (key == 'estimativaDanoMoveis' || key == 'estimativaDanoEdificacao') {
          if (value != null) {
            final doubleVal = double.tryParse(value.toString()) ?? 0.0;
            _controllers[key]!.text = _currencyFormat.format(doubleVal);
          }
        } else {
          _controllers[key]!.text = value?.toString() ?? '';
        }
      }
    });

    if (data['dataNascimentoAtingido'] != null) {
      _dataNascimentoSelecionada = DateTime.parse(data['dataNascimentoAtingido']);
      _controllers['dataNascimentoAtingido']!.text = _formatarData(_dataNascimentoSelecionada!);
    }

    _latitude = double.tryParse(data['latitude']?.toString() ?? '');
    _longitude = double.tryParse(data['longitude']?.toString() ?? '');

    if (data['fotosResidencia'] != null && data['fotosResidencia'] is List) {
      final fotos = data['fotosResidencia'] as List;
      for (var f in fotos) {
        _fotosResidencia.add(base64Decode(f.toString()));
      }
    }

    setState(() {
      _possuiNecessidadesEspeciais = _normalizeBool(data['possuiNecessidadesEspeciais']?.toString());
      _possuiDesaparecidos = _normalizeBool(data['possuiDesaparecidos']?.toString());
      _possuiFeridos = _normalizeBool(data['possuiFeridos']?.toString());
    });
  }

  String _formatarData(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year}';
  }

  Future<void> _selecionarDataNascimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimentoSelecionada ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );

    if (picked != null) {
      setState(() {
        _dataNascimentoSelecionada = picked;
        _controllers['dataNascimentoAtingido']!.text = _formatarData(picked);
      });
    }
  }

  void _setSubmitting(bool value) {
    if (mounted) {
      setState(() => _isSubmitting = value);
    } else {
      _isSubmitting = value;
    }
  }

  void _mostrarMensagemTopo(String mensagem, {bool sucesso = false}) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final cor = sucesso ? Colors.green.shade600 : Colors.red.shade700;

    messenger
      ..hideCurrentMaterialBanner()
      ..showMaterialBanner(
        MaterialBanner(
          backgroundColor: cor,
          content: Text(
            mensagem,
            style: const TextStyle(color: Colors.white),
          ),
          leading: Icon(
            sucesso ? Icons.check_circle : Icons.error_outline,
            color: Colors.white,
          ),
          actions: [
            TextButton(
              onPressed: messenger.hideCurrentMaterialBanner,
              child: const Text(
                'Fechar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        messenger.hideCurrentMaterialBanner();
      }
    });
  }

  bool _validarObrigatoriosNoSubmit() {
    const labelsObrigatorios = <String, String>{
      'nomeAtingido': 'Nome',
      'cpfAtingido': 'CPF',
      'dataNascimentoAtingido': 'Data de Nascimento',
      'enderecoAtingido': 'Endereço',
      'cidadeAtingido': 'Cidade',
      'localizacao': 'Localização',
      'moradia': 'Moradia',
      'danoResidencia': 'Danos na Residência',
      'numeroTotalPessoas': 'Número Total de Pessoas',
      'usoMedicamentoContinuo': 'Uso de Medicamento Contínuo',
    };

    for (final entry in labelsObrigatorios.entries) {
      final valor = _controllers[entry.key]?.text.trim() ?? '';
      if (valor.isEmpty) {
        _mostrarMensagemTopo('Preencha o campo obrigatório: ${entry.value}.');
        return false;
      }
    }

    final cpfDigits = (_controllers['cpfAtingido']?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (cpfDigits.isNotEmpty && cpfDigits.length != 11) {
      _mostrarMensagemTopo('CPF inválido. Informe os 11 dígitos.');
      return false;
    }

    final totalPessoas = int.tryParse(_controllers['numeroTotalPessoas']?.text ?? '');
    if (totalPessoas == null || totalPessoas <= 0) {
      _mostrarMensagemTopo('Informe um número total de pessoas válido.');
      return false;
    }

    if (_possuiNecessidadesEspeciais && (_controllers['quantidadeNecessidadesEspeciais']?.text.trim().isEmpty ?? true)) {
      _mostrarMensagemTopo('Informe a quantidade de necessidades especiais.');
      return false;
    }

    if (_possuiDesaparecidos && (_controllers['quantidadeDesaparecidos']?.text.trim().isEmpty ?? true)) {
      _mostrarMensagemTopo('Informe a quantidade de desaparecidos.');
      return false;
    }

    if (_possuiFeridos && (_controllers['quantidadeFeridos']?.text.trim().isEmpty ?? true)) {
      _mostrarMensagemTopo('Informe a quantidade de feridos.');
      return false;
    }

    return true;
  }

  Future<void> _salvarFormulario() async {
    if (_isSubmitting) return;
    final formValido = _formKey.currentState?.validate() ?? false;
    final obrigatoriosValidos = _validarObrigatoriosNoSubmit();
    if (!formValido || !obrigatoriosValidos) {
      return;
    }

    _setSubmitting(true);

    if (_latitude == null || _longitude == null) {
      final sucessoLocalizacao = await _capturarLocalizacao(showFeedback: false);
      if (!sucessoLocalizacao && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível obter a localização atual.')),
        );
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Salvando formulário...')),
    );

    int? toInt(String? value) {
      if (value == null || value.isEmpty) return null;
      return int.tryParse(value);
    }

    double? parseCurrency(String? value) {
      if (value == null || value.isEmpty) return null;
      final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return null;
      final cents = double.tryParse(cleaned);
      if (cents == null) return null;
      return cents / 100;
    }

    bool? toBool(String? value) {
      if (value == null || value.isEmpty) return null;
      final normalized = value.toLowerCase();
      if (normalized == 'sim' || normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'nao' || normalized == 'não' || normalized == 'false' || normalized == '0') {
        return false;
      }
      return null;
    }

    final auth = await AppDatabase.instance.obterToken();
    final municipalIdFromAuth = auth?['municipal_id'];

    final payload = {
      'nomeAtingido': _controllers['nomeAtingido']!.text,
      'cpfAtingido': _controllers['cpfAtingido']!.text,
      'rgAtingido': _controllers['rgAtingido']!.text,
      'dataNascimentoAtingido': _dataNascimentoSelecionada?.toIso8601String(),
      'enderecoAtingido': _controllers['enderecoAtingido']!.text,
      'bairroAtingido': _controllers['bairroAtingido']!.text,
      'cidadeAtingido': _controllers['cidadeAtingido']!.text,
      'complementoAtingido': _controllers['complementoAtingido']!.text,
      'localizacao': _controllers['localizacao']!.text,
      'moradia': _controllers['moradia']!.text,
      'danoResidencia': _controllers['danoResidencia']!.text,
      'estimativaDanoMoveis': parseCurrency(_controllers['estimativaDanoMoveis']!.text),
      'estimativaDanoEdificacao': parseCurrency(_controllers['estimativaDanoEdificacao']!.text),
      'ocupacao': _controllers['ocupacao']!.text,
      'tipoConstrucao': _controllers['tipoConstrucao']!.text,
      'alternativaMoradia': _controllers['alternativaMoradia']!.text,
      'observacaoImovel': _controllers['observacaoImovel']!.text,
      'numeroTotalPessoas': toInt(_controllers['numeroTotalPessoas']!.text),
      'menores0a12': toInt(_controllers['menores0a12']!.text),
      'menores13a17': toInt(_controllers['menores13a17']!.text),
      'maiores18a59': toInt(_controllers['maiores18a59']!.text),
      'idosos60mais': toInt(_controllers['idosos60mais']!.text),
      'possuiNecessidadesEspeciais': _possuiNecessidadesEspeciais,
      'quantidadeNecessidadesEspeciais': _possuiNecessidadesEspeciais
          ? toInt(_controllers['quantidadeNecessidadesEspeciais']!.text)
          : 0,
      'observacaoNecessidades': _controllers['observacaoNecessidades']!.text,
      'usoMedicamentoContinuo': toBool(_controllers['usoMedicamentoContinuo']!.text) ?? false,
      'medicamento': _controllers['medicamento']!.text,
      'possuiDesaparecidos': _possuiDesaparecidos,
      'quantidadeDesaparecidos': _possuiDesaparecidos
          ? toInt(_controllers['quantidadeDesaparecidos']!.text)
          : 0,
      'quantidadeFeridos': _possuiFeridos
          ? toInt(_controllers['quantidadeFeridos']!.text)
          : 0,
      'quantidadeObitos': toInt(_controllers['quantidadeObitos']!.text),
      'qtdAguaPotavel5L': toInt(_controllers['qtdAguaPotavel5LQtd']!.text) ?? 0,
      'qtdColchoesSolteiro': toInt(_controllers['qtdColchoesSolteiroQtd']!.text) ?? 0,
      'qtdColchoesCasal': toInt(_controllers['qtdColchoesCasalQtd']!.text) ?? 0,
      'qtdCestasBasicas': toInt(_controllers['qtdCestasBasicasQtd']!.text) ?? 0,
      'qtdKitHigienePessoal': toInt(_controllers['qtdKitHigienePessoalQtd']!.text) ?? 0,
      'qtdKitLimpeza': toInt(_controllers['qtdKitLimpezaQtd']!.text) ?? 0,
      'qtdMoveis': toInt(_controllers['qtdMoveisQtd']!.text) ?? 0,
      'qtdTelhas6mm': toInt(_controllers['qtdTelhas6mmQtd']!.text) ?? 0,
      'qtdTelhas4mm': toInt(_controllers['qtdTelhas4mmQtd']!.text) ?? 0,
      'qtdRoupas': toInt(_controllers['qtdRoupasQtd']!.text) ?? 0,
      'outrasNecessidades': _controllers['outrasNecessidades']!.text,
      'observacaoAssistencia': _controllers['observacaoAssistencia']!.text,
      'coordenadoriaMunicipalId': _controllers['coordenadoriaMunicipalId']!.text.isEmpty 
          ? municipalIdFromAuth?.toString() 
          : _controllers['coordenadoriaMunicipalId']!.text,
      'latitude': _latitude?.toString(),
      'longitude': _longitude?.toString(),
      'fotosResidencia': _fotosResidencia.map(base64Encode).toList(),
    };

    final dadosJson = jsonEncode(payload);

    try {
      int id;
      if (widget.localId != null) {
        id = widget.localId!;
        await AppDatabase.instance.atualizarFormulario(id: id, dadosJson: dadosJson);
      } else {
        id = await AppDatabase.instance.salvarFormulario(tipo: 'familia', dadosJson: dadosJson);
      }

      final enviado = await SyncService.instance.trySendRelatorio(payload, localId: id);

      if (enviado) {
        await AppDatabase.instance.marcarComoSincronizado(id);
        if (mounted) {
          _mostrarSnack('Formulário sincronizado com sucesso.');
          _retornarAposSalvar();
        }
      } else {
        if (mounted) {
          _mostrarSnack('Sem conexão: formulário salvo como pendente.', sucesso: false);
          _retornarAposSalvar();
        }
      }
    } catch (error) {
      if (mounted) {
        _mostrarSnack('Erro ao salvar formulário: $error', sucesso: false);
      }
    } finally {
      _setSubmitting(false);
    }
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

  void _retornarAposSalvar() {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    });
  }

  String? _validarCampo(String key, String? value) {
    final texto = value?.trim() ?? '';
    final obrigatorio = _camposObrigatorios.contains(key);
    if (obrigatorio && texto.isEmpty) {
      return 'Campo obrigatório';
    }

    if (key == 'cpfAtingido' && texto.isNotEmpty) {
      final digits = texto.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 11) {
        return 'CPF inválido';
      }
    }

    if (key == 'numeroTotalPessoas' && texto.isNotEmpty) {
      final total = int.tryParse(texto);
      if (total == null || total <= 0) {
        return 'Informe um total válido';
      }
    }

    return null;
  }

  Widget _campo(
    String key, {
    String? label,
    bool obrigatorio = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return AppTextFormField(
      controller: _controllers[key]!,
      label: label ?? key,
      obrigatorio: obrigatorio || _camposObrigatorios.contains(key),
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      validator: validator ?? (value) => _validarCampo(key, value),
    );
  }

  Widget _campoDataNascimento() {
    return AppTextFormField(
      controller: _controllers['dataNascimentoAtingido']!,
      label: 'Data de Nascimento',
      obrigatorio: true,
      readOnly: true,
      suffixIcon: const Icon(Icons.calendar_today),
      onTap: _selecionarDataNascimento,
      validator: (value) => _validarCampo('dataNascimentoAtingido', value),
    );
  }

  Future<void> _selecionarFotoResidencia(ImageSource source) async {
    if (source == ImageSource.camera) {
      final bytes = await ImageHelper.pickAndCompress(ImageSource.camera);
      if (bytes != null) {
        setState(() => _fotosResidencia.add(bytes));
      }
    } else {
      final novasFotos = await ImageHelper.pickMultiAndCompress();
      if (novasFotos.isNotEmpty) {
        setState(() => _fotosResidencia.addAll(novasFotos));
      }
    }
  }

  void _abrirPreviewFoto(int index) {
    if (index < 0 || index >= _fotosResidencia.length) return;
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
                  _fotosResidencia[index],
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

  Widget _previewFotoResidencia() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppImagePickerButtons(
          onCamera: () => _selecionarFotoResidencia(ImageSource.camera),
          onGallery: () => _selecionarFotoResidencia(ImageSource.gallery),
        ),
        if (_fotosResidencia.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            '${_fotosResidencia.length} imagem(ns) selecionada(s)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fotosResidencia.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    GestureDetector(
                      onTap: () => _abrirPreviewFoto(index),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _fotosResidencia[index],
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
                        onTap: () => setState(() => _fotosResidencia.removeAt(index)),
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
          TextButton.icon(
            onPressed: () => setState(_fotosResidencia.clear),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label: const Text('Remover todas', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }

  Future<bool> _capturarLocalizacao({bool showFeedback = true}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ative o serviço de localização para capturar latitude/longitude.')),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted && showFeedback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada.')),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted && showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissão de localização permanentemente negada. Configure nas definições.')),
        );
      }
      return false;
    }

    Position? posicao;
    try {
      posicao = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 30),
        ),
      );
    } catch (e) {
      posicao = await Geolocator.getLastKnownPosition();
      if (posicao == null) return false;
    }

    _latitude = posicao.latitude;
    _longitude = posicao.longitude;
    if (_controllers.containsKey('localizacao')) {
      _controllers['localizacao']!.text = "$_latitude,$_longitude";
    }
    return true;
  }

  bool _normalizeBool(String? value) {
    if (value == null) return false;
    final normalized = value.toLowerCase();
    return normalized == 'sim' || normalized == 'true' || normalized == '1';
  }

  void _updatePossui(String key, bool value, {TextEditingController? quantidadeController}) {
    setState(() {
      switch (key) {
        case 'necessidades':
          _possuiNecessidadesEspeciais = value;
          break;
        case 'desaparecidos':
          _possuiDesaparecidos = value;
          break;
        case 'feridos':
          _possuiFeridos = value;
          break;
      }
    });

    _controllers[
      key == 'necessidades'
          ? 'possuiNecessidadesEspeciais'
          : key == 'desaparecidos'
              ? 'possuiDesaparecidos'
              : 'possuiFeridos'
    ]?.text = value ? 'Sim' : 'Não';

    if (!value && quantidadeController != null) {
      quantidadeController.text = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cadastro de Família"),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
        scrolledUnderElevation: 0,
        actions: [
          if (!widget.readOnly)
            IconButton(
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              onPressed: _isSubmitting ? null : _salvarFormulario,
            )
        ],
      ),

      body: SafeArea(
        child: AbsorbPointer(
          absorbing: widget.readOnly,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(16),
              children: [
                AppFormSection(
                  title: 'Identificação do Atingido',
                  children: [
                    _campo('nomeAtingido', label: 'Nome'),
                    _campo(
                      'cpfAtingido',
                      label: 'CPF',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, _cpfFormatter],
                    ),
                    _campo('rgAtingido', label: 'RG'),
                    _campoDataNascimento(),
                    _campo('enderecoAtingido', label: 'Endereço'),
                    _campo('bairroAtingido', label: 'Bairro'),
                    _campo('cidadeAtingido', label: 'Cidade'),
                    _campo('complementoAtingido', label: 'Complemento'),
                  ],
                ),
                AppFormSection(
                  title: 'Dados do Imóvel',
                  children: [
                    CustomDropdown(
                      label: 'Localização',
                      controller: _controllers['localizacao']!,
                      opcoes: const ['Rural', 'Urbana'],
                      obrigatorio: true,
                    ),
                    CustomDropdown(
                      label: 'Moradia',
                      controller: _controllers['moradia']!,
                      opcoes: const ['Própria', 'Alugada'],
                      obrigatorio: true,
                    ),
                    CustomDropdown(
                      label: 'Danos na Residência',
                      controller: _controllers['danoResidencia']!,
                      opcoes: const ['Danos Parcial', 'Dano Total', 'Sem Dano'],
                      obrigatorio: true,
                    ),
                    _campoMonetario(
                      'estimativaDanoMoveis',
                      label: 'Estimativa de Dano em Móveis',
                    ),
                    _campoMonetario(
                      'estimativaDanoEdificacao',
                      label: 'Estimativa de Dano na Edificação',
                    ),
                    CustomDropdown(
                      label: 'Ocupação',
                      controller: _controllers['ocupacao']!,
                      opcoes: const ['Regular', 'Irregular'],
                    ),
                    CustomDropdown(
                      label: 'Tipo de Construção',
                      controller: _controllers['tipoConstrucao']!,
                      opcoes: const ['Alvenaria', 'Madeira', 'Mista'],
                    ),
                    CustomDropdown(
                      label: 'Alternativa de Moradia',
                      controller: _controllers['alternativaMoradia']!,
                      opcoes: const [
                        'Não Possui',
                        'Possui Outra Casa',
                        'Casa de Parentes/Amigos',
                        'Abrigo Temporário',
                        'Outros'
                      ],
                    ),
                    _campo('observacaoImovel', label: 'Observações'),
                  ],
                ),
                AppFormSection(
                  title: 'Pessoas na Residência',
                  children: [
                    _campo(
                      'numeroTotalPessoas',
                      label: 'Número Total de Pessoas',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _campo(
                      'menores0a12',
                      label: 'Menores 0 a 12',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _campo(
                      'menores13a17',
                      label: 'Menores 13 a 17',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _campo(
                      'maiores18a59',
                      label: 'Maiores 18 a 59',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    _campo(
                      'idosos60mais',
                      label: 'Idosos 60+',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    CustomDropdown(
                      label: 'Necessidades Especiais',
                      controller: _controllers['possuiNecessidadesEspeciais']!,
                      opcoes: const ['Sim', 'Não'],
                      onChanged: (value) {
                        final possui = (value ?? '').toLowerCase() == 'sim';
                        _updatePossui(
                          'necessidades',
                          possui,
                          quantidadeController: _controllers['quantidadeNecessidadesEspeciais'],
                        );
                      },
                    ),
                    if (_possuiNecessidadesEspeciais)
                      _campo(
                        'quantidadeNecessidadesEspeciais',
                        label: 'Quantidade',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    _campo('observacaoNecessidades', label: 'Observações'),
                    CustomDropdown(
                      label: 'Uso de Medicamento Contínuo',
                      controller: _controllers['usoMedicamentoContinuo']!,
                      opcoes: const ['Sim', 'Não'],
                      obrigatorio: true,
                    ),
                    CustomDropdown(
                      label: 'Possui Desaparecidos?',
                      controller: _controllers['possuiDesaparecidos']!,
                      opcoes: const ['Sim', 'Não'],
                      onChanged: (value) {
                        final possui = (value ?? '').toLowerCase() == 'sim';
                        _updatePossui(
                          'desaparecidos',
                          possui,
                          quantidadeController: _controllers['quantidadeDesaparecidos'],
                        );
                      },
                    ),
                    if (_possuiDesaparecidos)
                      _campo(
                        'quantidadeDesaparecidos',
                        label: 'Quantidade Desaparecidos',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    CustomDropdown(
                      label: 'Possui Feridos?',
                      controller: _controllers['possuiFeridos']!,
                      opcoes: const ['Sim', 'Não'],
                      onChanged: (value) {
                        final possui = (value ?? '').toLowerCase() == 'sim';
                        _updatePossui(
                          'feridos',
                          possui,
                          quantidadeController: _controllers['quantidadeFeridos'],
                        );
                      },
                    ),
                    if (_possuiFeridos)
                      _campo(
                        'quantidadeFeridos',
                        label: 'Quantidade Feridos',
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    _campo(
                      'quantidadeObitos',
                      label: 'Quantidade Óbitos',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
                AppFormSection(
                  title: 'Assistência Humanitária - Necessidades Imediatas',
                  children: [
                    CustomItemQuantidade(
                      label: 'Água Potável 5L',
                      controllerMarcado: _controllers['qtdAguaPotavel5L']!,
                      controllerQuantidade: _controllers['qtdAguaPotavel5LQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Colchões Solteiro',
                      controllerMarcado: _controllers['qtdColchoesSolteiro']!,
                      controllerQuantidade: _controllers['qtdColchoesSolteiroQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Colchões Casal',
                      controllerMarcado: _controllers['qtdColchoesCasal']!,
                      controllerQuantidade: _controllers['qtdColchoesCasalQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Cesta Básica',
                      controllerMarcado: _controllers['qtdCestasBasicas']!,
                      controllerQuantidade: _controllers['qtdCestasBasicasQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Kit Higiene Pessoal',
                      controllerMarcado: _controllers['qtdKitHigienePessoal']!,
                      controllerQuantidade: _controllers['qtdKitHigienePessoalQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Kit Limpeza',
                      controllerMarcado: _controllers['qtdKitLimpeza']!,
                      controllerQuantidade: _controllers['qtdKitLimpezaQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Móveis',
                      controllerMarcado: _controllers['qtdMoveis']!,
                      controllerQuantidade: _controllers['qtdMoveisQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Roupas',
                      controllerMarcado: _controllers['qtdRoupas']!,
                      controllerQuantidade: _controllers['qtdRoupasQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Telhas 6mm',
                      controllerMarcado: _controllers['qtdTelhas6mm']!,
                      controllerQuantidade: _controllers['qtdTelhas6mmQtd']!,
                    ),
                    CustomItemQuantidade(
                      label: 'Telhas 4mm',
                      controllerMarcado: _controllers['qtdTelhas4mm']!,
                      controllerQuantidade: _controllers['qtdTelhas4mmQtd']!,
                    ),
                    _campo('outrasNecessidades', label: 'Outros Itens'),
                    _campo('observacaoAssistencia', label: 'Observações'),
                    const SizedBox(height: 6),
                    Text(
                      'Fotos da residência',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _previewFotoResidencia(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      floatingActionButton: widget.readOnly 
          ? null 
          : FloatingActionButton.extended(
              backgroundColor: _isSubmitting ? Colors.grey : Colors.orange.shade700,
              onPressed: _isSubmitting ? null : _salvarFormulario,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSubmitting ? 'Salvando...' : 'Salvar'),
            ),
    );
  }

  Widget _campoMonetario(String key, {required String label}) {
    return AppTextFormField(
      controller: _controllers[key]!,
      label: label,
      keyboardType: TextInputType.number,
      inputFormatters: [_currencyInputFormatter],
      hintText: 'R\$ 0,00',
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  static const _maxLength = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > _maxLength ? digits.substring(0, _maxLength) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if ((i == 2 || i == 5) && i != limited.length - 1) {
        buffer.write('.');
      } else if (i == 8 && i != limited.length - 1) {
        buffer.write('-');
      }
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _CurrencyInputFormatter extends TextInputFormatter {
  _CurrencyInputFormatter(this._formatter);

  final NumberFormat _formatter;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '', selection: TextSelection.collapsed(offset: 0));
    }

    final value = double.parse(digits) / 100;
    final formatted = _formatter.format(value);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

