import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io'; // For platform detection

import 'models/site.dart';
import 'models/borehole.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'borehole_data.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  void _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        location TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE boreholes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        siteId INTEGER,
        boreholeName TEXT,
        xyPosition TEXT,
        mAOD REAL,
        FOREIGN KEY(siteId) REFERENCES sites(id) ON DELETE CASCADE
      )
    ''');
  }

  // Site Methods
  Future<int> insertSite(Site site) async {
    final db = await database;
    return await db.insert('sites', site.toMap());
  }

  Future<List<Site>> getAllSites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('sites');
    return List.generate(maps.length, (i) {
      return Site.fromMap(maps[i]);
    });
  }

  // Borehole Methods
  Future<int> insertBorehole(Borehole borehole) async {
    final db = await database;
    return await db.insert('boreholes', borehole.toMap());
  }

  // Delete borehole
  Future<void> deleteBorehole(int id) async {
    final db = await database;
    await db.delete(
      'boreholes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Update borehole
  Future<void> updateBorehole(Borehole borehole) async {
    final db = await database;
    await db.update(
      'boreholes',
      borehole.toMap(),
      where: 'id = ?',
      whereArgs: [borehole.id],
    );
  }

  Future<List<Borehole>> getBoreholesForSite(int siteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'boreholes',
      where: 'siteId = ?',
      whereArgs: [siteId],
    );
    return List.generate(maps.length, (i) {
      return Borehole.fromMap(maps[i]);
    });
  }

  Future<List<Borehole>> getAllBoreholes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('boreholes');
    return List.generate(maps.length, (i) {
      return Borehole.fromMap(maps[i]);
    });
  }
}
