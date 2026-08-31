import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Manage saved payment methods (cards, UPI) shown as quick "preferred method"
/// shortcuts. Actual charges always go through Razorpay's own hosted Checkout
/// sheet (see payment_provider.dart / payment_screen.dart), which already
/// offers every method Razorpay supports (UPI, cards, netbanking, wallets) —
/// this screen doesn't gate what a customer can pay with, it's just a
/// shortlist. UI-only for now — wire the add/delete actions to your payments
/// API once the backend endpoint exists.
class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  // TODO: Replace with real data from your payments provider/API.
  final List<_PaymentMethod> _methods = [
    _PaymentMethod(type: _MethodType.upi, label: 'pradnya@okhdfcbank', isDefault: true),
  ];

  void _addUpi() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddUpiSheet(
        onAdd: (upiId) {
          setState(() {
            _methods.add(_PaymentMethod(type: _MethodType.upi, label: upiId, isDefault: false));
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('UPI ID added. This will sync once payments backend is connected.')),
          );
        },
      ),
    );
  }

  void _addCard() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddCardSheet(
        onAdd: (maskedLabel) {
          setState(() {
            _methods.add(_PaymentMethod(type: _MethodType.card, label: maskedLabel, isDefault: false));
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Card added. This will sync once payments backend is connected.')),
          );
        },
      ),
    );
  }

  void _remove(int index) {
    setState(() => _methods.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Payment Methods')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_methods.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 60),
              child: Column(
                children: [
                  Icon(Icons.payment_outlined, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No payment methods added yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                ],
              ),
            )
          else
            ..._methods.asMap().entries.map((entry) {
              final index = entry.key;
              final m = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.lightOutline),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        m.type == _MethodType.upi
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card_rounded,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                          if (m.isDefault) ...[
                            const SizedBox(height: 3),
                            const Text('Default',
                                style: TextStyle(color: AppTheme.successColor, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey),
                      onPressed: () => _remove(index),
                    ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addUpi,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add UPI ID'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _addCard,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Card'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'These are just quick shortcuts. At checkout you can still pay '
                  'using any method Razorpay supports — cards, UPI, netbanking, or wallets.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _MethodType { upi, card }

class _PaymentMethod {
  final _MethodType type;
  final String label;
  final bool isDefault;

  _PaymentMethod({required this.type, required this.label, required this.isDefault});
}

class _AddUpiSheet extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _AddUpiSheet({required this.onAdd});

  @override
  State<_AddUpiSheet> createState() => _AddUpiSheetState();
}

class _AddUpiSheetState extends State<_AddUpiSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add UPI ID', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'yourname@upi',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final value = _controller.text.trim();
                if (!value.contains('@') || value.length < 5) {
                  setState(() => _error = 'Enter a valid UPI ID');
                  return;
                }
                widget.onAdd(value);
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds a card as a quick shortcut. Deliberately only ever stores/shows a
/// masked "•••• 1234" label locally — the raw card number is never sent
/// anywhere or persisted, since real card capture/tokenization has to go
/// through Razorpay's own Checkout + backend token vault, not a plain form
/// like this. Wire this up to that flow when the backend endpoint exists.
class _AddCardSheet extends StatefulWidget {
  final ValueChanged<String> onAdd;

  const _AddCardSheet({required this.onAdd});

  @override
  State<_AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends State<_AddCardSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Card', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: 19,
            decoration: InputDecoration(
              hintText: '1234 5678 9012 3456',
              prefixIcon: const Icon(Icons.credit_card_rounded),
              errorText: _error,
              counterText: '',
            ),
          ),
          Text(
            'For your safety, only the last 4 digits are saved on this device.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                final digits = _controller.text.replaceAll(RegExp(r'\s'), '');
                if (digits.length < 12 || digits.length > 19 || int.tryParse(digits) == null) {
                  setState(() => _error = 'Enter a valid card number');
                  return;
                }
                widget.onAdd('•••• ${digits.substring(digits.length - 4)}');
              },
              child: const Text('Add'),
            ),
          ),
        ],
      ),
    );
  }
}