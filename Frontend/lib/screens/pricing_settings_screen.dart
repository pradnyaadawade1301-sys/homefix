import 'package:flutter/material.dart';

/// Combined pricing settings for a technician: hourly/visit charge, travel
/// fee, emergency service fee, and minimum service charge. UI-only for now;
/// wire the save action to your technician profile/pricing API.
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
  void dispose() {
    _hourlyController.dispose();
    _travelController.dispose();
    _emergencyController.dispose();
    _minimumController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    // TODO: PATCH technician pricing fields to your backend.
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pricing updated')),
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