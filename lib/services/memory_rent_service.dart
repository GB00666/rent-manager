import 'package:uuid/uuid.dart';
import '../models/tenant.dart';
import '../models/rent_payment.dart';
import '../models/landlord.dart';
import 'rent_service.dart';

/// Web data-access layer. Holds everything in memory for the lifetime
/// of the browser tab — there's no native SQLite in the browser, so
/// data resets on page refresh. Mirrors SqliteRentService's behavior
/// exactly so the UI code doesn't need to know which backend is active.
class InMemoryRentService implements RentService {
  static const _uuid = Uuid();

  Landlord _landlord = Landlord(
    fullName: '',
    phoneNumber: '',
    businessName: '',
    upiId: '',
    whatsappAutomationSync: true,
    paymentSuccessSound: true,
  );

  final Map<String, Tenant> _tenants = {};
  final Map<String, RentPayment> _payments = {};

  // ---------------------------------------------------------------------
  // LANDLORD PROFILE
  // ---------------------------------------------------------------------

  @override
  Future<Landlord> getLandlordProfile() async => _landlord;

  @override
  Future<Landlord> updateLandlordProfile({
    String? fullName,
    String? phoneNumber,
    String? businessName,
    String? upiId,
  }) async {
    _landlord = Landlord(
      fullName: fullName ?? _landlord.fullName,
      phoneNumber: phoneNumber ?? _landlord.phoneNumber,
      businessName: businessName ?? _landlord.businessName,
      upiId: upiId ?? _landlord.upiId,
      whatsappAutomationSync: _landlord.whatsappAutomationSync,
      paymentSuccessSound: _landlord.paymentSuccessSound,
    );
    return _landlord;
  }

  @override
  Future<void> updateAutomationSettings({
    bool? whatsappAutomationSync,
    bool? paymentSuccessSound,
  }) async {
    _landlord = Landlord(
      fullName: _landlord.fullName,
      phoneNumber: _landlord.phoneNumber,
      businessName: _landlord.businessName,
      upiId: _landlord.upiId,
      whatsappAutomationSync:
          whatsappAutomationSync ?? _landlord.whatsappAutomationSync,
      paymentSuccessSound:
          paymentSuccessSound ?? _landlord.paymentSuccessSound,
    );
  }

  // ---------------------------------------------------------------------
  // TENANTS
  // ---------------------------------------------------------------------

  @override
  Future<List<Tenant>> getTenants({String? searchQuery}) async {
    var list = _tenants.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list
          .where((t) =>
              t.name.toLowerCase().contains(q) ||
              (t.roomComplex ?? '').toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  @override
  Future<Tenant> addTenant({
    required String name,
    String? phoneNumber,
    String? roomComplex,
    required double monthlyRent,
    required int dueDay,
  }) async {
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
    _tenants[tenant.id] = tenant;

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
    )
      ..tenantName = tenant.name
      ..tenantPhone = tenant.phoneNumber
      ..tenantRoomComplex = tenant.roomComplex;

    _payments[payment.id] = payment;

    return tenant;
  }

  @override
  Future<void> deleteTenant(String tenantId) async {
    _tenants.remove(tenantId);
    _payments.removeWhere((_, p) => p.tenantId == tenantId);
  }

  // ---------------------------------------------------------------------
  // RENT PAYMENTS / COLLECTION
  // ---------------------------------------------------------------------

  RentPayment _withTenantInfo(RentPayment p) {
    final t = _tenants[p.tenantId];
    p.tenantName = t?.name;
    p.tenantPhone = t?.phoneNumber;
    p.tenantRoomComplex = t?.roomComplex;
    return p;
  }

  @override
  Future<List<RentPayment>> getCurrentMonthPayments() async {
    final now = DateTime.now();
    final list = _payments.values
        .where((p) =>
            p.periodMonth == now.month && p.periodYear == now.year)
        .map(_withTenantInfo)
        .toList()
      ..sort((a, b) {
        final statusCompare = a.status.compareTo(b.status);
        if (statusCompare != 0) return statusCompare;
        return (a.tenantName ?? '').compareTo(b.tenantName ?? '');
      });
    return list;
  }

  @override
  Future<List<RentPayment>> getRecentCollectionLogs({int limit = 10}) async {
    final list = _payments.values
        .where((p) => p.status == 'paid')
        .map(_withTenantInfo)
        .toList()
      ..sort((a, b) =>
          (b.paidAt ?? DateTime(0)).compareTo(a.paidAt ?? DateTime(0)));
    return list.take(limit).toList();
  }

  @override
  Future<RentPayment> collectPayment({
    required String paymentId,
    required double amount,
    String paymentMethod = 'UPI',
    bool autoVerified = true,
  }) async {
    final existing = _payments[paymentId];
    if (existing == null) {
      throw StateError('Payment not found: $paymentId');
    }
    final updated = RentPayment(
      id: existing.id,
      tenantId: existing.tenantId,
      amountDue: existing.amountDue,
      amountPaid: amount,
      periodMonth: existing.periodMonth,
      periodYear: existing.periodYear,
      dueDate: existing.dueDate,
      paidAt: DateTime.now(),
      paymentMethod: paymentMethod,
      status: 'paid',
      autoVerified: autoVerified,
      reminderSentAt: existing.reminderSentAt,
    );
    _payments[paymentId] = updated;
    return _withTenantInfo(updated);
  }

  @override
  Future<void> markReminderSent(String paymentId) async {
    final existing = _payments[paymentId];
    if (existing == null) return;
    _payments[paymentId] = RentPayment(
      id: existing.id,
      tenantId: existing.tenantId,
      amountDue: existing.amountDue,
      amountPaid: existing.amountPaid,
      periodMonth: existing.periodMonth,
      periodYear: existing.periodYear,
      dueDate: existing.dueDate,
      paidAt: existing.paidAt,
      paymentMethod: existing.paymentMethod,
      status: existing.status,
      autoVerified: existing.autoVerified,
      reminderSentAt: DateTime.now(),
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
