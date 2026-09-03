import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart' show FlutterRingtonePlayer;
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../services/signaling_service.dart';
import '../video_call_screen.dart';

/// Technician side of the Live Video Consultation flow — lists consultation
/// requests currently waiting for a response (GET /consultations/pending) and
/// lets the technician accept or reject each one. Accepting fetches the call's
/// room_id + ICE servers and opens the real WebRTC [VideoCallScreen].
///
/// Rings (device ringtone, looping) for as long as there's at least one
/// pending request on screen, and stops the moment the list empties out
/// (accepted/rejected/expired) or this screen is left.
class IncomingConsultationScreen extends StatefulWidget {
  const IncomingConsultationScreen({Key? key}) : super(key: key);

  @override
  State<IncomingConsultationScreen> createState() => _IncomingConsultationScreenState();
}

class _IncomingConsultationScreenState extends State<IncomingConsultationScreen> {
  String? _joiningConsultationId;
  bool _ringing = false;
  // Without this, a request that arrives AFTER the technician has already
  // opened this screen would never show up — loadPending() only ran once,
  // in initState, so the list looked "empty" until a manual pull-to-refresh.
  // Poll in the background (same 6s interval as the jobs dashboard's
  // consultation banner) so a new request appears — and stays visible/rings
  // — on this screen without the technician having to do anything.
  Timer? _pollTimer;

  void _syncRingtone(bool hasPending) {
    if (hasPending && !_ringing) {
      _ringing = true;
      FlutterRingtonePlayer().playRingtone(looping: true, volume: 1.0, asAlarm: false);
    } else if (!hasPending && _ringing) {
      _ringing = false;
      FlutterRingtonePlayer().stop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadPending();
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _pollPending());
  }

  Future<void> _pollPending() async {
    // Skip a poll tick while mid-accept/join or the screen is gone — avoids
    // yanking the list out from under an in-progress action.
    if (!mounted || _joiningConsultationId != null) return;
    try {
      await context.read<ConsultationProvider>().fetchPendingRequests();
    } catch (_) {
      // Silent — this is a background refresh; the next tick will retry,
      // and any real error is already surfaced by the manual pull-to-refresh.
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_ringing) {
      FlutterRingtonePlayer().stop();
    }
    super.dispose();
  }

  Future<void> _accept(String consultationId) async {
    setState(() => _joiningConsultationId = consultationId);
    _syncRingtone(false);
    try {
      final provider = context.read<ConsultationProvider>();
      await provider.acceptRequest(consultationId);
      final withCallInfo = await provider.getCallInfo(consultationId);
      // Fresh, not cached-from-login token — see AuthProvider.getValidAccessToken.
      final token = await context.read<AuthProvider>().getValidAccessToken();
      final myId = context.read<AuthProvider>().currentUser?.id ?? '';

      if (token == null || withCallInfo.roomId == null) {
        throw Exception('Could not join the call. Please try again.');
      }

      final signaling = SignalingService(
        serverUrl: ApiConfig.wsCallUrl(withCallInfo.roomId!, token),
        userId: myId,
        isDirectUrl: true,
      );
      signaling.connect();

      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          signaling: signaling,
          myId: myId,
          peerId: withCallInfo.customerId,
          isCaller: false,
          iceServers: withCallInfo.iceServers.map((s) => s.toMap()).toList(),
          consultationId: consultationId,
          categoryId: withCallInfo.categoryId,
          categoryName: withCallInfo.categoryName,
          customerName: withCallInfo.customerName,
        ),
      ));
      if (mounted) context.read<ConsultationProvider>().loadPending();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _joiningConsultationId = null);
    }
  }

  Future<void> _reject(String consultationId) async {
    _syncRingtone(false);
    try {
      await context.read<ConsultationProvider>().rejectRequest(consultationId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consultation Requests')),
      body: RefreshIndicator(
        onRefresh: () => context.read<ConsultationProvider>().loadPending(),
        child: Consumer<ConsultationProvider>(
          builder: (context, provider, _) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _syncRingtone(provider.pendingRequests.isNotEmpty);
            });
            if (provider.isLoadingPending && provider.pendingRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            if (provider.pendingRequests.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  Padding(
                    padding: EdgeInsets.only(top: 120),
                    child: Center(child: Text('No pending requests right now.')),
                  ),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.pendingRequests.length,
              itemBuilder: (context, i) {
                final req = provider.pendingRequests[i];
                final joining = _joiningConsultationId == req.consultationId;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                                             Text(req.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(req.categoryName, style: TextStyle(color: Colors.grey[600])),
                        if (req.customerNote != null && req.customerNote!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(req.customerNote!, style: const TextStyle(fontSize: 13)),
                        ],
                        if (req.customerArea != null && req.customerArea!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(req.customerArea!, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                        if (req.aiAssessment != null && req.aiAssessment!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.auto_awesome_outlined, size: 15, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    req.aiAssessment!,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: joining ? null : () => _reject(req.consultationId),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: joining ? null : () => _accept(req.consultationId),
                                child: joining
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Accept'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}