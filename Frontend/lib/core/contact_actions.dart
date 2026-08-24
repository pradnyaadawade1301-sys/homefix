import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared "contact the other side of a booking" actions (call + WhatsApp),
/// used by the customer's booking screens and the technician's jobs screen
/// so the behaviour/error-handling stays identical everywhere.

/// Normalizes a stored phone number (e.g. "9999999999" or "+91 99999 99999")
/// into a bare digits string with an Indian country code, for wa.me links.
String _toWhatsAppNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 10) return '91$digits';
  if (digits.length == 11 && digits.startsWith('0')) return '91${digits.substring(1)}';
  return digits; // already has a country code (or an unusual format)
}

/// Opens the phone's dialer with [phone] pre-filled (Android's ACTION_DIAL
/// behaviour for a `tel:` URI) so the user just taps the call button there.
Future<void> callContact(BuildContext context, String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showError(context, 'Could not open the phone dialer on this device.');
    }
  } catch (_) {
    if (context.mounted) {
      _showError(context, 'Could not open the phone dialer on this device.');
    }
  }
}

/// Opens a WhatsApp chat with [phone] directly (via wa.me), optionally with
/// a prefilled [message]. Falls back to a clear error if WhatsApp isn't
/// installed rather than failing silently.
Future<void> openWhatsApp(BuildContext context, String phone, {String? message}) async {
  final number = _toWhatsAppNumber(phone);
  final uri = Uri.https('wa.me', '/$number', message != null ? {'text': message} : null);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      _showError(context, 'WhatsApp isn\'t installed on this device.');
    }
  } catch (_) {
    if (context.mounted) {
      _showError(context, 'WhatsApp isn\'t installed on this device.');
    }
  }
}

void _showError(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}