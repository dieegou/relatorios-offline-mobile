import 'dart:convert';

class EntregaIah {
  final int id;
  final String nomeResponsavel;
  final String? cpfResponsavel;
  final String? telefoneResponsavel;
  final String enderecoResponsavel;
  final double? latitudeColeta;
  final double? longitudeColeta;
  final double? precisaoGpsColeta;
  final Desastre desastre;
  final ItensAssistencia itensAssistencia;
  final String statusEntrega;
  final String statusEntregaDescricao;
  final UsuarioEntrega? usuarioEntrega;
  final DateTime? dataEntrega;

  EntregaIah({
    required this.id,
    required this.nomeResponsavel,
    this.cpfResponsavel,
    this.telefoneResponsavel,
    required this.enderecoResponsavel,
    this.latitudeColeta,
    this.longitudeColeta,
    this.precisaoGpsColeta,
    required this.desastre,
    required this.itensAssistencia,
    required this.statusEntrega,
    required this.statusEntregaDescricao,
    this.usuarioEntrega,
    this.dataEntrega,
  });

  factory EntregaIah.fromJson(Map<String, dynamic> json) {
    return EntregaIah(
      id: json['id'],
      nomeResponsavel: json['nomeResponsavel'],
      cpfResponsavel: json['cpfResponsavel'],
      telefoneResponsavel: json['telefoneResponsavel'],
      enderecoResponsavel: json['enderecoResponsavel'],
      latitudeColeta: json['latitudeColeta']?.toDouble(),
      longitudeColeta: json['longitudeColeta']?.toDouble(),
      precisaoGpsColeta: json['precisaoGpsColeta']?.toDouble(),
      desastre: Desastre.fromJson(json['desastre']),
      itensAssistencia: ItensAssistencia.fromJson(json['itensAssistencia']),
      statusEntrega: json['statusEntrega'],
      statusEntregaDescricao: json['statusEntregaDescricao'],
      usuarioEntrega: json['usuarioEntrega'] != null
          ? UsuarioEntrega.fromJson(json['usuarioEntrega'])
          : null,
      dataEntrega: json['dataEntrega'] != null
          ? DateTime.parse(json['dataEntrega'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nomeResponsavel': nomeResponsavel,
      'cpfResponsavel': cpfResponsavel,
      'telefoneResponsavel': telefoneResponsavel,
      'enderecoResponsavel': enderecoResponsavel,
      'latitudeColeta': latitudeColeta,
      'longitudeColeta': longitudeColeta,
      'precisaoGpsColeta': precisaoGpsColeta,
      'desastre': desastre.toJson(),
      'itensAssistencia': itensAssistencia.toJson(),
      'statusEntrega': statusEntrega,
      'statusEntregaDescricao': statusEntregaDescricao,
      'usuarioEntrega': usuarioEntrega?.toJson(),
      'dataEntrega': dataEntrega?.toIso8601String(),
    };
  }
}

class Desastre {
  final int id;
  final String cobrade;
  final String descricao;
  final DateTime dataDesastre;

  Desastre({
    required this.id,
    required this.cobrade,
    required this.descricao,
    required this.dataDesastre,
  });

  factory Desastre.fromJson(Map<String, dynamic> json) {
    return Desastre(
      id: json['id'],
      cobrade: json['cobrade'],
      descricao: json['descricao'],
      dataDesastre: DateTime.parse(json['dataDesastre']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'cobrade': cobrade,
      'descricao': descricao,
      'dataDesastre': dataDesastre.toIso8601String(),
    };
  }
}

class ItensAssistencia {
  final int? quantidadeAguaPotavel5L;
  final int? quantidadeCestaBasicaAlimentos;
  final int? quantidadeKitHigienePessoal;
  final int? quantidadeKitLimpezaDomestica;
  final int? quantidadeColchaoSolteiro;
  final int? quantidadeColchaoCasal;
  final int? quantidadeKitAcomodacaoSolteiro;
  final int? quantidadeKitAcomodacaoCasal;
  final int? quantidadeTelhaFibrocimento4mm;
  final int? quantidadeCumeeiraTelhaFibrocimento4mm;
  final int? quantidadeTelhaFibrocimento6mm;
  final int? quantidadeCumeeiraTelhaFibrocimento6mm;

  ItensAssistencia({
    this.quantidadeAguaPotavel5L,
    this.quantidadeCestaBasicaAlimentos,
    this.quantidadeKitHigienePessoal,
    this.quantidadeKitLimpezaDomestica,
    this.quantidadeColchaoSolteiro,
    this.quantidadeColchaoCasal,
    this.quantidadeKitAcomodacaoSolteiro,
    this.quantidadeKitAcomodacaoCasal,
    this.quantidadeTelhaFibrocimento4mm,
    this.quantidadeCumeeiraTelhaFibrocimento4mm,
    this.quantidadeTelhaFibrocimento6mm,
    this.quantidadeCumeeiraTelhaFibrocimento6mm,
  });

  factory ItensAssistencia.fromJson(Map<String, dynamic> json) {
    return ItensAssistencia(
      quantidadeAguaPotavel5L: json['quantidadeAguaPotavel5L'],
      quantidadeCestaBasicaAlimentos: json['quantidadeCestaBasicaAlimentos'],
      quantidadeKitHigienePessoal: json['quantidadeKitHigienePessoal'],
      quantidadeKitLimpezaDomestica: json['quantidadeKitLimpezaDomestica'],
      quantidadeColchaoSolteiro: json['quantidadeColchaoSolteiro'],
      quantidadeColchaoCasal: json['quantidadeColchaoCasal'],
      quantidadeKitAcomodacaoSolteiro: json['quantidadeKitAcomodacaoSolteiro'],
      quantidadeKitAcomodacaoCasal: json['quantidadeKitAcomodacaoCasal'],
      quantidadeTelhaFibrocimento4mm: json['quantidadeTelhaFibrocimento4mm'],
      quantidadeCumeeiraTelhaFibrocimento4mm: json['quantidadeCumeeiraTelhaFibrocimento4mm'],
      quantidadeTelhaFibrocimento6mm: json['quantidadeTelhaFibrocimento6mm'],
      quantidadeCumeeiraTelhaFibrocimento6mm: json['quantidadeCumeeiraTelhaFibrocimento6mm'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'quantidadeAguaPotavel5L': quantidadeAguaPotavel5L,
      'quantidadeCestaBasicaAlimentos': quantidadeCestaBasicaAlimentos,
      'quantidadeKitHigienePessoal': quantidadeKitHigienePessoal,
      'quantidadeKitLimpezaDomestica': quantidadeKitLimpezaDomestica,
      'quantidadeColchaoSolteiro': quantidadeColchaoSolteiro,
      'quantidadeColchaoCasal': quantidadeColchaoCasal,
      'quantidadeKitAcomodacaoSolteiro': quantidadeKitAcomodacaoSolteiro,
      'quantidadeKitAcomodacaoCasal': quantidadeKitAcomodacaoCasal,
      'quantidadeTelhaFibrocimento4mm': quantidadeTelhaFibrocimento4mm,
      'quantidadeCumeeiraTelhaFibrocimento4mm': quantidadeCumeeiraTelhaFibrocimento4mm,
      'quantidadeTelhaFibrocimento6mm': quantidadeTelhaFibrocimento6mm,
      'quantidadeCumeeiraTelhaFibrocimento6mm': quantidadeCumeeiraTelhaFibrocimento6mm,
    };
  }

  Map<String, int> getAvailableItens() {
    final map = <String, int>{};
    if ((quantidadeAguaPotavel5L ?? 0) > 0) map['quantidadeAguaPotavel5L'] = quantidadeAguaPotavel5L!;
    if ((quantidadeCestaBasicaAlimentos ?? 0) > 0) map['quantidadeCestaBasicaAlimentos'] = quantidadeCestaBasicaAlimentos!;
    if ((quantidadeKitHigienePessoal ?? 0) > 0) map['quantidadeKitHigienePessoal'] = quantidadeKitHigienePessoal!;
    if ((quantidadeKitLimpezaDomestica ?? 0) > 0) map['quantidadeKitLimpezaDomestica'] = quantidadeKitLimpezaDomestica!;
    if ((quantidadeColchaoSolteiro ?? 0) > 0) map['quantidadeColchaoSolteiro'] = quantidadeColchaoSolteiro!;
    if ((quantidadeColchaoCasal ?? 0) > 0) map['quantidadeColchaoCasal'] = quantidadeColchaoCasal!;
    if ((quantidadeKitAcomodacaoSolteiro ?? 0) > 0) map['quantidadeKitAcomodacaoSolteiro'] = quantidadeKitAcomodacaoSolteiro!;
    if ((quantidadeKitAcomodacaoCasal ?? 0) > 0) map['quantidadeKitAcomodacaoCasal'] = quantidadeKitAcomodacaoCasal!;
    if ((quantidadeTelhaFibrocimento4mm ?? 0) > 0) map['quantidadeTelhaFibrocimento4mm'] = quantidadeTelhaFibrocimento4mm!;
    if ((quantidadeCumeeiraTelhaFibrocimento4mm ?? 0) > 0) map['quantidadeCumeeiraTelhaFibrocimento4mm'] = quantidadeCumeeiraTelhaFibrocimento4mm!;
    if ((quantidadeTelhaFibrocimento6mm ?? 0) > 0) map['quantidadeTelhaFibrocimento6mm'] = quantidadeTelhaFibrocimento6mm!;
    if ((quantidadeCumeeiraTelhaFibrocimento6mm ?? 0) > 0) map['quantidadeCumeeiraTelhaFibrocimento6mm'] = quantidadeCumeeiraTelhaFibrocimento6mm!;
    return map;
  }

  static String getLabel(String key) {
    switch (key) {
      case 'quantidadeAguaPotavel5L': return 'Água Potável 5L';
      case 'quantidadeCestaBasicaAlimentos': return 'Cesta Básica';
      case 'quantidadeKitHigienePessoal': return 'Kit Higiene Pessoal';
      case 'quantidadeKitLimpezaDomestica': return 'Kit Limpeza Doméstica';
      case 'quantidadeColchaoSolteiro': return 'Colchão Solteiro';
      case 'quantidadeColchaoCasal': return 'Colchão Casal';
      case 'quantidadeKitAcomodacaoSolteiro': return 'Kit Acomodação Solteiro';
      case 'quantidadeKitAcomodacaoCasal': return 'Kit Acomodação Casal';
      case 'quantidadeTelhaFibrocimento4mm': return 'Telha Fibrocimento 4mm';
      case 'quantidadeCumeeiraTelhaFibrocimento4mm': return 'Cumeeira Telha 4mm';
      case 'quantidadeTelhaFibrocimento6mm': return 'Telha Fibrocimento 6mm';
      case 'quantidadeCumeeiraTelhaFibrocimento6mm': return 'Cumeeira Telha 6mm';
      default: return key;
    }
  }
}

class UsuarioEntrega {
  final int id;
  final String nome;
  final String username;

  UsuarioEntrega({
    required this.id,
    required this.nome,
    required this.username,
  });

  factory UsuarioEntrega.fromJson(Map<String, dynamic> json) {
    return UsuarioEntrega(
      id: json['id'],
      nome: json['nome'],
      username: json['username'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'username': username,
    };
  }
}
