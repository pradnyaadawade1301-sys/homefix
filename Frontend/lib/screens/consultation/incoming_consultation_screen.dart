import 'package:flutter/material.dart';
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
class IncomingConsultationScreen extends StatefulWidget {
  const IncomingConsultationScreen({Key? key}) : super(key: key);

  @override
  State<IncomingConsultationScreen> createState() => _IncomingConsultationScreenState();
}

class _IncomingConsultationScreenState extends State<IncomingConsultationScreen> {
  String? _joiningConsultationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsultationProvider>().loadPending();
    });
  }

  Future<void> _accept(String consultationId) async {
    setState(() => _joiningConsultationId = consultationId);
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