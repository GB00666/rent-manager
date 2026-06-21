import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rent_payment.dart';
import '../services/rent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import 'add_tenant_screen.dart';

enum _DuesFilter { all, paid, pending }

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final _service = RentService.instance;
  final _searchCtrl = TextEditingController();

  List<RentPayment> _payments = [];
  bool _loading = true;
  _DuesFilter _filter = _DuesFilter.all;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(() {
      setState(() => _search = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final payments = await _service.getCurrentMonthPayments();
      if (!mounted) return;
      setState(() {
        _payments = payments;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load tenants: $e')));
    }
  }

  List<RentPayment> get _filtered {
    var list = _payments;
    if (_search.isNotEmpty) {
      list = list
          .where((p) =>
              (p.tenantName ?? '').toLowerCase().contains(_search) ||
              (p.tenantRoomComplex ?? '').toLowerCase().contains(_search))
          .toList();
    }
    switch (_filter) {
      case _DuesFilter.paid:
        return list.where((p) => p.status == 'paid').toList();
      case _DuesFilter.pending:
        return list.where((p) => p.status != 'paid').toList();
      case _DuesFilter.all:
        return list;
    }
  }

  int get _allCount => _payments.length;
  int get _paidCount => _payments.where((p) => p.status == 'paid').length;
  int get _pendingCount => _payments.where((p) => p.status != 'paid').length;

  Future<void> _remind(RentPayment p) async {
    final message =
        'Hi ${p.tenantName}, this is a friendly reminder that your rent of '
        '${Formatters.rupee(p.pendingAmount)} was due on '
        '${Formatters.dayOrdinal(p.dueDate?.day ?? 1)}. Please pay at your '
        'earliest convenience. Thank you!';
    await Share.share(message, subject: 'Rent Reminder');
    await _service.markReminderSent(p.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Reminder shared')));
  }

  Future<void> _call(RentPayment p) async {
    final phone = p.tenantPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number on file')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _collect(RentPayment p) async {
    final amountCtrl =
        TextEditingController(text: p.pendingAmount.toStringAsFixed(0));
    String method = 'UPI';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Collect rent from ${p.tenantName}',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount Collected (₹)',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    children: ['UPI', 'Cash', 'Bank Transfer'].map((m) {
                      final sel = method == m;
                      return ChoiceChip(
                        label: Text(m),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        onSelected: (_) => setSheetState(() => method = m),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Confirm Collection'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed != true) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? p.pendingAmount;

    try {
      await _service.collectPayment(
        paymentId: p.id,
        amount: amount,
        paymentMethod: method,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Collected ${Formatters.rupee(amount)} from ${p.tenantName}')),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to collect: $e')));
    }
  }

  void _goToAddTenant() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddTenantScreen()),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Tenants')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search Tenant Name / Room No...',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textGrey),
                fillColor: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Dues ($_allCount)',
                  selected: _filter == _DuesFilter.all,
                  onTap: () => setState(() => _filter = _DuesFilter.all),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Paid ($_paidCount)',
                  selected: _filter == _DuesFilter.paid,
                  onTap: () => setState(() => _filter = _DuesFilter.paid),
                ),
                const SizedBox(width: 10),
                _FilterChip(
                  label: 'Pending ($_pendingCount)',
                  selected: _filter == _DuesFilter.pending,
                  onTap: () => setState(() => _filter = _DuesFilter.pending),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: list.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text(
                                  'No tenants found.',
                                  style: TextStyle(color: AppColors.textGrey),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            itemCount: list.length,
                            itemBuilder: (ctx, i) {
                              final p = list[i];
                              return _TenantDueCard(
                                payment: p,
                                onCall: () => _call(p),
                                onRemind: () => _remind(p),
                                onCollect: () => _collect(p),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddTenant,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantDueCard extends StatelessWidget {
  final RentPayment payment;
  final VoidCallback onCall;
  final VoidCallback onRemind;
  final VoidCallback onCollect;

  const _TenantDueCard({
    required this.payment,
    required this.onCall,
    required this.onRemind,
    required this.onCollect,
  });

  @override
  Widget build(BuildContext context) {
    final isPaid = payment.status == 'paid';
    final isOverdue = payment.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      isPaid ? AppColors.successSoft : AppColors.dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPaid ? Icons.check : Icons.priority_high_rounded,
                  color: isPaid ? AppColors.success : AppColors.danger,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          payment.tenantName ?? 'Tenant',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        if (payment.tenantPhone != null) ...[
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: onCall,
                            child: const Icon(
                              Icons.phone,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Room/Complex: ${payment.tenantRoomComplex ?? '-'}',
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupee(
                        isPaid ? payment.amountPaid : payment.pendingAmount),
                    style: TextStyle(
                      color: isPaid ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    payment.dueDate != null
                        ? 'Due Date: ${Formatters.dayOrdinal(payment.dueDate!.day)}'
                        : '',
                    style: const TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                isPaid ? 'Paid' : (isOverdue ? 'Overdue' : 'Pending'),
                style: TextStyle(
                  color: isPaid
                      ? AppColors.success
                      : (isOverdue ? AppColors.danger : Colors.orange),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (!isPaid) ...[
                OutlinedButton.icon(
                  onPressed: onRemind,
                  icon:
                      const Icon(Icons.share, size: 16, color: AppColors.success),
                  label: const Text('Remind'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.success,
                    side: const BorderSide(color: AppColors.success),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onCollect,
                  icon: const Icon(Icons.currency_rupee, size: 16),
                  label: const Text('Collect'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ] else
                const Icon(Icons.verified_rounded, color: AppColors.success),
            ],
          ),
        ],
      ),
    );
  }
}
