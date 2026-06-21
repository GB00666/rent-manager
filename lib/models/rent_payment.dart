class RentPayment {
  final String id;
  final String landlordId;
  final String tenantId;
  final double amountDue;
  final double amountPaid;
  final int periodMonth;
  final int periodYear;
  final DateTime? dueDate;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String status; // pending | paid
  final bool autoVerified;
  final DateTime? reminderSentAt;

  // joined tenant fields (populated client-side for convenience)
  String? tenantName;
  String? tenantPhone;
  String? tenantRoomComplex;

  RentPayment({
    required this.id,
    required this.landlordId,
    required this.tenantId,
    required this.amountDue,
    required this.amountPaid,
    required this.periodMonth,
    required this.periodYear,
    this.dueDate,
    this.paidAt,
    this.paymentMethod,
    required this.status,
    required this.autoVerified,
    this.reminderSentAt,
    this.tenantName,
    this.tenantPhone,
    this.tenantRoomComplex,
  });

  double get pendingAmount =>
      (amountDue - amountPaid).clamp(0, double.infinity);

  bool get isOverdue {
    if (status == 'paid') return false;
    if (dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  factory RentPayment.fromMap(Map<String, dynamic> map) {
    final tenant = map['tenants'] as Map<String, dynamic>?;
    return RentPayment(
      id: map['id'] as String,
      landlordId: map['landlord_id'] as String,
      tenantId: map['tenant_id'] as String,
      amountDue: (map['amount_due'] as num?)?.toDouble() ?? 0,
      amountPaid: (map['amount_paid'] as num?)?.toDouble() ?? 0,
      periodMonth: (map['period_month'] as num?)?.toInt() ?? 0,
      periodYear: (map['period_year'] as num?)?.toInt() ?? 0,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'].toString())
          : null,
      paidAt: map['paid_at'] != null
          ? DateTime.tryParse(map['paid_at'].toString())
          : null,
      paymentMethod: map['payment_method'] as String?,
      status: map['status'] as String? ?? 'pending',
      autoVerified: map['auto_verified'] as bool? ?? false,
      reminderSentAt: map['reminder_sent_at'] != null
          ? DateTime.tryParse(map['reminder_sent_at'].toString())
          : null,
      tenantName: tenant?['name'] as String?,
      tenantPhone: tenant?['phone_number'] as String?,
      tenantRoomComplex: tenant?['room_complex'] as String?,
    );
  }
}
