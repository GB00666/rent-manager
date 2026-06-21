import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/rent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/formatters.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _service = RentService.instance;
  CollectionSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final summary = await _service.getCurrentMonthSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load reports: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    final pct = ((summary?.ratio ?? 0) * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const Text(
                    'Collection Reports',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: [
                          const Text(
                            'Collection Ratio this month',
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 220,
                            width: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    startDegreeOffset: -90,
                                    sectionsSpace: 0,
                                    centerSpaceRadius: 78,
                                    sections: [
                                      PieChartSectionData(
                                        value: pct.toDouble(),
                                        color: AppColors.success,
                                        radius: 22,
                                        showTitle: false,
                                      ),
                                      PieChartSectionData(
                                        value: (100 - pct).toDouble(),
                                        color: AppColors.background,
                                        radius: 22,
                                        showTitle: false,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '$pct%',
                                      style: const TextStyle(
                                        fontSize: 38,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Rent Collected',
                                      style: TextStyle(
                                        color: AppColors.textGrey,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Divider(color: AppColors.border),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _ReportStat(
                                label: 'Expected',
                                value:
                                    Formatters.rupee(summary?.expected ?? 0),
                                color: AppColors.textDark,
                              ),
                              _ReportStat(
                                label: 'Received',
                                value:
                                    Formatters.rupee(summary?.received ?? 0),
                                color: AppColors.success,
                              ),
                              _ReportStat(
                                label: 'Pending',
                                value: Formatters.rupee(summary?.pending ?? 0),
                                color: AppColors.danger,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Active Tenant Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      child: Column(
                        children: [
                          _SummaryRow(
                            label: 'Total active tenants registry',
                            value: '${summary?.totalTenants ?? 0} Tenants',
                            valueColor: AppColors.textDark,
                          ),
                          const Divider(color: AppColors.border),
                          _SummaryRow(
                            label: 'Tenants who paid rent',
                            value: '${summary?.paidCount ?? 0} Paid status',
                            valueColor: AppColors.success,
                          ),
                          const Divider(color: AppColors.border),
                          _SummaryRow(
                            label: 'Tenants with pending dues',
                            value:
                                '${summary?.pendingCount ?? 0} Awaiting dues',
                            valueColor: AppColors.danger,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: const [
                      Icon(Icons.bolt, color: Colors.amber),
                      SizedBox(width: 6),
                      Text(
                        'Smart Collection Tips Hub',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Actionable tips to automate reminders and speed up recovery',
                    style: TextStyle(color: AppColors.textGrey, fontSize: 14),
                  ),
                  const SizedBox(height: 14),
                  const _TipCard(
                    icon: Icons.bolt,
                    title: 'Automated Gentle Reminders',
                    badge: 'Collection +12%',
                  ),
                  const SizedBox(height: 12),
                  const _TipCard(
                    icon: Icons.qr_code_rounded,
                    title: 'Share UPI QR with Due Notices',
                    badge: 'Faster Pay',
                  ),
                ],
              ),
            ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ReportStat({
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
            style: const TextStyle(color: AppColors.textGrey, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;

  const _TipCard({
    required this.icon,
    required this.title,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.successSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
