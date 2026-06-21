import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Opens (and creates, on first run) the local SQLite database used by
/// the whole app. All data lives on-device only — nothing leaves the
/// phone.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'rent_manager.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE landlord (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            full_name TEXT,
            phone_number TEXT,
            business_name TEXT,
            upi_id TEXT,
            whatsapp_automation_sync INTEGER NOT NULL DEFAULT 1,
            payment_success_sound INTEGER NOT NULL DEFAULT 1
          )
        ''');

        await db.execute('''
          CREATE TABLE tenants (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone_number TEXT,
            room_complex TEXT,
            monthly_rent REAL NOT NULL DEFAULT 0,
            due_day INTEGER NOT NULL DEFAULT 1,
            status TEXT NOT NULL DEFAULT 'active',
            created_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE rent_payments (
            id TEXT PRIMARY KEY,
            tenant_id TEXT NOT NULL,
            amount_due REAL NOT NULL DEFAULT 0,
            amount_paid REAL NOT NULL DEFAULT 0,
            period_month INTEGER NOT NULL,
            period_year INTEGER NOT NULL,
            due_date TEXT,
            paid_at TEXT,
            payment_method TEXT,
            status TEXT NOT NULL DEFAULT 'pending',
            auto_verified INTEGER NOT NULL DEFAULT 0,
            reminder_sent_at TEXT,
            FOREIGN KEY (tenant_id) REFERENCES tenants (id) ON DELETE CASCADE,
            UNIQUE (tenant_id, period_month, period_year)
          )
        ''');

        // Seed a default (empty) landlord profile row.
        await db.insert('landlord', {
          'id': 1,
          'full_name': '',
          'phone_number': '',
          'business_name': '',
          'upi_id': '',
          'whatsapp_automation_sync': 1,
          'payment_success_sound': 1,
        });
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }
}
