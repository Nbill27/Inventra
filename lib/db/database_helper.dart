import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite connection. Tests inject an in-memory [factory] and [path].
class DatabaseHelper {
  DatabaseHelper({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactory,
        // `this._path` would make the named parameter private, so callers could
        // not pass `path:` from another library.
        // ignore: prefer_initializing_formals
        _path = path;

  static final DatabaseHelper instance = DatabaseHelper();

  static const fileName = 'peminjaman_barang.db';

  /// v2 replaced the generic `category`/`note` columns with the columns of the
  /// master "Daftar Alat Ukur" file.
  static const schemaVersion = 2;

  final DatabaseFactory _factory;
  final String? _path;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = _path ?? p.join(await _factory.getDatabasesPath(), fileName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: _createSchema,
        onUpgrade: _migrate,
      ),
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        no_urut TEXT,
        name TEXT NOT NULL,
        code TEXT,
        range_text TEXT,
        brand TEXT,
        pic TEXT,
        status TEXT,
        stock_total INTEGER NOT NULL CHECK (stock_total >= 0),
        stock_available INTEGER NOT NULL CHECK (stock_available >= 0),
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER NOT NULL REFERENCES items (id),
        borrower_name TEXT NOT NULL,
        contact TEXT,
        quantity INTEGER NOT NULL CHECK (quantity > 0),
        loan_date TEXT NOT NULL,
        due_date TEXT NOT NULL,
        return_date TEXT,
        status TEXT NOT NULL CHECK (status IN ('dipinjam', 'selesai')),
        note TEXT,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    await db.execute('CREATE INDEX idx_loans_item ON loans (item_id)');
    await db.execute('CREATE INDEX idx_loans_status ON loans (status)');
  }

  /// v1 is the initial schema. Add one ordered step per new version.
  Future<void> _migrate(Database db, int from, int to) async {
    if (from < 2) {
      // v2 mirrors the columns of the master "Daftar Alat Ukur" file. The old
      // `category`/`note` columns are left in place but unused, so the table is
      // never rebuilt while `loans.item_id` still references it.
      await db.execute('ALTER TABLE items ADD COLUMN no_urut TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN range_text TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN brand TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN pic TEXT');
      await db.execute('ALTER TABLE items ADD COLUMN status TEXT');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
