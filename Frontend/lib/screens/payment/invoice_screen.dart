import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../../core/theme.dart';
import '../../models/payment_model.dart';
import '../../providers/payment_provider.dart';

/// Shows the full GST-compliant invoice for a paid booking — service ID,
/// base amount, CGST, SGST, total — and lets the customer download/share it
/// as a PDF. Opened automatically right after a successful payment (see
/// PaymentScreen._buildSuccess), and reachable again later from Payment
/// History for any past paid booking.
class InvoiceScreen extends StatefulWidget {
  final String paymentId;
  const InvoiceScreen({Key? key, required this.paymentId}) : super(key: key);

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() => context.read<PaymentProvider>().loadInvoice(widget.paymentId);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Invoice'),
        actions: [
          Consumer<PaymentProvider>(
            builder: (context, provider, _) {
              if (provider.invoice == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Share PDF',
                onPressed: () => _sharePdf(provider.invoice!),
              );
            },
          ),
        ],
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingInvoice && provider.invoice == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null && provider.invoice == null) {
            return _ErrorState(message: provider.error!, onRetry: _load);
          }
          final invoice = provider.invoice;
          if (invoice == null) {
            return const Center(child: Text('Invoice not available'));
          }
          return _InvoiceBody(invoice: invoice);
        },
      ),
      bottomNavigationBar: Consumer<PaymentProvider>(
        builder: (context, provider, _) {
          if (provider.invoice == null) return const SizedBox.shrink();
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _downloadPdf(provider.invoice!),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Download PDF'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Actually saves the PDF to the device (app's document storage, which
  /// needs no runtime permission on any Android version) and immediately
  /// opens it in the phone's default PDF viewer — a real "download", not
  /// just the OS print-preview dialog the old implementation showed.
  Future<void> _downloadPdf(InvoiceDetail invoice) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final doc = await _buildPdf(invoice);
      final bytes = await doc.save();
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'Invoice-${invoice.invoiceNumber}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        // No PDF viewer could open it directly — fall back to the share
        // sheet so the customer can still save/view it another way.
        if (!mounted) return;
        messenger.showSnackBar(SnackBar(content: Text('Saved as $fileName. Opening it needs a PDF viewer app.')));
        await Printing.sharePdf(bytes: bytes, filename: fileName);
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('Could not download invoice: $e')));
    }
  }

  Future<void> _sharePdf(InvoiceDetail invoice) async {
    final doc = await _buildPdf(invoice);
    await Printing.sharePdf(bytes: await doc.save(), filename: 'Invoice-${invoice.invoiceNumber}.pdf');
  }

  Future<pw.Document> _buildPdf(InvoiceDetail inv) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');
    const teal = PdfColor.fromInt(0xFF0F766E);

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('HomeFix Live', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: teal)),
                      pw.SizedBox(height: 2),
                      pw.Text('Smart Home Services, Trusted Professionals', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('TAX INVOICE', style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text(inv.invoiceNumber, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 12),

              // Service ID + date
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _pdfLabelValue('Service ID', inv.serviceCode),
                  _pdfLabelValue('Date', dateFmt.format(inv.paidAt)),
                ],
              ),
              pw.SizedBox(height: 16),

              // Customer / technician
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Billed to', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 3),
                        pw.Text(inv.customerName, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                        if (inv.customerPhone.isNotEmpty) pw.Text(inv.customerPhone, style: const pw.TextStyle(fontSize: 10)),
                        if (inv.addressFormatted.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 3),
                            child: pw.Text(inv.addressFormatted, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          ),
                      ],
                    ),
                  ),
                  if (inv.technicianName.isNotEmpty)
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Service by', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 3),
                          pw.Text(inv.technicianName, style: const pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          if (inv.technicianPhone.isNotEmpty) pw.Text(inv.technicianPhone, style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Line items table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4)},
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _pdfCell('Description', bold: true),
                      _pdfCell('Amount', bold: true, alignRight: true),
                    ],
                  ),
                  pw.TableRow(children: [
                    _pdfCell(inv.categoryName.isNotEmpty ? inv.categoryName : 'Service charge'),
                    _pdfCell('Rs. ${inv.baseAmount.toStringAsFixed(2)}', alignRight: true),
                  ]),
                  if (inv.isRepeatCustomer && inv.repeatDiscountAmount != null)
                    pw.TableRow(children: [
                      _pdfCell('Repeat customer discount (${inv.repeatDiscountPercent?.toStringAsFixed(0) ?? ''}%)'),
                      _pdfCell('-Rs. ${inv.repeatDiscountAmount!.toStringAsFixed(2)}', alignRight: true),
                    ]),
                  pw.TableRow(children: [
                    _pdfCell('CGST (${inv.cgstPercent.toStringAsFixed(1)}%)'),
                    _pdfCell('Rs. ${inv.cgstAmount.toStringAsFixed(2)}', alignRight: true),
                  ]),
                  pw.TableRow(children: [
                    _pdfCell('SGST (${inv.sgstPercent.toStringAsFixed(1)}%)'),
                    _pdfCell('Rs. ${inv.sgstAmount.toStringAsFixed(2)}', alignRight: true),
                  ]),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      _pdfCell('Total Paid', bold: true),
                      _pdfCell('Rs. ${inv.totalAmount.toStringAsFixed(2)}', bold: true, alignRight: true),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Total GST: Rs. ${inv.gstTotal.toStringAsFixed(2)}',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
                ),
              ),

              pw.SizedBox(height: 24),
              if (inv.problemDescription.isNotEmpty) ...[
                pw.Text('Issue reported', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 3),
                pw.Text(inv.problemDescription, style: const pw.TextStyle(fontSize: 10)),
                pw.SizedBox(height: 16),
              ],

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 6),
              pw.Text(
                'Payment ID: ${inv.payment.razorpayPaymentId ?? inv.payment.transactionRef}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
              pw.Text(
                'This is a system-generated invoice and does not require a signature.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              ),
            ],
          );
        },
      ),
    );

    return doc;
  }

  pw.Widget _pdfLabelValue(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2),
        pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
      ],
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Align(
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
        child: pw.Text(text, style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      ),
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  final InvoiceDetail invoice;
  const _InvoiceBody({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d MMM yyyy, h:mm a');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Success banner
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.successColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.successColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const CircleAvatar(radius: 20, backgroundColor: AppTheme.successColor, child: Icon(Icons.check_rounded, color: Colors.white)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payment successful', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(dateFmt.format(invoice.paidAt), style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Service ID + invoice number card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.lightOutline),
          ),
          child: Row(
            children: [
              Expanded(child: _labelValue('Service ID', invoice.serviceCode)),
              Container(width: 1, height: 32, color: AppTheme.lightOutline),
              const SizedBox(width: 16),
              Expanded(child: _labelValue('Invoice No.', invoice.invoiceNumber)),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Service + people
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.lightOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invoice.categoryName.isNotEmpty ? invoice.categoryName : 'Service', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (invoice.problemDescription.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(invoice.problemDescription, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ],
              const Divider(height: 24),
              _personRow(Icons.person_outline_rounded, 'Billed to', invoice.customerName, invoice.customerPhone),
              if (invoice.technicianName.isNotEmpty) ...[
                const SizedBox(height: 10),
                _personRow(Icons.build_outlined, 'Service by', invoice.technicianName, invoice.technicianPhone),
              ],
              if (invoice.addressFormatted.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 6),
                    Expanded(child: Text(invoice.addressFormatted, style: TextStyle(fontSize: 12.5, color: Colors.grey[700]))),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Price breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.lightOutline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bill details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 14),
              _priceRow('Service amount', invoice.baseAmount),
              if (invoice.isRepeatCustomer && invoice.repeatDiscountAmount != null)
                _priceRow(
                  'Repeat customer discount (${invoice.repeatDiscountPercent?.toStringAsFixed(0) ?? ''}%)',
                  -(invoice.repeatDiscountAmount ?? 0),
                  color: AppTheme.successColor,
                ),
              _priceRow('CGST (${invoice.cgstPercent.toStringAsFixed(1)}%)', invoice.cgstAmount),
              _priceRow('SGST (${invoice.sgstPercent.toStringAsFixed(1)}%)', invoice.sgstAmount),
              const Divider(height: 24),
              _priceRow('Total paid', invoice.totalAmount, bold: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Text(
          'Payment ID: ${invoice.payment.razorpayPaymentId ?? invoice.payment.transactionRef}',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _labelValue(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _personRow(IconData icon, String label, String name, String phone) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10.5, color: Colors.grey[500])),
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (phone.isNotEmpty) Text(phone, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
      ],
    );
  }

  Widget _priceRow(String label, double amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: bold ? 15 : 13.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w400, color: color)),
          Text(
            '${amount < 0 ? '-' : ''}\u20B9${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(fontSize: bold ? 16 : 13.5, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.errorColor),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}