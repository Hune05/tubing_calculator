import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tubing_calculator.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // 💡 버전업! (기존 1에서 2로 변경하여 새 테이블 생성 유도)
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. 작업 기록(History) 테이블
    await db.execute('''
      CREATE TABLE history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        bend_data TEXT,
        p_to_p TEXT,
        pipe_size TEXT,
        total_length TEXT
      )
    ''');

    // 2. 🔥 신규 추가: 프로젝트(Projects) 테이블
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        status TEXT DEFAULT 'ONGOING',
        created_at TEXT
      )
    ''');
  }

  // 데이터베이스 버전이 올라갔을 때 실행되는 로직
  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS projects (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          status TEXT DEFAULT 'ONGOING',
          created_at TEXT
        )
      ''');
    }
  }

  // ==========================================
  // 💡 프로젝트(Projects) 관련 CRUD 메서드
  // ==========================================
  Future<int> insertProject(Map<String, dynamic> project) async {
    final db = await instance.database;
    return await db.insert('projects', project);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await instance.database;
    return await db.query('projects', orderBy: 'id DESC');
  }

  Future<int> deleteProject(int id) async {
    final db = await instance.database;
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  // ==========================================
  // 💡 작업 기록(History) 관련 CRUD 메서드
  // ==========================================
  Future<int> insertHistory(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert('history', row);
  }

  Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await instance.database;
    return await db.query('history', orderBy: 'id DESC');
  }

  Future<int> updateHistory(int id, Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.update('history', row, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteHistory(int id) async {
    final db = await instance.database;
    return await db.delete('history', where: 'id = ?', whereArgs: [id]);
  }
}
