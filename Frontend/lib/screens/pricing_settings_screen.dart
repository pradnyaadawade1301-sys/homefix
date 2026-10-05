import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/technician_theme.dart';
import '../providers/category_provider.dart';

/// Combined pricing settings for a technician: hourly/visit charge, travel
/// fee, emergency service fee, and minimum service charge. Saved via
/// PATCH /technicians/me/settings.
class PricingSettingsScreen extends StatefulWidget {
  final String initialField;

  const PricingSettingsScreen({Key? key, this.initialField = ''}) : super(key: key);

  @override
  State<PricingSettingsScreen> createState() => _PricingSettingsScreenState();
}

class _PricingSettingsScreenState extends State<PricingSettingsScreen> {
  final _hourlyController = TextEditingController(text: '299');
  final _travelController = TextEditingController(text: '49');
  final _emergencyController = TextEditingController(text: '99');
  final _minimumController = TextEditingController(text: '199');
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await context.read<TechnicianKycProvider>().loadSettings();
    if (!mounted) return;
    String? txt(String k) => s[k] is num ? (s[k] as num).toStringAsFixed(0) : null;
    setState(() {
      _hourlyController.text = txt('hourly_rate') ?? _hourlyController.text;
      _travelController.text = txt('travel_fee') ?? _travelController.text;
      _emergencyController.text = txt('emergency_fee') ?? _emergencyController.text;
      _minimumController.text = txt('minimum_charge') ?? _minimumController.text;
    });
  }

  @override
  void dispose() {
    _hourlyController.dispose();
    _travelController.dispose();
    _emergencyController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final values = {
      'hourly_rate': double.tryParse(_hourlyController.text.trim()),
      'travel_fee': double.tryParse(_travelController.text.trim()),
      'emergency_fee': double.tryParse(_emergencyController.text.trim()),
      'minimum_charge': double.tryParse(_minimumController.text.trim()),
    };
    if (values.values.any((v) => v == null || v < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid amounts (0 or more) in every field')),
      );
      return;
    }
    setState(() => _isSaving = true);
    final provider = context.read<TechnicianKycProvider>();
    final ok = await provider.saveSettings(values.map((k, v) => MapEntry(k, v!)));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Pricing updated' : (provider.error ?? 'Could not save pricing'))),
    );
  }

  Widget _priceField(String label, String hint, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(hint, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              prefixText: '₹ ',
              prefixIcon: Icon(icon),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Pricing Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _priceField('Hourly / Visit Charge', 'Base charge for a standard visit', _hourlyController, Icons.currency_rupee_rounded),
                  _priceField('Travel Fee', 'Added if the customer is outside your free-travel range', _travelController, Icons.local_shipping_outlined),
                  _priceField('Emergency Service Fee', 'Extra charge for urgent same-hour requests', _emergencyController, Icons.priority_high_rounded),
                  _priceField('Minimum Service Charge', 'Lowest amount charged regardless of job size', _minimumController, Icons.money_off_csred_outlined),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: TechTheme.primary, foregroundColor: Colors.white),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                      )
                    : const Text('Save Pricing'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}