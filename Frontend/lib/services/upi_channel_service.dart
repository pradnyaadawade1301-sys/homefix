import 'package:flutter/services.dart';

/// Status values a UPI app can report back — mirrors the NPCI-derived convention
/// every major UPI app (GPay, PhonePe, Paytm) uses in its response string.
class UpiPaymentStatus {
  static const String success = 'SUCCESS';
  static const String failure = 'FAILURE';
  static const String submitted = 'SUBMITTED';
  static const String other = 'OTHER';
}

/// The parsed response from a UPI app after `UpiChannelService.pay` returns.
class UpiChannelResponse {
  final String? transactionId;
  final String? responseCode;
  final String? approvalRefNo;
  final String status;

  UpiChannelResponse({
    required this.transactionId,
    required this.responseCode,
    required this.approvalRefNo,
    required this.status,
  });

  /// Parses the raw "key=value&key2=value2..." string every UPI app returns.
  factory UpiChannelResponse.parse(String raw) {
    String? txnId, responseCode, approvalRefNo;
    String status = UpiPaymentStatus.other;

    for (final part in raw.split('&')) {
      final kv = part.split('=');
      if (kv.length < 2) continue;
      final key = kv[0].toLowerCase();
      final value = Uri.decodeComponent(kv.sublist(1).join('='));
      if (value.isEmpty || value.toLowerCase() == 'null') continue;

      switch (key) {
        case 'txnid':
          txnId = value;
          break;
        case 'responsecode':
          responseCode = value;
          break;
        case 'approvalrefno':
          approvalRefNo = value;
          break;
        case 'status':
          final v = value.toLowerCase();
          if (v.contains('success')) {
            status = UpiPaymentStatus.success;
          } else if (v.contains('fail')) {
            status = UpiPaymentStatus.failure;
          } else if (v.contains('submit')) {
            status = UpiPaymentStatus.submitted;
          }
          break;
      }
    }

    return UpiChannelResponse(
      transactionId: txnId,
      responseCode: responseCode,
      approvalRefNo: approvalRefNo,
      status: status,
    );
  }
}

/// Thrown when the UPI app can't complete the payment for a known reason
/// (not installed / user backed out) — distinguished from an unexpected error so
/// the payment screen can show the right message.
class UpiChannelException implements Exception {
  final String code; // "app_not_installed" | "user_cancelled" | "no_result" | ...
  final String message;
  UpiChannelException(this.code, this.message);

  @override
  String toString() => 'UpiChannelException($code): $message';
}

/// Launches Google Pay (or any UPI app) via Android's startActivityForResult —
/// not a fire-and-forget deep link — so the app gets back the UPI app's OWN
/// reported outcome (see MainActivity.kt). Replaces the `upi_india` package,
/// which turned out to be unmaintained and incompatible with this project's
/// Android Gradle toolchain.
class UpiChannelService {
  static const _channel = MethodChannel('com.homefixlive.homefix_live/upi');

  /// GPay's own Android package — setting this makes Android open GPay directly
  /// instead of showing the generic UPI app chooser (matches "Clicking Pay should
  /// directly open Google Pay"). Falls back to the chooser if GPay isn't found by
  /// passing null instead.
  static const String googlePayPackage = 'com.google.android.apps.nbu.paisa.user';

  Future<UpiChannelResponse> pay({
    required String payeeVpa,
    required String payeeName,
    required String transactionRef,
    required String note,
    required double amount,
    String currency = 'INR',
    String? appPackage = googlePayPackage,
  }) async {
    try {
      final raw = await _channel.invokeMethod<String>('launchUpiPayment', {
        'pa': payeeVpa,
        'pn': payeeName,
        'tr': transactionRef,
        'tn': note,
        'am': amount.toStringAsFixed(2),
        'cu': currency,
        'package': appPackage,
      });
      if (raw == null) {
        throw UpiChannelException('no_result', 'UPI app returned no response data');
      }
      return UpiChannelResponse.parse(raw);
    } on PlatformException catch (e) {
      throw UpiChannelException(e.code, e.message ?? 'UPI payment failed');
    }
  }
}
