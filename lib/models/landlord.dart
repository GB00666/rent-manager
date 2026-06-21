class Landlord {
  final String id;
  final String? fullName;
  final String? phoneNumber;
  final String? businessName;
  final String? upiId;
  final bool whatsappAutomationSync;
  final bool paymentSuccessSound;

  Landlord({
    required this.id,
    this.fullName,
    this.phoneNumber,
    this.businessName,
    this.upiId,
    required this.whatsappAutomationSync,
    required this.paymentSuccessSound,
  });

  factory Landlord.fromMap(Map<String, dynamic> map) {
    return Landlord(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      phoneNumber: map['phone_number'] as String?,
      businessName: map['business_name'] as String?,
      upiId: map['upi_id'] as String?,
      whatsappAutomationSync: map['whatsapp_automation_sync'] as bool? ?? true,
      paymentSuccessSound: map['payment_success_sound'] as bool? ?? true,
    );
  }

  String get displayInitials {
    final n = (fullName ?? '').trim();
    if (n.isEmpty) return 'LL';
    final parts = n.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}
