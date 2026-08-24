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
class SearchingTechnicianScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? note;
  final String? preferredTechnicianId;
  final String? preferredTechnicianName;

  const SearchingTechnicianScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    this.note,
    this.preferredTechnicianId,
    this.preferredTechnicianName,
  }) : super(key: key);

  @override
  State<SearchingTechnicianScreen> createState() => _SearchingTechnicianScreenState();
}

class _SearchingTechnicianScreenState extends State<SearchingTechnicianScreen> {
  bool _joining = false;
  Timer? _pollTimer;

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
      await provider.requestConsultation(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        note: widget.note,
        preferredTechnicianId: widget.preferredTechnicianId,
      );
      // Start polling after the request is created
      final consultation = provider.current;
      if (consultation != null) {
        _startPolling(consultation.id);
      }
    } catch (_) {
      // Error is already set on provider, UI will show it
    }
  }

  void _startPolling(String consultationId) {
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
      } catch (_) {
        // Transient network error — keep polling
      }
    });
  }

  Future<void> _joinCall(Consultation consultation) async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      final provider = context.read<ConsultationProvider>();
      final withCallInfo = await provider.getCallInfo(consultation.id);
      final token = context.read<AuthProvider>().accessToken;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Consumer<ConsultationProvider>(
          builder: (context, provider, _) {
            final consultation = provider.current;
            final status = consultation?.status;

            // Technician accepted — join the call as soon as we see it.
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
