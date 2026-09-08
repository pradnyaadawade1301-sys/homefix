import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../services/dispute_service.dart';
import 'dispute_detail_screen.dart';

/// "Raise a dispute" form. Push this with EXACTLY ONE of [bookingId] /
/// [consultationId] set — matches the backend's "exactly one required" rule.
/// Wire up from booking/consultation detail screens, e.g.:
///
///   Navigator.push(context, MaterialPageRoute(
///     builder: (_) => RaiseDisputeScreen(bookingId: booking.id),
///   ));
class RaiseDisputeScreen extends StatefulWidget {
  final String? bookingId;
  final String? consultationId;

  const RaiseDisputeScreen({Key? key, this.bookingId, this.consultationId})
      : assert(bookingId != null || consultationId != null,
            'RaiseDisputeScreen needs a bookingId or consultationId'),
        super(key: key);

  @override
  State<RaiseDisputeScreen> createState() => _RaiseDisputeScreenState();
}

class _RaiseDisputeScreenState extends State<RaiseDisputeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dispute = await context.read<DisputeService>().raise(
            bookingId: widget.bookingId,
            consultationId: widget.consultationId,
            reason: _reasonController.text.trim(),
          );
      if (!mounted) return;
      // Replace this form with the detail screen so back-navigation doesn't
      // resubmit the same dispute.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => DisputeDetailScreen(disputeId: dispute.id)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raise a Dispute')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text(
                'Tell us what went wrong. Our team will review and get back to you.',
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _reasonController,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'Describe the issue in detail...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Reason is required';
                  if (v.trim().length < 10) return 'Please add a bit more detail';
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppTheme.errorColor)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Dispute'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}