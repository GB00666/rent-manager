import 'package:flutter/material.dart';
import '../models/landlord.dart';
import '../services/rent_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _service = RentService.instance;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _upiCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _whatsappSync = true;
  bool _paymentSound = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _businessCtrl.dispose();
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final Landlord landlord = await _service.getOrCreateLandlordProfile();
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = landlord.fullName ?? '';
        _phoneCtrl.text = landlord.phoneNumber ?? '';
        _businessCtrl.text = landlord.businessName ?? '';
        _upiCtrl.text = landlord.upiId ?? '';
        _whatsappSync = landlord.whatsappAutomationSync;
        _paymentSound = landlord.paymentSuccessSound;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to load profile: $e')));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.updateLandlordProfile(
        fullName: _nameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        businessName: _businessCtrl.text.trim(),
        upiId: _upiCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleWhatsapp(bool v) async {
    setState(() => _whatsappSync = v);
    await _service.updateAutomationSettings(whatsappAutomationSync: v);
  }

  Future<void> _toggleSound(bool v) async {
    setState(() => _paymentSound = v);
    await _service.updateAutomationSettings(paymentSuccessSound: v);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const Text(
                  'Your Profile & Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Edit Landlord Account Info',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Your Full Name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            hintText: 'Your Phone Number',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _businessCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Rentals Business Name',
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _upiCtrl,
                          decoration: const InputDecoration(
                            hintText: 'UPI ID for Receiving Rent',
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : const Text('Save Account Changes'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'WhatsApp Automation Sync',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Card(
                  child: Column(
                    children: [
                      _ToggleRow(
                        icon: Icons.phone_iphone_rounded,
                        title: 'WhatsApp Automation Sync',
                        subtitle: 'Directly triggers Whatsapp with no pasting',
                        value: _whatsappSync,
                        onChanged: _toggleWhatsapp,
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      _ToggleRow(
                        icon: Icons.volume_up_rounded,
                        title: 'Payment Success Sound',
                        subtitle: 'Hear success chimes when cash received',
                        value: _paymentSound,
                        onChanged: _toggleSound,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Sign Out'),
                        content:
                            const Text('Are you sure you want to sign out?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _service.signOut();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded,
                      color: AppColors.danger),
                  label: const Text('Sign Out',
                      style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textGrey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
