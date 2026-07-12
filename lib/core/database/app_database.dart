import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('defesa_civil.db');
    return _database!;
  }


  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 8,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );

    await _runMaintenance(db);
    return db;
  }

  Future<void> _runMaintenance(Database db) async {
    // Mantém os dados originais para permitir consulta futura
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try {
        final result = await db.rawQuery('PRAGMA table_info(auth)');
        final columnExists = result.any((column) => column['name'] == 'nome');
        if (!columnExists) {
          await db.execute('ALTER TABLE auth ADD COLUMN nome TEXT');
        }
      } catch (_) {}
    }
    if (oldVersion < 4) {
      final authInfo = await db.rawQuery('PRAGMA table_info(auth)');
      if (!authInfo.any((c) => c['name'] == 'municipal_id')) {
        await db.execute('ALTER TABLE auth ADD COLUMN municipal_id INTEGER');
      }
      if (!authInfo.any((c) => c['name'] == 'municipal_nome')) {
        await db.execute('ALTER TABLE auth ADD COLUMN municipal_nome TEXT');
      }

      final formInfo = await db.rawQuery('PRAGMA table_info(formularios)');
      if (!formInfo.any((c) => c['name'] == 'template_id')) {
        await db.execute('ALTER TABLE formularios ADD COLUMN template_id INTEGER');
      }
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS templates (
          id INTEGER PRIMARY KEY,
          nome TEXT NOT NULL,
          descricao TEXT,
          dados_json TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nivel TEXT NOT NULL,
          mensagem TEXT NOT NULL,
          tag TEXT,
          extra TEXT,
          data_hora TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 6) {
      final authInfo = await db.rawQuery('PRAGMA table_info(auth)');
      if (!authInfo.any((c) => c['name'] == 'habilita_relatorios_dinamicos')) {
        await db.execute(
            'ALTER TABLE auth ADD COLUMN habilita_relatorios_dinamicos INTEGER DEFAULT 0');
      }
    }
    if (oldVersion < 7) {
      final authInfo = await db.rawQuery('PRAGMA table_info(auth)');
      if (!authInfo.any((c) => c['name'] == 'regional_id')) {
        await db.execute('ALTER TABLE auth ADD COLUMN regional_id INTEGER');
      }
      if (!authInfo.any((c) => c['name'] == 'regional_nome')) {
        await db.execute('ALTER TABLE auth ADD COLUMN regional_nome TEXT');
      }
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS entregas_iah (
          id INTEGER PRIMARY KEY,
          desastre_id INTEGER,
          dados_json TEXT NOT NULL
        )
      ''');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE auth (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        token TEXT NOT NULL,
        nome TEXT,
        municipal_id INTEGER,
        municipal_nome TEXT,
        regional_id INTEGER,
        regional_nome TEXT,
        habilita_relatorios_dinamicos INTEGER DEFAULT 0,
        data_login TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS templates (
        id INTEGER PRIMARY KEY,
        nome TEXT NOT NULL,
        descricao TEXT,
        dados_json TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nivel TEXT NOT NULL,
        mensagem TEXT NOT NULL,
        tag TEXT,
        extra TEXT,
        data_hora TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE formularios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER,
        tipo TEXT NOT NULL,
        dados_json TEXT NOT NULL,
        sincronizado INTEGER NOT NULL DEFAULT 0,
        data_criacao TEXT NOT NULL,
        FOREIGN KEY (template_id) REFERENCES templates (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS entregas_iah (
        id INTEGER PRIMARY KEY,
        desastre_id INTEGER,
        dados_json TEXT NOT NULL
      )
    ''');
  }

  Future<void> salvarTemplates(List<dynamic> templates) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('templates');
      for (var template in templates) {
        await txn.insert('templates', {
          'id': template['id'],
          'nome': template['nome'],
          'descricao': template['descricao'],
          'dados_json': jsonEncode(template),
        });
      }
    });
  }

  Future<List<Map<String, dynamic>>> obterTemplates() async {
    final db = await database;
    return await db.query('templates');
  }

  Future<void> salvarToken(
    String username,
    String token, {
    String? nome,
    int? municipalId,
    String? municipalNome,
    int? regionalId,
    String? regionalNome,
    bool? habilitaRelatoriosDinamicos,
  }) async {
    final db = await database;
    await db.delete('auth');

    await db.insert('auth', {
      'username': username,
      'token': token,
      'nome': nome,
      'municipal_id': municipalId,
      'municipal_nome': municipalNome,
      'regional_id': regionalId,
      'regional_nome': regionalNome,
      'habilita_relatorios_dinamicos': (habilitaRelatoriosDinamicos ?? false) ? 1 : 0,
      'data_login': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> obterToken() async {
    final db = await database;
    final result = await db.query('auth', limit: 1);
    if (result.isNotEmpty) {
      final data = Map<String, dynamic>.from(result.first);
      data['habilitaRelatoriosDinamicos'] = data['habilita_relatorios_dinamicos'] == 1;
      return data;
    }
    return null;
  }

  Future<void> atualizarConfigRegional({
    required int? regionalId,
    required String? regionalNome,
    required bool habilitaDinamicos,
  }) async {
    final db = await database;
    await db.update(
      'auth',
      {
        'regional_id': regionalId,
        'regional_nome': regionalNome,
        'habilita_relatorios_dinamicos': habilitaDinamicos ? 1 : 0,
      },
    );
  }

  Future<void> limparToken() async {
    final db = await database;
    await db.delete('auth');
  }

  Future<int> salvarFormulario({
    required String tipo,
    required String dadosJson,
    int? templateId,
  }) async {
    final db = await database;
    return await db.insert('formularios', {
      'tipo': tipo,
      'template_id': templateId,
      'dados_json': dadosJson,
      'sincronizado': 0,
      'data_criacao': DateTime.now().toIso8601String(),
    });
  }

  Future<void> atualizarFormulario({
    required int id,
    required String dadosJson,
  }) async {
    final db = await database;
    await db.update(
      'formularios',
      {
        'dados_json': dadosJson,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletarFormulario(int id) async {
    final db = await database;
    await db.delete(
      'formularios',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, dynamic>?> obterFormularioPorId(int id) async {
    final db = await database;
    final result = await db.query(
      'formularios',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> obterFormularios({
    bool? sincronizado,
    bool incluirDadosJson = false,
  }) async {
    final db = await database;
    final columns = incluirDadosJson
        ? null
        : <String>['id', 'tipo', 'template_id', 'sincronizado', 'data_criacao'];

    if (sincronizado != null) {
      return await db.query(
        'formularios',
        columns: columns,
        where: 'sincronizado = ?',
        whereArgs: [sincronizado ? 1 : 0],
        orderBy: 'data_criacao DESC',
      );
    }
    return await db.query(
      'formularios',
      columns: columns,
      orderBy: 'data_criacao DESC',
    );
  }

  Future<void> marcarComoSincronizado(int id) async {
    final db = await database;
    await db.update(
      'formularios',
      {
        'sincronizado': 1,
        // Mantemos o dados_json original para visualização
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> limparEnviados() async {
    final db = await database;
    await db.delete(
      'formularios',
      where: 'sincronizado = ?',
      whereArgs: [1],
    );
  }

  Future<void> salvarEntregasIah(List<dynamic> entregas) async {
    final db = await database;
    final localRows = await db.query('entregas_iah');
    final localById = <int, Map<String, dynamic>>{
      for (final row in localRows)
        row['id'] as int: jsonDecode(row['dados_json'] as String) as Map<String, dynamic>,
    };

    final familiaIdsComReciboPendente = await _obterFamiliasComReciboPendente();

    await db.transaction((txn) async {
      await txn.delete('entregas_iah');
      for (var entrega in entregas) {
        final id = entrega['id'] as int;
        Map<String, dynamic> dados = Map<String, dynamic>.from(entrega);

        final local = localById[id];
        if (local != null) {
          final localStatus = local['statusEntrega'] as String?;
          final serverStatus = entrega['statusEntrega'] as String?;
          if (familiaIdsComReciboPendente.contains(id) ||
              (localStatus != 'LIBERADA' && serverStatus == 'LIBERADA')) {
            dados = local;
          }
        }

        await txn.insert('entregas_iah', {
          'id': id,
          'desastre_id': dados['desastre']['id'],
          'dados_json': jsonEncode(dados),
        });
      }
    });
  }

  Future<Set<int>> _obterFamiliasComReciboPendente() async {
    final pendentes = await obterFormularios(
      sincronizado: false,
      incluirDadosJson: true,
    );
    final ids = <int>{};
    for (final form in pendentes) {
      if (form['tipo'] == 'recibo_iah') {
        final dados = jsonDecode(form['dados_json'] as String) as Map<String, dynamic>;
        final familiaId = dados['familiaAtingidaId'];
        if (familiaId is int) ids.add(familiaId);
      }
    }
    return ids;
  }

  Future<Map<String, dynamic>?> obterReciboIahPendentePorFamilia(int familiaAtingidaId) async {
    final pendentes = await obterFormularios(
      sincronizado: false,
      incluirDadosJson: true,
    );
    for (final form in pendentes) {
      if (form['tipo'] != 'recibo_iah') continue;
      final dados = jsonDecode(form['dados_json'] as String) as Map<String, dynamic>;
      if (dados['familiaAtingidaId'] == familiaAtingidaId) {
        return form;
      }
    }
    return null;
  }

  Future<int> salvarOuAtualizarReciboIahPendente({
    required int familiaAtingidaId,
    required String dadosJson,
  }) async {
    final existente = await obterReciboIahPendentePorFamilia(familiaAtingidaId);
    if (existente != null) {
      final id = existente['id'] as int;
      await atualizarFormulario(id: id, dadosJson: dadosJson);
      return id;
    }
    return await salvarFormulario(tipo: 'recibo_iah', dadosJson: dadosJson);
  }

  Future<List<Map<String, dynamic>>> obterEntregasIah() async {
    final db = await database;
    return await db.query('entregas_iah', orderBy: 'desastre_id ASC, id ASC');
  }

  Future<List<Map<String, dynamic>>> obterEntregasIahPorDesastre(int desastreId) async {
    final db = await database;
    return await db.query(
      'entregas_iah',
      where: 'desastre_id = ?',
      whereArgs: [desastreId],
      orderBy: 'id ASC',
    );
  }

  Future<void> marcarEntregaComoEntregue(int id, Map<String, dynamic>? auth) async {
    final db = await database;
    final rows = await db.query('entregas_iah', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;

    final dados = Map<String, dynamic>.from(
      jsonDecode(rows.first['dados_json'] as String) as Map<String, dynamic>,
    );
    dados['statusEntrega'] = 'ENTREGUE';
    dados['statusEntregaDescricao'] = 'Entregue';
    dados['dataEntrega'] = DateTime.now().toIso8601String();
    if (auth != null) {
      dados['usuarioEntrega'] = {
        'id': 0,
        'nome': auth['nome'] ?? auth['username'] ?? 'Agente',
        'username': auth['username'] ?? '',
      };
    }

    await db.update(
      'entregas_iah',
      {'dados_json': jsonEncode(dados)},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> salvarLog({
    required String nivel,
    required String mensagem,
    String? tag,
    String? extra,
  }) async {
    final db = await database;
    await db.insert('logs', {
      'nivel': nivel,
      'mensagem': mensagem,
      'tag': tag,
      'extra': extra,
      'data_hora': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> obterLogs({int limit = 200}) async {
    final db = await database;
    return await db.query(
      'logs',
      orderBy: 'data_hora DESC',
      limit: limit,
    );
  }

  Future<void> limparLogs() async {
    final db = await database;
    await db.delete('logs');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  Future<void> deleteDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'defesa_civil.db');
    _database = null;
    await databaseFactory.deleteDatabase(path);
  }
}