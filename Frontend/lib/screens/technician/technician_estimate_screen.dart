import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/booking_provider.dart';

/// Step 2 of the "Physical Inspection -> Estimate -> Approval" flow.
///
/// Shown to the technician once they've physically inspected the job
/// on-site (booking.status == 'in_progress', after arrival/OTP). They build
/// up a labour + parts cost breakdown here; submitting sends it to the
/// customer for approval and moves the booking to
/// 'awaiting_estimate_approval' — see BookingProvider.submitEstimate /
/// backend booking_service.go SubmitEstimate.
class TechnicianEstimateScreen extends StatefulWidget {
  final String bookingId;
  final String technicianId;
  final String customerName;

  const TechnicianEstimateScreen({
    Key? key,
    required this.bookingId,
    required this.technicianId,
    this.customerName = 'the customer',
  }) : super(key: key);

  @override
  State<TechnicianEstimateScreen> createState() => _TechnicianEstimateScreenState();
}

class _EstimateLineDraft {
  String itemType; // 'labour' | 'part'
  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;

  _EstimateLineDraft({required this.itemType, String name = '', String qty = '1', String price = ''})
      : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty),
        priceCtrl = TextEditingController(text: price);

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 1;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get amount => quantity * unitPrice;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _TechnicianEstimateScreenState extends State<TechnicianEstimateScreen> {
  final List<_EstimateLineDraft> _lines = [
    _EstimateLineDraft(itemType: 'labour', name: 'Labour charge'),
  ];
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  double get _labourTotal =>
      _lines.where((l) => l.itemType == 'labour').fold(0.0, (sum, l) => sum + l.amount);
  double get _partsTotal =>
      _lines.where((l) => l.itemType == 'part').fold(0.0, (sum, l) => sum + l.amount);
  double get _grandTotal => _labourTotal + _partsTotal;

  void _addLine(String type) {
    setState(() => _lines.add(_EstimateLineDraft(itemType: type)));
  }

  void _removeLine(int index) {
    setState(() {
      _lines[index].dispose();
      _lines.removeAt(index);
    });
  }

  @override
  void dispose() {
    for (final l in _lines) {
      l.dispose();
    }
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final items = <BookingEstimateItem>[];
    for (final l in _lines) {
      final name = l.nameCtrl.text.trim();
      if (name.isEmpty || l.unitPrice <= 0) continue;
      items.add(BookingEstimateItem(
        id: '',
        estimateId: '',
        itemType: l.itemType,
        name: name,
        quantity: l.quantity <= 0 ? 1 : l.quantity,
        unitPrice: l.unitPrice,
        amount: l.amount,
      ));
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with a name and price')),
      );
      return;
    }

    setState(() => _submitting = true);
    final ok = await context.read<BookingProvider>().submitEstimate(
          bookingId: widget.bookingId,
          technicianId: widget.technicianId,
          items: items,
          note: _noteCtrl.text.trim(),
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estimate sent to customer for approval')),
      );
    } else {
      final err = context.read<BookingProvider>().error ?? 'Could not submit estimate';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Estimate')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Give ${widget.customerName} a breakdown of labour and parts cost based on your inspection. They\u2019ll need to approve this before you can proceed.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            _sectionHeader('Labour', Icons.build_rounded),
            ..._lineFields('labour'),
            TextButton.icon(
              onPressed: () => _addLine('labour'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add labour line'),
            ),
            const SizedBox(height: 16),
            _sectionHeader('Parts', Icons.settings_suggest_rounded),
            ..._lineFields('part'),
            TextButton.icon(
              onPressed: () => _addLine('part'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add part'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note for customer (optional)',
                hintText: 'e.g. Compressor needs replacement, motor is fine',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _totalsCard(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Send estimate for approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }

  List<Widget> _lineFields(String type) {
    final indices = <int>[];
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].itemType == type) indices.add(i);
    }
    return indices.map((i) {
      final l = _lines[i];
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: TextField(
                controller: l.nameCtrl,
                decoration: InputDecoration(
                  labelText: type == 'labour' ? 'Labour description' : 'Part name',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: TextField(
                controller: l.qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Qty', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: TextField(
                controller: l.priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(prefixText: '\u20b9', labelText: 'Unit price', isDense: true, border: OutlineInputBorder()),
                onChanged: (_) => setState(() {}),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
              onPressed: _lines.length > 1 ? () => _removeLine(i) : null,
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _totalsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          _totalRow('Labour', _labourTotal),
          const SizedBox(height: 6),
          _totalRow('Parts', _partsTotal),
          const Divider(height: 20),
          _totalRow('Total estimate', _grandTotal, bold: true),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double amount, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 15 : 13);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('\u20b9${amount.toStringAsFixed(0)}', style: style),
      ],
    );
  }
}