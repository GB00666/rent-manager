class Tenant {
  final String id;
  final String landlordId;
  final String name;
  final String? phoneNumber;
  final String? roomComplex;
  final double monthlyRent;
  final int dueDay;
  final String status; // active | inactive
  final DateTime createdAt;

  Tenant({
    required this.id,
    required this.landlordId,
    required this.name,
    this.phoneNumber,
    this.roomComplex,
    required this.monthlyRent,
    required this.dueDay,
    required this.status,
    required this.createdAt,
  });

  factory Tenant.fromMap(Map<String, dynamic> map) {
    return Tenant(
      id: map['id'] as String,
      landlordId: map['landlord_id'] as String,
      name: map['name'] as String? ?? '',
      phoneNumber: map['phone_number'] as String?,
      roomComplex: map['room_complex'] as String?,
      monthlyRent: (map['monthly_rent'] as num?)?.toDouble() ?? 0,
      dueDay: (map['due_day'] as num?)?.toInt() ?? 1,
      status: map['status'] as String? ?? 'active',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'landlord_id': landlordId,
      'name': name,
      'phone_number': phoneNumber,
      'room_complex': roomComplex,
      'monthly_rent': monthlyRent,
      'due_day': dueDay,
      'status': status,
    };
  }
}
