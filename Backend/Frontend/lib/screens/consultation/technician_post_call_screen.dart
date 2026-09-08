import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/consultation_provider.dart';

/// Shown right after a Live Video Consultation call ends, on the
/// TECHNICIAN's side. Lets them send the customer a simple, structured
/// recommendation — what they found on the call, and (optionally) a
/// suggested price for an on-site visit — via
/// POST /consultations/:id/recommend-onsite.
///
/// The customer sees this on their own PostCallScreen and explicitly
/// Accepts (turns it into a real booking with the same technician, see
/// ConsultationService.Escalate) or Declines it. This screen deliberately
/// does NOT create a booking itself — that decision belongs to the customer.
class TechnicianPostCallScreen extends StatefulWidget {
  final String consultationId;
  final String categoryName;
  final String? customerName;

  const TechnicianPostCallScreen({
    Key? key,
    required this.consultationId,
    required this.categoryName,
    this.customerName,
  }) : super(key: key);

  @override
  State<TechnicianPostCallScreen> createState() => _TechnicianPostCallScreenState();
}

class _TechnicianPostCallScreenState extends State<TechnicianPostCallScreen> {
  final _summaryController = TextEditingController();
  final _priceController = TextEditingController();
  bool _isSending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _summaryController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final summary = _summaryController.text.trim();
    if (summary.isEmpty) {
      setState(() => _error = 'Please describe what you found on the call');
      return;
    }
    double? price;
    final priceText = _priceController.text.trim();
    if (priceText.isNotEmpty) {
      price = double.tryParse(priceText);
      if (price == null) {
        setState(() => _error = 'Enter a valid price, or leave it blank');
        return;
      }
    }

    setState(() {
      _error = null;
      _isSending = true;
    });
    try {
      await context.read<ConsultationProvider>().sendRecommendation(
            widget.consultationId,
            summary: summary,
            price: price,
          );
      if (!mounted) return;
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _done() {
    // Back to the technician's jobs dashboard — same "pop everything back
    // to root" pattern the customer's PostCallScreen uses for its own Done
    // button, since the whole call flow was pushed on top of it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_sent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call Complete')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 56),
                  const SizedBox(height: 16),
                  const Text('Recommendation sent', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(
                    'The customer will review it and let you know if they\'d like to book a visit.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(onPressed: _done, child: const Text('Done')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Call Complete')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.customerName != null
                          ? 'Your call with ${widget.customerName} has ended.'
                          : 'Your video consultation has ended.',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text('Send a recommendation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Tell the customer what you found and — if you think an on-site '
              'visit is needed — roughly what it might cost. They can then '
              'choose to book a visit with you.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text('What did you find?', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _summaryController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g. "Looks like the compressor needs checking — I\'d recommend an on-site inspection."',
              ),
            ),
            const SizedBox(height: 16),
            const Text('Suggested price (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(hintText: 'e.g. 499', prefixText: '₹ '),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12.5)),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _send,
                child: _isSending
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Send to Customer'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isSending ? null : _done,
                child: const Text('Skip — don\'t send anything'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}