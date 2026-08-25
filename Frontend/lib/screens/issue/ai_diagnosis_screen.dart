import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/ai_provider.dart';
import '../home/technician_list_screen.dart';
import '../consultation/searching_technician_screen.dart';

/// Steps 4-5 of the customer flow: AI Diagnosis chat (backed by the real Groq
/// endpoint) followed by the customer's decision — Live Video Consultation or
/// Book Technician Visit. Chat starts pre-seeded (see IssueDetailsScreen) with
/// the customer's issue title/description/image URLs as the first message.
class AIDiagnosisScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String problemDescription;

  const AIDiagnosisScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    required this.problemDescription,
  }) : super(key: key);

  @override
  State<AIDiagnosisScreen> createState() => _AIDiagnosisScreenState();
}

class _AIDiagnosisScreenState extends State<AIDiagnosisScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await context.read<AIProvider>().sendMessage(text);
    _scrollToBottom();
  }

  void _openLiveConsultation() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchingTechnicianScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        note: widget.problemDescription,
      ),
    ));
  }

  // "Book Technician Visit" opens the technician browse/select list for this
  // category (not the address form directly) — the customer picks who they
  // want, sees their profile, then taps Book Now there. That's what actually
  // assigns a technician today, since automatic nearest-technician assignment
  // isn't implemented on the backend yet.
  void _bookTechnician() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TechnicianListScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        problemDescription: widget.problemDescription,
      ),
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Tries to parse the AI message content as the structured diagnosis JSON.
  /// Returns null if the content isn't valid JSON (i.e. it's a normal chat
  /// reply / follow-up answer), so we know to just render it as plain text.
  Map<String, dynamic>? _tryParseDiagnosis(String content) {
    final trimmed = content.trim();
    if (!trimmed.startsWith('{') || !trimmed.endsWith('}')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  Widget _buildDiagnosisCard(Map<String, dynamic> data) {
    final fault = data['possible_fault']?.toString();
    final causes = (data['causes'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final followUps = (data['follow_up_questions'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final confidence = data['confidence_score'];
    final costMin = data['estimated_cost_min'];
    final costMax = data['estimated_cost_max'];
    final timeMinutes = data['estimated_time_minutes'];
    final canSolveRemotely = data['can_solve_remotely'];
    final recommendation = data['recommendation']?.toString();

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fault != null) ...[
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, size: 18, color: AppTheme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    fault,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                if (confidence != null) _confidenceBadge(confidence),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (causes.isNotEmpty) ...[
            const Text('Likely causes', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 4),
            ...causes.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('•  ', style: TextStyle(fontSize: 13)),
                      Expanded(child: Text(c, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
            const SizedBox(height: 10),
          ],
          if (costMin != null && costMax != null || timeMinutes != null) ...[
            Row(
              children: [
                if (costMin != null && costMax != null)
                  Expanded(child: _infoChip(Icons.currency_rupee, '₹$costMin - ₹$costMax')),
                if (costMin != null && costMax != null && timeMinutes != null)
                  const SizedBox(width: 8),
                if (timeMinutes != null)
                  Expanded(child: _infoChip(Icons.schedule, '~$timeMinutes min')),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (followUps.isNotEmpty) ...[
            const Text('A couple of quick questions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.black54)),
            const SizedBox(height: 4),
            ...followUps.map((q) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(q, style: const TextStyle(fontSize: 13)),
                )),
            const SizedBox(height: 6),
          ],
          if (recommendation != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: canSolveRemotely == true ? Colors.green[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                canSolveRemotely == true
                    ? 'This may be fixable remotely'
                    : 'Recommended: onsite technician visit',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: canSolveRemotely == true ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _confidenceBadge(dynamic confidence) {
    final value = confidence is num ? confidence.toInt() : 0;
    Color color = value >= 70 ? Colors.green : (value >= 40 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$value%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryColor),
          const SizedBox(width: 4),
          Flexible(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Diagnosis')),
      body: SafeArea(
        child: Consumer<AIProvider>(
          builder: (context, ai, _) {
            if (ai.isStarting && ai.messages.isEmpty) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            if (ai.error != null && !ai.isSending && ai.messages.every((m) => m.isUser)) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        'AI diagnosis is unavailable right now.\n${ai.error}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'You can still book a technician directly.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _bookTechnician, child: const Text('Book Technician Visit')),
                    ],
                  ),
                ),
              );
            }

            _scrollToBottom();

            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: ai.messages.length + (ai.isSending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= ai.messages.length) {
                        return const Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: SizedBox(
                              height: 18, width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            ),
                          ),
                        );
                      }
                      final m = ai.messages[i];
                      final diagnosis = m.isUser ? null : _tryParseDiagnosis(m.content);

                      return Align(
                        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: diagnosis == null
                              ? const EdgeInsets.symmetric(horizontal: 14, vertical: 10)
                              : EdgeInsets.zero,
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                          decoration: diagnosis == null
                              ? BoxDecoration(
                                  color: m.isUser ? AppTheme.primaryColor : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(16),
                                )
                              : null,
                          child: diagnosis != null
                              ? _buildDiagnosisCard(diagnosis)
                              : Text(
                                  m.content,
                                  style: TextStyle(color: m.isUser ? Colors.white : Colors.black87, fontSize: 13.5),
                                ),
                        ),
                      );
                    },
                  ),
                ),
                // Decision buttons — step 5 of the spec. Shown once the AI has
                // replied at least once, so the customer has something to act on.
                if (ai.messages.any((m) => !m.isUser))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openLiveConsultation,
                            icon: const Icon(Icons.videocam_outlined, size: 18),
                            label: const Text('Live Consultation', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _bookTechnician,
                            icon: const Icon(Icons.build_rounded, size: 18),
                            label: const Text('Book Technician', style: TextStyle(fontSize: 12.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: 'Ask a follow-up question...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              fillColor: Colors.grey[100],
                              filled: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: ai.isSending ? null : _send,
                          icon: const Icon(Icons.send_rounded, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}