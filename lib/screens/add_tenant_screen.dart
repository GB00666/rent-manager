import 'package:flutter/material.dart';
import '../services/rent_service.dart';
import '../theme/app_theme.dart';

class AddTenantScreen extends StatefulWidget {
  const AddTenantScreen({super.key});

  @override
  State<AddTenantScreen> createState() => _AddTenantScreenState();
}

class _AddTenantScreenState extends State<AddTenantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();
  final _rentCtrl = TextEditingController();
  final _dueDayCtrl = TextEditingController(text: '1');

  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _roomCtrl.dispose();
    _rentCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await RentService.instance.addTenant(
        name: _nameCtrl.text.trim(),
        phoneNumber:
            _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        roomComplex:
            _roomCtrl.text.trim().isEmpty ? null : _roomCtrl.text.trim(),
        monthlyRent: double.parse(_rentCtrl.text.trim()),
        dueDay: int.parse(_dueDayCtrl.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to add tenant: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Tenant'),
        centerTitle: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _FieldLabel('Tenant Full Name'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Harsha'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              _FieldLabel('Phone Number'),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: 'e.g. 9876543210'),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Room / Complex'),
              TextFormField(
                controller: _roomCtrl,
                decoration: const InputDecoration(hintText: 'e.g. 2'),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Monthly Rent (₹)'),
              TextFormField(
                controller: _rentCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'e.g. 5500'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Rent is required';
                  final n = double.tryParse(v.trim());
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _FieldLabel('Rent Due Day of Month'),
              TextFormField(
                controller: _dueDayCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'e.g. 8'),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 1 || n > 31) {
                    return 'Enter a day between 1 and 31';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 28),
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
                    : const Text('Save Tenant'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}
