package com.homefixlive.homefix_live

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Owns the Google Pay / UPI intent launch directly (via startActivityForResult) so
 * the app doesn't depend on a third-party plugin for something this security-
 * sensitive — a prior attempt (the `upi_india` package) turned out to be
 * unmaintained and incompatible with this project's Android Gradle toolchain
 * (its build.gradle calls the long-removed `jcenter()` repository method), so this
 * channel replaces it with code we own and can actually build/maintain.
 *
 * Protocol: Dart calls "launchUpiPayment" with {pa, pn, tr, tn, am, cu, package}.
 * The result is the raw response string the UPI app returns (same
 * "key=value&key2=value2..." shape GPay/PhonePe/Paytm all use — parsed on the Dart
 * side, see lib/services/upi_channel_service.dart), or a PlatformException with
 * code "app_not_installed" / "user_cancelled" / "no_result".
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.homefixlive.homefix_live/upi"
    private val requestCode = 55231
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method != "launchUpiPayment") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val pa = call.argument<String>("pa")
            val pn = call.argument<String>("pn")
            val tr = call.argument<String>("tr")
            val tn = call.argument<String>("tn") ?: ""
            val am = call.argument<String>("am")
            val cu = call.argument<String>("cu") ?: "INR"
            val packageName = call.argument<String>("package")

            if (pa == null || pn == null || tr == null || am == null) {
                result.error("invalid_parameters", "pa, pn, tr, and am are required", null)
                return@setMethodCallHandler
            }

            val uri = Uri.parse("upi://pay")
                .buildUpon()
                .appendQueryParameter("pa", pa)
                .appendQueryParameter("pn", pn)
                .appendQueryParameter("tr", tr)
                .appendQueryParameter("tn", tn)
                .appendQueryParameter("am", am)
                .appendQueryParameter("cu", cu)
                .build()

            val intent = Intent(Intent.ACTION_VIEW, uri)
            if (packageName != null) {
                intent.setPackage(packageName)
            }

            try {
                pendingResult = result
                startActivityForResult(intent, requestCode)
            } catch (e: ActivityNotFoundException) {
                pendingResult = null
                result.error("app_not_installed", "No UPI app found to handle this payment", null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return

        val result = pendingResult
        pendingResult = null

        if (result == null) return

        if (resultCode == Activity.RESULT_CANCELED && data == null) {
            result.error("user_cancelled", "Payment was cancelled before completion", null)
            return
        }

        // UPI apps conventionally return the transaction outcome as a single
        // extra named "response" (a "txnId=...&responseCode=...&Status=...&
        // approvalRefNo=...&txnRef=..." string) — GPay, PhonePe, and Paytm all
        // follow this NPCI-derived convention.
        val response = data?.getStringExtra("response") ?: data?.dataString
        if (response == null) {
            result.error("no_result", "UPI app returned no response data", null)
            return
        }
        result.success(response)
    }
}
