import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/ai_provider.dart';

/// What the customer entered before requesting a video call — handed
/// straight through to ConsultationProvider.requestConsultation as
/// note/area/aiDiagnosisSessionId.
class VideoCallPreCheckResult {
  final String note;
  final String? area;
  final String? aiDiagnosisSessionId;
  const VideoCallPreCheckResult({required this.note, this.area, this.aiDiagnosisSessionId});
}

/// Shown right before a "Video Call" / "Schedule for later" request goes
/// out, so the technician isn't asked to accept/decline blind. Collects:
///  - a one-line problem description (required)
///  - a short area/city (optional, NOT a full address — the call is remote)
///  - silently carries along the customer's current AI Diagnosis session id
///    (AIProvider.session), if they ran one for this issue, so the backend
///    can resolve it into a read-only assessment for the technician.
///
/// Returns null if the customer backs out.
Future<VideoCallPreCheckResult?> showVideoCallPreCheckSheet(
  BuildContext context, {
  String? initialDescription,
}) {
  return showModalBottomSheet<VideoCallPreCheckResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VideoCallPreCheckSheet(initialDescription: initialDescription),
  );
}

class _VideoCallPreCheckSheet extends StatefulWidget {
  final String? initialDescription;
  const _VideoCallPreCheckSheet({this.initialDescription});

  @override
  State<_VideoCallPreCheckSheet> createState() => _VideoCallPreCheckSheetState();
}

class _VideoCallPreCheckSheetState extends State<_VideoCallPreCheckSheet> {
  late final TextEditingController _descriptionController;
  final _areaController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _submit() {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Please describe the problem in a line');
      return;
    }
    final aiSessionId = context.read<AIProvider>().session?.id;
    Navigator.of(context).pop(VideoCallPreCheckResult(
      note: description,
      area: _areaController.text.trim().isEmpty ? null : _areaController.text.trim(),
      aiDiagnosisSessionId: aiSessionId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasAiSession = context.watch<AIProvider>().session != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const Text('Before you call', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'A quick line about the issue helps the technician get straight to the point.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 18),
            const Text('What\'s the problem?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _descriptionController,
              autofocus: widget.initialDescription == null || widget.initialDescription!.isEmpty,
              maxLines: 2,
              maxLength: 140,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              decoration: InputDecoration(
                hintText: 'e.g. Kitchen tap is leaking from the base',
                border: const OutlineInputBorder(),
                errorText: _error,
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            const Text('Your area (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _areaController,
              maxLength: 60,
              decoration: const InputDecoration(
                hintText: 'e.g. Andheri West, Mumbai',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            if (hasAiSession) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_outlined, size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your AI Diagnosis chat for this issue will be shared with the technician too.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}