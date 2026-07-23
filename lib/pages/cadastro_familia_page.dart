import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/sync_service.dart';
import 'package:relatoriooffline/widgets/app_form_widgets.dart';

class CadastroFamiliaPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final int? localId;
  final bool readOnly;

  const CadastroFamiliaPage({
    super.key,
    this.initialData,
    this.localId,
    this.readOnly = false,
  });

  @override
  State<CadastroFamiliaPage> createState() => _CadastroFamiliaPageState();
}

class _CadastroFamiliaPageState extends State<CadastroFamiliaPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  final Map<String, FocusNode> _focusNodes = {
    'nomeResponsavel': FocusNode(),
    'cpfResponsavel': FocusNode(),
    'telefoneResponsavel': FocusNode(),
    'enderecoResponsavel': FocusNode(),
    'numeroFamilias': FocusNode(),
    'numeroPessoas': FocusNode(),
  };

  final Map<String, TextEditingController> _controllers = {
    'nomeResponsavel': TextEditingController(),
    'cpfResponsavel': TextEditingController(),
    'telefoneResponsavel': TextEditingController(),
    'enderecoResponsavel': TextEditingController(),
    'numeroFamilias': TextEditingController(text: '1'),
    'numeroPessoas': TextEditingController(),
    'quantidadeAguaPotavel5L': TextEditingController(),
    'quantidadeCestaBasicaAlimentos': TextEditingController(),
    'quantidadeKitHigienePessoal': TextEditingController(),
    'quantidadeKitLimpezaDomestica': TextEditingController(),
    'quantidadeColchaoSolteiro': TextEditingController(),
    'quantidadeColchaoCasal': TextEditingController(),
    'quantidadeKitAcomodacaoSolteiro': TextEditingController(),
    'quantidadeKitAcomodacaoCasal': TextEditingController(),
    'quantidadeTelhaFibrocimento4mm': TextEditingController(),
    'quantidadeCumeeiraTelhaFibrocimento4mm': TextEditingController(),
    'quantidadeTelhaFibrocimento6mm': TextEditingController(),
    'quantidadeCumeeiraTelhaFibrocimento6mm': TextEditingController(),
  };

  double? _latitude;
  double? _longitude;
  double? _precisaoGps;
  bool _moradiaAlternativa = false;
  final List<Uint8List> _fotosResidencia = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _loadInitialData();
    } else {
      _capturarLocalizacao();
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes.values) {
      node.dispose();
    }
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _controllers['nomeResponsavel']!.text = data['nomeResponsavel'] ?? '';
    _controllers['cpfResponsavel']!.text = data['cpfResponsavel'] ?? '';
    _controllers['telefoneResponsavel']!.text = data['telefoneResponsavel'] ?? '';
    _controllers['enderecoResponsavel']!.text = data['enderecoResponsavel'] ?? '';
    _controllers['numeroFamilias']!.text = data['numeroFamilias']?.toString() ?? '1';
    _controllers['numeroPessoas']!.text = data['numeroPessoas']?.toString() ?? '';
    _moradiaAlternativa = data['moradiaAlternativa'] == true;
    
    _controllers['quantidadeAguaPotavel5L']!.text = data['quantidadeAguaPotavel5L']?.toString() ?? '';
    _controllers['quantidadeCestaBasicaAlimentos']!.text = data['quantidadeCestaBasicaAlimentos']?.toString() ?? '';
    _controllers['quantidadeKitHigienePessoal']!.text = data['quantidadeKitHigienePessoal']?.toString() ?? '';
    _controllers['quantidadeKitLimpezaDomestica']!.text = data['quantidadeKitLimpezaDomestica']?.toString() ?? '';
    _controllers['quantidadeColchaoSolteiro']!.text = data['quantidadeColchaoSolteiro']?.toString() ?? '';
    _controllers['quantidadeColchaoCasal']!.text = data['quantidadeColchaoCasal']?.toString() ?? '';
    _controllers['quantidadeKitAcomodacaoSolteiro']!.text = data['quantidadeKitAcomodacaoSolteiro']?.toString() ?? '';
    _controllers['quantidadeKitAcomodacaoCasal']!.text = data['quantidadeKitAcomodacaoCasal']?.toString() ?? '';
    _controllers['quantidadeTelhaFibrocimento4mm']!.text = data['quantidadeTelhaFibrocimento4mm']?.toString() ?? '';
    _controllers['quantidadeCumeeiraTelhaFibrocimento4mm']!.text = data['quantidadeCumeeiraTelhaFibrocimento4mm']?.toString() ?? '';
    _controllers['quantidadeTelhaFibrocimento6mm']!.text = data['quantidadeTelhaFibrocimento6mm']?.toString() ?? '';
    _controllers['quantidadeCumeeiraTelhaFibrocimento6mm']!.text = data['quantidadeCumeeiraTelhaFibrocimento6mm']?.toString() ?? '';

    _latitude = data['latitude'];
    _longitude = data['longitude'];
    _precisaoGps = data['precisaoGps'];

    if (data['fotosResidencia'] != null) {
      for (var f in data['fotosResidencia']) {
        _fotosResidencia.add(base64Decode(f));
      }
    }
  }

  Future<void> _capturarLocalizacao() async {
    setState(() => _isLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Serviço de localização desativado';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Permissão de localização negada';
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _precisaoGps = position.accuracy;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Localização capturada com sucesso!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao capturar localização: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar localização: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selecionarFoto(ImageSource source) async {
    final int limiteRestante = 6 - _fotosResidencia.length;
    if (limiteRestante <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite máximo de 6 fotos atingido.')),
      );
      return;
    }

    if (source == ImageSource.gallery) {
      setState(() => _isLoading = true);
      try {
        final novasFotos = await ImageHelper.pickMultiAndCompress(limit: limiteRestante);
        if (novasFotos.isNotEmpty) {
          setState(() {
            _fotosResidencia.addAll(novasFotos);
          });
        }
      } finally {
        setState(() => _isLoading = false);
      }
    } else {
      final foto = await ImageHelper.pickAndCompress(source);
      if (foto != null) {
        setState(() {
          _fotosResidencia.add(foto);
        });
      }
    }
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, verifique os campos obrigatórios.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final auth = await AppDatabase.instance.obterToken();
      
      final Map<String, dynamic> payload = {
        'nomeResponsavel': _controllers['nomeResponsavel']!.text,
        'cpfResponsavel': _controllers['cpfResponsavel']!.text,
        'telefoneResponsavel': _controllers['telefoneResponsavel']!.text,
        'enderecoResponsavel': _controllers['enderecoResponsavel']!.text,
        'numeroFamilias': int.tryParse(_controllers['numeroFamilias']!.text) ?? 1,
        'numeroPessoas': int.tryParse(_controllers['numeroPessoas']!.text) ?? 0,
        'moradiaAlternativa': _moradiaAlternativa,
        'latitude': _latitude,
        'longitude': _longitude,
        'precisaoGps': _precisaoGps,
        'municipalId': auth?['municipal_id'],
        'fotosResidencia': _fotosResidencia.map((e) => base64Encode(e)).toList(),
      };

      // Adicionar quantidades apenas se preenchidas
      _controllers.forEach((key, controller) {
        if (key.startsWith('quantidade')) {
          final value = int.tryParse(controller.text);
          if (value != null) {
            payload[key] = value;
          }
        }
      });

      int id;
      if (widget.localId != null) {
        id = widget.localId!;
        await AppDatabase.instance.atualizarFormulario(
          id: id,
          dadosJson: jsonEncode(payload),
        );
      } else {
        id = await AppDatabase.instance.salvarFormulario(
          tipo: 'familia_atingida',
          dadosJson: jsonEncode(payload),
        );
      }

      // Tenta sincronizar imediatamente
      final sucesso = await SyncService.instance.trySendFamiliaAtingida(payload, localId: id);

      if (sucesso) {
        await AppDatabase.instance.marcarComoSincronizado(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sincronizado com sucesso!')),
          );
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salvo offline. Será sincronizado quando houver internet.')),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro Família Atingida'),
      ),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppFormSection(
                title: 'Dados do Responsável',
                children: [
                  AppTextFormField(
                    controller: _controllers['nomeResponsavel']!,
                    focusNode: _focusNodes['nomeResponsavel'],
                    label: 'Nome do Responsável',
                    obrigatorio: true,
                    textCapitalization: TextCapitalization.words,
                  ),
                  AppTextFormField(
                    controller: _controllers['cpfResponsavel']!,
                    focusNode: _focusNodes['cpfResponsavel'],
                    label: 'CPF do Responsável',
                    obrigatorio: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _CpfInputFormatter(),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length < 14) {
                        return 'CPF incompleto';
                      }
                      return null;
                    },
                  ),
                  AppTextFormField(
                    controller: _controllers['telefoneResponsavel']!,
                    focusNode: _focusNodes['telefoneResponsavel'],
                    label: 'Telefone',
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _TelefoneInputFormatter(),
                    ],
                    validator: (value) {
                      if (value != null && value.isNotEmpty && value.length < 14) {
                        return 'Telefone incompleto';
                      }
                      return null;
                    },
                  ),
                  AppTextFormField(
                    controller: _controllers['enderecoResponsavel']!,
                    focusNode: _focusNodes['enderecoResponsavel'],
                    label: 'Endereço',
                    obrigatorio: true,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              AppFormSection(
                title: 'Dados da Família',
                children: [
                  const FieldLabel(label: 'Possui moradia alternativa?'),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          label: Text('Sim'),
                          icon: Icon(Icons.check_circle_outline),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          label: Text('Não'),
                          icon: Icon(Icons.cancel_outlined),
                        ),
                      ],
                      selected: {_moradiaAlternativa},
                      onSelectionChanged: widget.readOnly
                          ? null
                          : (selection) =>
                              setState(() => _moradiaAlternativa = selection.first),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextFormField(
                    controller: _controllers['numeroFamilias']!,
                    focusNode: _focusNodes['numeroFamilias'],
                    label: 'Número de Famílias',
                    obrigatorio: true,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      if (n == null || n <= 0) return 'Mínimo 1';
                      return null;
                    },
                  ),
                  AppTextFormField(
                    controller: _controllers['numeroPessoas']!,
                    focusNode: _focusNodes['numeroPessoas'],
                    label: 'Número de Pessoas',
                    obrigatorio: true,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      if (n == null || n <= 0) return 'Mínimo 1';
                      return null;
                    },
                  ),
                ],
              ),
              AppFormSection(
                title: 'Necessidades e Itens',
                children: [
                  _buildQuantidadeField('quantidadeAguaPotavel5L', 'Água Potável 5L'),
                  _buildQuantidadeField('quantidadeCestaBasicaAlimentos', 'Cesta Básica'),
                  _buildQuantidadeField('quantidadeKitHigienePessoal', 'Kit Higiene Pessoal'),
                  _buildQuantidadeField('quantidadeKitLimpezaDomestica', 'Kit Limpeza Doméstica'),
                  _buildQuantidadeField('quantidadeColchaoSolteiro', 'Colhão Solteiro'),
                  _buildQuantidadeField('quantidadeColchaoCasal', 'Colchão Casal'),
                  _buildQuantidadeField('quantidadeKitAcomodacaoSolteiro', 'Kit Acomodação Solteiro'),
                  _buildQuantidadeField('quantidadeKitAcomodacaoCasal', 'Kit Acomodação Casal'),
                  _buildQuantidadeField('quantidadeTelhaFibrocimento4mm', 'Telha Fibrocimento 4mm'),
                  _buildQuantidadeField('quantidadeCumeeiraTelhaFibrocimento4mm', 'Cumeeira 4mm'),
                  _buildQuantidadeField('quantidadeTelhaFibrocimento6mm', 'Telha Fibrocimento 6mm'),
                  _buildQuantidadeField('quantidadeCumeeiraTelhaFibrocimento6mm', 'Cumeeira 6mm'),
                ],
              ),
              AppFormSection(
                title: 'Localização e Fotos',
                children: [
                  if (_latitude != null) ...[
                    Text('Latitude: $_latitude',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Longitude: $_longitude',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Precisão: ${_precisaoGps?.toStringAsFixed(2)}m',
                        style: const TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                  ],
                  if (!widget.readOnly) ...[
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _capturarLocalizacao,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Coletar Localização GPS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _selecionarFoto(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Câmera'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _selecionarFoto(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Galeria'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _fotosResidencia.asMap().entries.map((entry) {
                      return Stack(
                        children: [
                          Image.memory(entry.value,
                              width: 100, height: 100, fit: BoxFit.cover),
                          if (!widget.readOnly)
                            Positioned(
                              right: 0,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _fotosResidencia.removeAt(entry.key);
                                  });
                                },
                              ),
                            ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!widget.readOnly)
                ElevatedButton(
                  onPressed: _isLoading ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: const Color(0xFF3A3F7A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SALVAR RELATÓRIO',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantidadeField(String key, String label) {
    return AppTextFormField(
      controller: _controllers[key]!,
      label: label,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    );
  }
}

class _CpfInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);
    
    var formatted = '';
    for (var i = 0; i < text.length; i++) {
      formatted += text[i];
      if (i == 2 || i == 5) {
        if (i != text.length - 1) formatted += '.';
      } else if (i == 8) {
        if (i != text.length - 1) formatted += '-';
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TelefoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 11) text = text.substring(0, 11);
    
    var formatted = '';
    if (text.isNotEmpty) {
      formatted = '(';
      for (var i = 0; i < text.length; i++) {
        formatted += text[i];
        if (i == 1) {
          formatted += ') ';
        } else if (i == 6 && text.length == 11) {
          formatted += '-';
        } else if (i == 5 && text.length < 11) {
          formatted += '-';
        }
      }
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
