import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:relatoriooffline/core/database/app_database.dart';
import 'package:relatoriooffline/services/sync_service.dart';
import 'package:relatoriooffline/widgets/signature_pad.dart';

import '../widgets/app_form_widgets.dart';

class DynamicFormPage extends StatefulWidget {
  final Map<String, dynamic> template;
  final Map<String, dynamic>? initialData;
  final int? localId;
  final bool readOnly;

  const DynamicFormPage({
    super.key,
    required this.template,
    this.initialData,
    this.localId,
    this.readOnly = false,
  });

  @override
  State<DynamicFormPage> createState() => _DynamicFormPageState();
}

class _DynamicFormPageState extends State<DynamicFormPage> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, dynamic> _values = {};
  final Map<String, TextEditingController> _controllers = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _inicializarCampos();
  }

  void _inicializarCampos() {
    final campos = widget.template['campos'] as List<dynamic>;
    final initialData = widget.initialData;

    for (var campo in campos) {
      final chave = campo['chave'];
      final tipo = campo['tipo'];
      final initialValue = initialData?[chave];

      if (tipo == 'TEXTO' || tipo == 'NUMERO' || tipo == 'DATA' || tipo == 'LOCALIZACAO') {
        _controllers[chave] = TextEditingController(text: initialValue?.toString() ?? '');
      } else if (tipo == 'MULTIPLA_SELECAO') {
        if (initialValue is List) {
          _values[chave] = List<String>.from(initialValue);
        } else {
          _values[chave] = <String>[];
        }
      } else if (tipo == 'IMAGEM' || tipo == 'ASSINATURA') {
        if (initialValue is List) {
          _values[chave] = initialValue.map((e) => base64Decode(e.toString())).toList();
        } else {
          _values[chave] = <Uint8List>[];
        }
      } else if (tipo == 'BOOLEANO' || tipo == 'SELECAO') {
        _values[chave] = initialValue;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _capturarLocalizacao(String chave) async {
    if (widget.readOnly) return;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('O serviço de localização está desativado.')),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permissão de localização negada.')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permissão de localização negada permanentemente.')),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Buscando localização...'), duration: Duration(seconds: 2)),
        );
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 30),
          ),
        );
      } catch (e) {
        position = await Geolocator.getLastKnownPosition();
        if (position == null) rethrow;
      }

      setState(() {
        _controllers[chave]!.text = "${position?.latitude},${position?.longitude}";
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao obter localização: $e')),
        );
      }
    }
  }

  Future<void> _selecionarData(String chave) async {
    if (widget.readOnly) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _controllers[chave]!.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _selecionarImagem(String chave, {required bool daCamera}) async {
    if (widget.readOnly) return;
    if (daCamera) {
      final bytes = await ImageHelper.pickAndCompress(ImageSource.camera);
      if (bytes != null) {
        setState(() {
          (_values[chave] as List<Uint8List>).add(bytes);
        });
      }
    } else {
      final novasImagens = await ImageHelper.pickMultiAndCompress();
      if (novasImagens.isNotEmpty) {
        setState(() {
          (_values[chave] as List<Uint8List>).addAll(novasImagens);
        });
      }
    }
  }

  Future<void> _abrirSignaturePad(String chave) async {
    if (widget.readOnly) return;
    await showDialog(
      context: context,
      builder: (context) => SignaturePad(
        onSignatureGenerated: (signatureImage) {
          setState(() {
            (_values[chave] as List<Uint8List>).add(signatureImage);
          });
        },
      ),
    );
  }

  void _abrirMultiplaSelecao(String chave, String label, List<String> opcoes) async {
    if (widget.readOnly) return;
    List<String> selecionados = List<String>.from(_values[chave] ?? []);
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(label),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: opcoes.map((opt) {
                  return CheckboxListTile(
                    title: Text(opt),
                    value: selecionados.contains(opt),
                    onChanged: (val) {
                      setDialogState(() {
                        if (val == true) {
                          selecionados.add(opt);
                        } else {
                          selecionados.remove(opt);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
            ],
          );
        });
      },
    );
    setState(() => _values[chave] = selecionados);
  }

  Future<void> _salvar() async {
    if (_isSaving) return;
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSaving = true);

      Map<String, dynamic> dadosParaSalvar = {};

      final campos = widget.template['campos'] as List<dynamic>;
      for (var campo in campos) {
        final chave = campo['chave'];
        final tipo = campo['tipo'];

        if (tipo == 'IMAGEM' || tipo == 'ASSINATURA') {
          final imagens = _values[chave] as List<Uint8List>;
          dadosParaSalvar[chave] = imagens.map((f) => base64Encode(f)).toList();
        } else if (_controllers.containsKey(chave)) {
          dadosParaSalvar[chave] = _controllers[chave]!.text;
        } else {
          dadosParaSalvar[chave] = _values[chave];
        }
      }

      try {
        final auth = await AppDatabase.instance.obterToken();
        final municipalIdFromAuth = auth?['municipal_id'];
        
        if (!dadosParaSalvar.containsKey('municipalId')) {
          dadosParaSalvar['municipalId'] = municipalIdFromAuth;
        }

        int idLocal;
        if (widget.localId != null) {
          idLocal = widget.localId!;
          await AppDatabase.instance.atualizarFormulario(
            id: idLocal,
            dadosJson: jsonEncode(dadosParaSalvar),
          );
        } else {
          idLocal = await AppDatabase.instance.salvarFormulario(
            tipo: widget.template['nome'],
            templateId: widget.template['id'],
            dadosJson: jsonEncode(dadosParaSalvar),
          );
        }

        bool sincronizado = false;
        try {
          sincronizado = await SyncService.instance.trySendRelatorio(
            dadosParaSalvar,
            localId: idLocal,
            templateId: widget.template['id'],
          );

          if (sincronizado) {
            await AppDatabase.instance.marcarComoSincronizado(idLocal);
          }
        } catch (_) {
        }

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sincronizado 
              ? 'Relatório enviado com sucesso!' 
              : 'Relatório salvo offline para envio posterior.'),
            backgroundColor: sincronizado ? Colors.green : Colors.orange,
          ),
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao salvar: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        } else {
          _isSaving = false;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campos = (widget.template['campos'] as List<dynamic>)
      ..sort((a, b) => (a['ordem'] as int).compareTo(b['ordem'] as int));

    return Scaffold(
      appBar: AppBar(title: Text(widget.template['nome'])),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...campos.map((campo) => _buildField(campo)),
              const SizedBox(height: 32),
              if (!widget.readOnly)
                ElevatedButton(
                  onPressed: _isSaving ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3F7A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'SALVAR RELATÓRIO',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(Map<String, dynamic> campo) {
    final String label = campo['rotulo'] ?? '';
    final String chave = campo['chave'];
    final bool obrigatorio = campo['obrigatorio'] ?? false;
    final String tipo = campo['tipo'];

    switch (tipo) {
      case 'TEXTO':
      case 'NUMERO':
        return AppTextFormField(
          controller: _controllers[chave]!,
          label: label,
          obrigatorio: obrigatorio,
          readOnly: widget.readOnly,
          keyboardType: tipo == 'NUMERO' ? TextInputType.number : TextInputType.text,
        );

      case 'DATA':
        return AppTextFormField(
          controller: _controllers[chave]!,
          label: label,
          obrigatorio: obrigatorio,
          readOnly: true,
          onTap: () => _selecionarData(chave),
          suffixIcon: const Icon(Icons.calendar_today, size: 20),
        );

      case 'BOOLEANO':
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label: label, obrigatorio: obrigatorio),
              DropdownButtonFormField<bool>(
                value: _values[chave],
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: true, child: Text('Sim')),
                  DropdownMenuItem(value: false, child: Text('Não')),
                ],
                onChanged: widget.readOnly ? null : (v) => setState(() => _values[chave] = v),
                validator: (v) => (obrigatorio && v == null) ? 'Obrigatório' : null,
              ),
            ],
          ),
        );

      case 'SELECAO':
        final opcoesRaw = campo['opcoes'];
        final List<String> opcoes = opcoesRaw is List
            ? opcoesRaw.map((e) => e.toString()).toList()
            : (opcoesRaw as String? ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label: label, obrigatorio: obrigatorio),
              DropdownButtonFormField<String>(
                value: _values[chave],
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                items: opcoes.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                onChanged: widget.readOnly ? null : (v) => setState(() => _values[chave] = v),
                validator: (v) => (obrigatorio && v == null) ? 'Obrigatório' : null,
              ),
            ],
          ),
        );

      case 'MULTIPLA_SELECAO':
        final opcoesRaw = campo['opcoes'];
        final List<String> opcoes = opcoesRaw is List
            ? opcoesRaw.map((e) => e.toString()).toList()
            : (opcoesRaw as String? ?? '').split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final selecionados = (_values[chave] as List<String>).join(", ");
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label: label, obrigatorio: obrigatorio),
              InkWell(
                onTap: () => _abrirMultiplaSelecao(chave, label, opcoes),
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    suffixIcon: const Icon(Icons.list, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  isEmpty: selecionados.isEmpty,
                  child: Text(
                    selecionados.isEmpty ? "Toque para selecionar" : selecionados,
                    style: TextStyle(color: selecionados.isEmpty ? Colors.grey.shade600 : Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );

      case 'LOCALIZACAO':
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label: label, obrigatorio: obrigatorio),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _controllers[chave],
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: "Latitude, Longitude",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      validator: (v) => (obrigatorio && (v == null || v.isEmpty)) ? 'Obrigatório' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _capturarLocalizacao(chave),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade700,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: const Icon(Icons.location_on, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      case 'IMAGEM':
        final fotos = _values[chave] as List<Uint8List>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppImagePickerButtons(
                label: label,
                obrigatorio: obrigatorio,
                onCamera: () => _selecionarImagem(chave, daCamera: true),
                onGallery: () => _selecionarImagem(chave, daCamera: false),
              ),
              if (fotos.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fotos
                      .asMap()
                      .entries
                      .map((entry) => Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(entry.value, width: 80, height: 80, fit: BoxFit.cover),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: widget.readOnly 
                                    ? const SizedBox.shrink()
                                    : GestureDetector(
                                        onTap: () => setState(() => fotos.removeAt(entry.key)),
                                        child: Container(
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: const Icon(Icons.close, color: Colors.white, size: 20),
                                        ),
                                      ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
              ],
              if (obrigatorio && fotos.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text('Adicione pelo menos uma foto', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        );

      case 'ASSINATURA':
        final assinaturas = _values[chave] as List<Uint8List>;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel(label: label, obrigatorio: obrigatorio),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...assinaturas.asMap().entries.map((entry) => Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(entry.value, width: 120, height: 80, fit: BoxFit.cover),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: widget.readOnly
                                ? const SizedBox.shrink()
                                : GestureDetector(
                                    onTap: () => setState(() => assinaturas.removeAt(entry.key)),
                                    child: Container(
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                                    ),
                                  ),
                          ),
                        ],
                      )),
                  if (assinaturas.isEmpty)
                    GestureDetector(
                      onTap: () => _abrirSignaturePad(chave),
                      child: Container(
                        width: 120,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit, size: 28, color: Colors.grey.shade600),
                            const SizedBox(height: 4),
                            Text('Assinar', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (obrigatorio && assinaturas.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8, left: 4),
                  child: Text('Adicione uma assinatura', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
            ],
          ),
        );

       default:
        return const SizedBox.shrink();
    }
  }
}
