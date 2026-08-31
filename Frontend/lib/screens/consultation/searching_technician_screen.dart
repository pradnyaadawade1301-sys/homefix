import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../services/signaling_service.dart';
import '../video_call_screen.dart';

/// Customer side of the Live Video Consultation flow. Requests a consultation,
/// shows a "searching for technician" state while [ConsultationProvider] polls
/// status, then — once a technician accepts — fetches the call's room_id +
/// ICE servers and opens the real WebRTC [VideoCallScreen].
///
/// IMPORTANT: every "is this scheduled?" check in this file is gated on
/// [scheduledAt] (a value we already know on the client, right from the
/// moment the widget is built) — NOT on the backend's status string. This is
/// intentional: relying on the backend status alone means if the server is
/// ever mid-rollout, stale, or briefly wrong, a scheduled request could look
/// "accepted" and this screen would wrongly jump straight into a live video
/// call. Gating on scheduledAt makes that impossible by construction.
class SearchingTechnicianScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? note;
  final String? preferredTechnicianId;
  final String? preferredTechnicianName;
  // Non-null = "Schedule for Later". When set, this screen must NEVER
  // auto-navigate to VideoCallScreen, no matter what status comes back.
  final DateTime? scheduledAt;

  const SearchingTechnicianScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    this.note,
    this.preferredTechnicianId,
    this.preferredTechnicianName,
    this.scheduledAt,
  }) : super(key: key);

  @override
  State<SearchingTechnicianScreen> createState() => _SearchingTechnicianScreenState();
}

class _SearchingTechnicianScreenState extends State<SearchingTechnicianScreen> {
  bool _joining = false;
  Timer? _pollTimer;

  bool get _isScheduled => widget.scheduledAt != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final provider = context.read<ConsultationProvider>();
      final consultation = await provider.requestConsultation(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        note: widget.note,
        preferredTechnicianId: widget.preferredTechnicianId,
        scheduledAt: widget.scheduledAt,
      );
      // Scheduled requests are stored and left alone — no technician is rung
      // yet, so there is nothing to poll for and definitely nothing to
      // auto-join. Only instant requests start polling for accept/reject.
      if (!_isScheduled) {
        _startPolling(consultation.id);
      }
    } catch (_) {
      // Error is already set on provider, UI will show it
    }
  }

  void _startPolling(String consultationId) {
    if (_isScheduled) return; // belt-and-suspenders: never poll a scheduled request
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final provider = context.read<ConsultationProvider>();
        final updated = await provider.refreshStatus(consultationId);
        // Stop polling once status moves past ringing/searching
        if (updated.status != ConsultationStatus.searching &&
            updated.status != ConsultationStatus.ringing) {
          _pollTimer?.cancel();
        }
      } catch (e) {
        // ignore: avoid_print
        print('SearchingTechnicianScreen: poll failed for $consultationId: $e');
      }
    });
  }

  Future<void> _joinCall(Consultation consultation) async {
    // Hard stop: a scheduled consultation must NEVER reach this method. This
    // check is redundant with the one at the call site in build() below, but
    // is kept here on purpose as a last line of defense.
    if (_isScheduled) return;
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final provider = context.read<ConsultationProvider>();
      final withCallInfo = await provider.getCallInfo(consultation.id);
      // Fresh, not cached-from-login token — see AuthProvider.getValidAccessToken.
      final token = await context.read<AuthProvider>().getValidAccessToken();
      final myId = context.read<AuthProvider>().currentUser?.id ?? '';

      if (token == null || withCallInfo.roomId == null) {
        throw Exception('Could not start the call. Please try again.');
      }

      final signaling = SignalingService(
        serverUrl: ApiConfig.wsCallUrl(withCallInfo.roomId!, token),
        userId: myId,
        isDirectUrl: true,
      );
      signaling.connect();

      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          signaling: signaling,
          myId: myId,
          peerId: withCallInfo.technicianId ?? '',
          isCaller: true,
          iceServers: withCallInfo.iceServers.map((s) => s.toMap()).toList(),
          consultationId: consultation.id,
          categoryId: widget.categoryId,
          categoryName: widget.categoryName,
          technicianName: withCallInfo.technicianName ?? widget.preferredTechnicianName,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      setState(() => _joining = false);
    }
  }

  Future<void> _cancel() async {
    _pollTimer?.cancel();
    final provider = context.read<ConsultationProvider>();
    final consultationId = provider.current?.id;
    if (consultationId != null) {
      try {
        await provider.cancelRequest(consultationId);
      } catch (_) {}
    }
    provider.clearCurrent();
    if (mounted) Navigator.of(context).pop();
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year}, $h:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Consumer<ConsultationProvider>(
          builder: (context, provider, _) {
            final consultation = provider.current;
            final status = consultation?.status;

            // ── Scheduled request: show a fixed confirmation screen and stop.
            // This branch is keyed ONLY on widget.scheduledAt — never on
            // `status` — so it is impossible for a scheduled request to fall
            // through to the auto-join logic below, regardless of what the
            // backend reports.
            if (_isScheduled) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.event_available_rounded, color: Colors.white, size: 56),
                      const SizedBox(height: 20),
                      Text(
                        'Video consultation scheduled for\n${_formatDateTime(widget.scheduledAt!)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "We'll notify you once it's confirmed. You won't be connected to a call automatically.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // ── Instant request flow (unchanged) ────────────────────────────

            // Technician accepted — join the call as soon as we see it.
            // Guarded by !_isScheduled above (whole branch already returned
            // for scheduled requests), so this only ever runs for instant ones.
            if (status == ConsultationStatus.accepted && !_joining && consultation != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => _joinCall(consultation));
            }

            String message;
            if (provider.error != null) {
              message = provider.error!;
            } else if (status == ConsultationStatus.rejected) {
              message = 'The technician declined this request.';
            } else if (status == ConsultationStatus.noTechnician) {
              message = 'No technician is available right now.';
            } else if (_joining || status == ConsultationStatus.accepted) {
              message = 'Connecting your call...';
            } else {
              message = widget.preferredTechnicianName != null
                  ? 'Waiting for ${widget.preferredTechnicianName} to accept...'
                  : 'Searching for an available technician...';
            }

            final failed = status == ConsultationStatus.rejected ||
                status == ConsultationStatus.noTechnician ||
                provider.error != null;

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!failed)
                      const CircularProgressIndicator(color: Colors.white)
                    else
                      const Icon(Icons.error_outline, color: Colors.white70, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    if (failed)
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go Back'),
                      )
                    else
                      OutlinedButton(
                        onPressed: _cancel,
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                        child: const Text('Cancel'),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}