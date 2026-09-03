import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/dispute_model.dart';
import '../../services/dispute_service.dart';
import '../../services/service_locator.dart' show UploadService;

/// Dispute detail + evidence trail. GET /disputes/:id for the data, POST
/// /disputes/:id/evidence to attach photos/notes. Resolution (refund/reject)
/// is admin-only and shown here read-only once it happens.
class DisputeDetailScreen extends StatefulWidget {
  final String disputeId;
  const DisputeDetailScreen({Key? key, required this.disputeId}) : super(key: key);

  @override
  State<DisputeDetailScreen> createState() => _DisputeDetailScreenState();
}

class _DisputeDetailScreenState extends State<DisputeDetailScreen> {
  final _picker = ImagePicker();
  late Future<DisputeDetail> _future;
  bool _uploadingEvidence = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<DisputeService>().getDetail(widget.disputeId);
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  Future<void> _addEvidence() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    if (!mounted) return;

    final note = await _promptNote();
    if (!mounted) return;

    setState(() {
      _uploadingEvidence = true;
      _uploadError = null;
    });

    try {
      final uploadService = context.read<UploadService>();
      final url = await uploadService.uploadFile(File(picked.path));
      if (!mounted) return;
      await context.read<DisputeService>().addEvidence(
            disputeId: widget.disputeId,
            fileUrl: url,
            note: note,
          );
      if (!mounted) return;
      await _refresh();
    } catch (e) {
      setState(() => _uploadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<String?> _promptNote() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add a note (optional)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'What does this photo show?'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(null),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispute Details')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<DisputeDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text('Failed to load: ${snapshot.error}')),
                ],
              );
            }
            final detail = snapshot.data!;
            final d = detail.dispute;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            d.bookingId != null ? 'Booking Dispute' : 'Consultation Dispute',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          _StatusPill(status: d.status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Reason', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(d.reason),
                    ],
                  ),
                ),
                if (d.isResolved) ...[
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Resolution', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        if (d.refundAmount != null)
                          Text('Refund amount: ₹${d.refundAmount!.toStringAsFixed(2)}'),
                        if (d.adminNotes != null && d.adminNotes!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(d.adminNotes!),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Evidence', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    TextButton.icon(
                      onPressed: _uploadingEvidence ? null : _addEvidence,
                      icon: _uploadingEvidence
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                if (_uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_uploadError!, style: const TextStyle(color: AppTheme.errorColor)),
                  ),
                if (detail.evidence.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No evidence added yet', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: detail.evidence.length,
                    itemBuilder: (context, index) => _EvidenceTile(evidence: detail.evidence[index]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.lightOutline),
      ),
      child: child,
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final DisputeEvidence evidence;
  const _EvidenceTile({required this.evidence});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        color: Colors.black12,
        child: Column(
          children: [
            Expanded(
              child: Image.network(
                evidence.fileUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
              ),
            ),
            if (evidence.note != null && evidence.note!.isNotEmpty)
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  evidence.note!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'open' => (AppTheme.warningColor, 'Open'),
      'under_review' => (AppTheme.infoColor, 'Under Review'),
      'resolved_refund' => (AppTheme.successColor, 'Refunded'),
      'resolved_partial' => (AppTheme.successColor, 'Partial Refund'),
      'resolved_rejected' => (AppTheme.errorColor, 'Rejected'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}