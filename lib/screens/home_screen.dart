import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/landlord.dart';
import '../models/rent_payment.dart';
import '../services/rent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';
import '../widgets/rent_app_bar.dart';
import 'add_tenant_screen.dart';
import 'root_shell.dart' show TabController2;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _service = RentService.instance;

  Landlord? _landlord;
  CollectionSummary? _summary;
  List<RentPayment> _recentLogs = [];
  List<RentPayment> _pendingThisMonth = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final landlord = await _service.getOrCreateLandlordProfile();
      final summary = await _service.getCurrentMonthSummary();
      final logs = await _service.getRecentCollectionLogs(limit: 5);
      final monthPayments = await _service.getCurrentMonthPayments();
      if (!mounted) return;
      setState(() {
        _landlord = landlord;
        _summary = summary;
        _recentLogs = logs;
        _pendingThisMonth =
            monthPayments.where((p) => p.status != 'paid').toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e')),
      );
    }
  }

  Future<void> _sendReminder() async {
    if (_pendingThisMonth.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending rent to remind about 🎉')),
      );
      return;
    }
    final names = _pendingThisMonth.map((p) => p.tenantName ?? 'Tenant').join(', ');
    final totalPending =
        _pendingThisMonth.fold<double>(0, (sum, p) => sum + p.pendingAmount);
    final message =
        'Rent Reminder: Hi $names, your rent of ${Formatters.rupee(totalPending)} '
        'is due. Please pay at your earliest convenience. Thank you!';

    await Share.share(message, subject: 'Rent Reminder');

    for (final p in _pendingThisMonth) {
      await _service.markReminderSent(p.id);
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
    final summary = _summary;
    final landlord = _landlord;

    return Scaffold(
      appBar: RentAppBar(initials: landlord?.displayInitials ?? 'LL'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    'Welcome, Landlord',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Rent Manager Active',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CollectionCard(summary: summary),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.ios_share_rounded,
                          title: 'Send Reminder',
                          subtitle: 'Rent Notice',
                          filled: true,
                          onTap: _sendReminder,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _QuickActionCard(
                          icon: Icons.person_add_alt_1_rounded,
                          title: 'Add Tenant',
                          subtitle: 'New Record',
                          filled: false,
                          onTap: _goToAddTenant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent Collection Logs',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      TextButton(
                        onPressed: () {
                          TabController2.of(context)?.switchTab(1);
                        },
                        child: const Text('See All'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_recentLogs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No collections yet this period.',
                          style: TextStyle(color: AppColors.textGrey),
                        ),
                      ),
                    )
                  else
                    ..._recentLogs.map((p) => _CollectionLogTile(payment: p)),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToAddTenant,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _CollectionCard extends StatelessWidget {
  final CollectionSummary? summary;
  const _CollectionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final received = summary?.received ?? 0;
    final expected = summary?.expected ?? 0;
    final ratio = summary?.ratio ?? 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT COLLECTION',
              style: TextStyle(
                color: AppColors.textGrey,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 34,
                ),
                children: [
                  TextSpan(text: Formatters.rupee(received)),
                  TextSpan(
                    text: ' / ${Formatters.rupeeAmount(expected)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: AppColors.background,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.success),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _StatColumn(
                  label: 'TENANTS',
                  value: '${summary?.totalTenants ?? 0}',
                  color: AppColors.textDark,
                ),
                const _VDivider(),
                _StatColumn(
                  label: 'RECEIVED',
                  value: '${summary?.paidCount ?? 0}',
                  color: AppColors.success,
                ),
                const _VDivider(),
                _StatColumn(
                  label: 'PENDING',
                  value: '${summary?.pendingCount ?? 0}',
                  color: AppColors.danger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.border,
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : Colors.white;
    final fg = filled ? Colors.white : AppColors.textDark;
    final iconBg =
        filled ? Colors.white.withOpacity(0.18) : AppColors.background;
    final iconColor = filled ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: filled ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: filled ? Colors.white70 : AppColors.textGrey,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionLogTile extends StatelessWidget {
  final RentPayment payment;
  const _CollectionLogTile({required this.payment});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.successSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: AppColors.success),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        payment.paymentMethod ?? 'UPI',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  payment.paidAt != null
                      ? 'Received on ${Formatters.dateTime(payment.paidAt!)}'
                      : 'Received',
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
                '+${Formatters.rupee(payment.amountPaid)}',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              if (payment.autoVerified)
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.bolt, size: 14, color: Colors.amber),
                      SizedBox(width: 2),
                      Text(
                        'Auto Verified',
                        style: TextStyle(fontSize: 11, color: AppColors.textGrey),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
