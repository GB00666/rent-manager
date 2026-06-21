import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../models/tenant.dart';
import '../models/rent_payment.dart';
import '../models/landlord.dart';
import 'app_database.dart';
import 'rent_service.dart';

/// Mobile (Android/iOS) data-access layer.
/// All reads/writes go to the on-device SQLite database — no network,
/// no accounts. Data persists across app restarts but stays on this
/// device only.
class SqliteRentService implements RentService {
  static const _uuid = Uuid();

  Future<Database> get _db async => AppDatabase.instance.database;

  // ---------------------------------------------------------------------
  // LANDLORD PROFILE
  // ---------------------------------------------------------------------

  @override
  Future<Landlord> getLandlordProfile() async {
    final db = await _db;
    final rows = await db.query('landlord', where: 'id = 1', limit: 1);
    if (rows.isEmpty) {
      // Defensive fallback in case the seed row is ever missing.
      await db.insert(
        'landlord',
        Landlord(
          fullName: '',
          phoneNumber: '',
          businessName: '',
          upiId: '',
          whatsappAutomationSync: true,
          paymentSuccessSound: true,
        ).toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return getLandlordProfile();
    }
    return Landlord.fromMap(rows.first);
  }

  @override
  Future<Landlord> updateLandlordProfile({
    String? fullName,
    String? phoneNumber,
    String? businessName,
    String? upiId,
  }) async {
    final db = await _db;
    await db.update(
      'landlord',
      {
        if (fullName != null) 'full_name': fullName,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (businessName != null) 'business_name': businessName,
        if (upiId != null) 'upi_id': upiId,
      },
      where: 'id = 1',
    );
    return getLandlordProfile();
  }

  @override
  Future<void> updateAutomationSettings({
    bool? whatsappAutomationSync,
    bool? paymentSuccessSound,
  }) async {
    final db = await _db;
    await db.update(
      'landlord',
      {
        if (whatsappAutomationSync != null)
          'whatsapp_automation_sync': whatsappAutomationSync ? 1 : 0,
        if (paymentSuccessSound != null)
          'payment_success_sound': paymentSuccessSound ? 1 : 0,
      },
      where: 'id = 1',
    );
  }

  // ---------------------------------------------------------------------
  // TENANTS
  // ---------------------------------------------------------------------

  @override
  Future<List<Tenant>> getTenants({String? searchQuery}) async {
    final db = await _db;
    List<Map<String, dynamic>> rows;
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      rows = await db.query(
        'tenants',
        where: 'name LIKE ? OR room_complex LIKE ?',
        whereArgs: [q, q],
        orderBy: 'created_at DESC',
      );
    } else {
      rows = await db.query('tenants', orderBy: 'created_at DESC');
    }
    return rows.map((r) => Tenant.fromMap(r)).toList();
  }

  /// Adds a tenant AND creates this month's rent_payments row for them.
  @override
  Future<Tenant> addTenant({
    required String name,
    String? phoneNumber,
    String? roomComplex,
    required double monthlyRent,
    required int dueDay,
  }) async {
    final db = await _db;
    final tenant = Tenant(
      id: _uuid.v4(),
      name: name,
      phoneNumber: phoneNumber,
      roomComplex: roomComplex,
      monthlyRent: monthlyRent,
      dueDay: dueDay,
      status: 'active',
      createdAt: DateTime.now(),
    );

    await db.insert('tenants', tenant.toMap());

    final now = DateTime.now();
    final dueDate = DateTime(now.year, now.month, dueDay);

    final payment = RentPayment(
      id: _uuid.v4(),
      tenantId: tenant.id,
      amountDue: monthlyRent,
      amountPaid: 0,
      periodMonth: now.month,
      periodYear: now.year,
      dueDate: dueDate,
      status: 'pending',
      autoVerified: false,
    );

    await db.insert('rent_payments', payment.toMap());

    return tenant;
  }

  @override
  Future<void> deleteTenant(String tenantId) async {
    final db = await _db;
    await db.delete('tenants', where: 'id = ?', whereArgs: [tenantId]);
    await db.delete(
      'rent_payments',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
    );
  }

  // ---------------------------------------------------------------------
  // RENT PAYMENTS / COLLECTION
  // ---------------------------------------------------------------------

  static const _joinedSelect = '''
    SELECT
      rp.*,
      t.name AS tenant_name,
      t.phone_number AS tenant_phone,
      t.room_complex AS tenant_room_complex
    FROM rent_payments rp
    JOIN tenants t ON t.id = rp.tenant_id
  ''';

  /// All payment rows for the current calendar month, joined with tenant info.
  @override
  Future<List<RentPayment>> getCurrentMonthPayments() async {
    final db = await _db;
    final now = DateTime.now();
    final rows = await db.rawQuery(
      '$_joinedSelect WHERE rp.period_month = ? AND rp.period_year = ? '
      'ORDER BY rp.status ASC, t.name ASC',
      [now.month, now.year],
    );
    return rows.map((r) => RentPayment.fromMap(r)).toList();
  }

  /// Most recent payments that have actually been collected (paid),
  /// across any period — used for "Recent Collection Logs" on Home.
  @override
  Future<List<RentPayment>> getRecentCollectionLogs({int limit = 10}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_joinedSelect WHERE rp.status = ? ORDER BY rp.paid_at DESC LIMIT ?',
      ['paid', limit],
    );
    return rows.map((r) => RentPayment.fromMap(r)).toList();
  }

  /// Marks a payment as collected (full or partial amount).
  @override
  Future<RentPayment> collectPayment({
    required String paymentId,
    required double amount,
    String paymentMethod = 'UPI',
    bool autoVerified = true,
  }) async {
    final db = await _db;
    await db.update(
      'rent_payments',
      {
        'amount_paid': amount,
        'status': 'paid',
        'payment_method': paymentMethod,
        'auto_verified': autoVerified ? 1 : 0,
        'paid_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [paymentId],
    );

    final rows = await db.rawQuery(
      '$_joinedSelect WHERE rp.id = ?',
      [paymentId],
    );
    return RentPayment.fromMap(rows.first);
  }

  @override
  Future<void> markReminderSent(String paymentId) async {
    final db = await _db;
    await db.update(
      'rent_payments',
      {'reminder_sent_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
  }

  // ---------------------------------------------------------------------
  // DASHBOARD / REPORT AGGREGATES
  // ---------------------------------------------------------------------

  @override
  Future<CollectionSummary> getCurrentMonthSummary() async {
    final payments = await getCurrentMonthPayments();
    final tenants = await getTenants();

    double expected = 0;
    double received = 0;
    int paidCount = 0;
    int pendingCount = 0;

    for (final p in payments) {
      expected += p.amountDue;
      received += p.amountPaid;
      if (p.status == 'paid') {
        paidCount++;
      } else {
        pendingCount++;
      }
    }

    return CollectionSummary(
      expected: expected,
      received: received,
      pending: (expected - received).clamp(0, double.infinity),
      totalTenants: tenants.length,
      paidCount: paidCount,
      pendingCount: pendingCount,
    );
  }
}
