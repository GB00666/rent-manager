import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tenant.dart';
import '../models/rent_payment.dart';
import '../models/landlord.dart';

/// Central data-access layer for the Rent Manager app.
/// Backed by Supabase (Postgres + Auth) so the same data is available
/// and stays in sync across Android, iOS, and Web for a signed-in
/// landlord.
class RentService {
  RentService._();
  static final RentService instance = RentService._();

  SupabaseClient get _client => Supabase.instance.client;

  String get _uid {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('No authenticated user. Sign in first.');
    }
    return id;
  }

  // ---------------------------------------------------------------------
  // LANDLORD PROFILE
  // ---------------------------------------------------------------------

  Future<Landlord> getOrCreateLandlordProfile() async {
    final existing = await _client
        .from('landlords')
        .select()
        .eq('id', _uid)
        .maybeSingle();

    if (existing != null) return Landlord.fromMap(existing);

    final inserted = await _client
        .from('landlords')
        .insert({'id': _uid})
        .select()
        .single();
    return Landlord.fromMap(inserted);
  }

  Future<Landlord> updateLandlordProfile({
    String? fullName,
    String? phoneNumber,
    String? businessName,
    String? upiId,
  }) async {
    final updated = await _client
        .from('landlords')
        .update({
          if (fullName != null) 'full_name': fullName,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (businessName != null) 'business_name': businessName,
          if (upiId != null) 'upi_id': upiId,
        })
        .eq('id', _uid)
        .select()
        .single();
    return Landlord.fromMap(updated);
  }

  Future<void> updateAutomationSettings({
    bool? whatsappAutomationSync,
    bool? paymentSuccessSound,
  }) async {
    await _client.from('landlords').update({
      if (whatsappAutomationSync != null)
        'whatsapp_automation_sync': whatsappAutomationSync,
      if (paymentSuccessSound != null)
        'payment_success_sound': paymentSuccessSound,
    }).eq('id', _uid);
  }

  // ---------------------------------------------------------------------
  // TENANTS
  // ---------------------------------------------------------------------

  Future<List<Tenant>> getTenants({String? searchQuery}) async {
    var query = _client.from('tenants').select().eq('landlord_id', _uid);

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.or(
        'name.ilike.%$searchQuery%,room_complex.ilike.%$searchQuery%',
      );
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Tenant.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Adds a tenant AND creates this month's rent_payments row for them.
  Future<Tenant> addTenant({
    required String name,
    String? phoneNumber,
    String? roomComplex,
    required double monthlyRent,
    required int dueDay,
  }) async {
    final tenantRow = await _client
        .from('tenants')
        .insert({
          'landlord_id': _uid,
          'name': name,
          'phone_number': phoneNumber,
          'room_complex': roomComplex,
          'monthly_rent': monthlyRent,
          'due_day': dueDay,
          'status': 'active',
        })
        .select()
        .single();

    final tenant = Tenant.fromMap(tenantRow);

    final now = DateTime.now();
    final dueDate = DateTime(now.year, now.month, dueDay);

    await _client.from('rent_payments').insert({
      'landlord_id': _uid,
      'tenant_id': tenant.id,
      'amount_due': monthlyRent,
      'amount_paid': 0,
      'period_month': now.month,
      'period_year': now.year,
      'due_date': dueDate.toIso8601String().split('T').first,
      'status': 'pending',
    });

    return tenant;
  }

  Future<void> deleteTenant(String tenantId) async {
    await _client.from('tenants').delete().eq('id', tenantId);
  }

  // ---------------------------------------------------------------------
  // RENT PAYMENTS / COLLECTION
  // ---------------------------------------------------------------------

  /// All payment rows for the current calendar month, joined with tenant info.
  Future<List<RentPayment>> getCurrentMonthPayments() async {
    final now = DateTime.now();
    final rows = await _client
        .from('rent_payments')
        .select('*, tenants(name, phone_number, room_complex)')
        .eq('landlord_id', _uid)
        .eq('period_month', now.month)
        .eq('period_year', now.year)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => RentPayment.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Most recent payments that have actually been collected (paid),
  /// across any period — used for "Recent Collection Logs" on Home.
  Future<List<RentPayment>> getRecentCollectionLogs({int limit = 10}) async {
    final rows = await _client
        .from('rent_payments')
        .select('*, tenants(name, phone_number, room_complex)')
        .eq('landlord_id', _uid)
        .eq('status', 'paid')
        .order('paid_at', ascending: false)
        .limit(limit);

    return (rows as List)
        .map((r) => RentPayment.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Marks a payment as collected (full amount by default).
  Future<RentPayment> collectPayment({
    required String paymentId,
    required double amount,
    String paymentMethod = 'UPI',
    bool autoVerified = true,
  }) async {
    final updated = await _client
        .from('rent_payments')
        .update({
          'amount_paid': amount,
          'status': 'paid',
          'payment_method': paymentMethod,
          'auto_verified': autoVerified,
          'paid_at': DateTime.now().toIso8601String(),
        })
        .eq('id', paymentId)
        .select('*, tenants(name, phone_number, room_complex)')
        .single();
    return RentPayment.fromMap(updated);
  }

  Future<void> markReminderSent(String paymentId) async {
    await _client.from('rent_payments').update({
      'reminder_sent_at': DateTime.now().toIso8601String(),
    }).eq('id', paymentId);
  }

  // ---------------------------------------------------------------------
  // DASHBOARD / REPORT AGGREGATES
  // ---------------------------------------------------------------------

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

  // ---------------------------------------------------------------------
  // AUTH
  // ---------------------------------------------------------------------

  User? get currentUser => _client.auth.currentUser;

  Future<void> signInAnonymously() async {
    if (_client.auth.currentUser != null) return;
    await _client.auth.signInAnonymously();
  }

  Future<AuthResponse> signUpWithEmail(String email, String password) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signInWithEmail(String email, String password) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();
}

class CollectionSummary {
  final double expected;
  final double received;
  final double pending;
  final int totalTenants;
  final int paidCount;
  final int pendingCount;

  CollectionSummary({
    required this.expected,
    required this.received,
    required this.pending,
    required this.totalTenants,
    required this.paidCount,
    required this.pendingCount,
  });

  double get ratio => expected == 0 ? 0 : (received / expected).clamp(0, 1);
}
