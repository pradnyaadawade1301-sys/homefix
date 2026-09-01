import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/ai_provider.dart';
import '../../providers/booking_provider.dart';
import '../../providers/category_provider.dart';
import '../home/technician_list_screen.dart';
import '../home/technician_detail_screen.dart';
import '../consultation/searching_technician_screen.dart';

/// Steps 4-5 of the customer flow: AI Diagnosis chat (backed by the real Groq
/// endpoint) followed by the customer's decision to Book a Technician Visit.
/// Chat starts pre-seeded (see IssueDetailsScreen) with
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

/// The three ways a customer can proceed once the AI has given its first
/// read on the problem (mirrors the "Possible Options" step of the product
/// spec: Get Instant AI Guidance / Talk to an Expert / Book Technician
/// Directly).
enum _NextStepChoice { aiGuidance, talkToExpert, bookDirect }

class _AIDiagnosisScreenState extends State<AIDiagnosisScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _techniciansRequested = false;

  // Once the AI has replied at least once, we show the "Possible Options"
  // card and wait for the customer to pick a path. Staying null keeps the
  // options card visible; picking "Get Instant AI Guidance" just dismisses
  // it and lets the customer keep chatting on this same screen. The other
  // two choices navigate away immediately.
  _NextStepChoice? _choice;

  void _maybeFetchTechnicians() {
    if (_techniciansRequested) return;
    _techniciansRequested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianProvider>().fetchTechnicians(categoryId: widget.categoryId);
    });
  }

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

  // "Book Technician Visit" opens the technician browse/select list for this
  // category (not the address form directly) — the customer picks who they
  // want, sees their profile, then taps Book Now there. That's what actually
  // assigns a technician today, since automatic nearest-technician assignment
  // isn't implemented on the backend yet.
  /// Folds the AI's latest reply into the pending Job Brief (see
  /// BookingProvider.pendingJobBrief) so it reaches the technician without
  /// the customer re-typing anything. Safe to call even if the customer
  /// never touched the guided questions in IssueDetailsScreen — this just
  /// adds to whatever's already pending.
  void _foldAiDiagnosisIntoBrief() {
    final messages = context.read<AIProvider>().messages;
    final lastAi = messages.where((m) => m.role == 'assistant').toList();
    if (lastAi.isEmpty) return;
    context.read<BookingProvider>().updatePendingJobBrief(
          (current) => current.copyWith(aiDiagnosis: lastAi.last.content),
        );
  }

  void _bookTechnician() {
    _foldAiDiagnosisIntoBrief();
    setState(() => _choice = _NextStepChoice.bookDirect);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TechnicianListScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        problemDescription: widget.problemDescription,
      ),
    ));
  }

  // "Talk to an Expert" opens the live video consultation flow: it requests
  // a consultation and shows a searching/matching state while a technician
  // accepts, then drops the customer straight into the WebRTC call.
  void _talkToExpert() {
    _foldAiDiagnosisIntoBrief();
    setState(() => _choice = _NextStepChoice.talkToExpert);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchingTechnicianScreen(
        categoryId: widget.categoryId,
        categoryName: widget.categoryName,
        note: widget.problemDescription,
      ),
    ));
  }

  // "Get Instant AI Guidance" just dismisses the options card so the
  // customer can keep chatting with the AI right here on this screen.
  void _continueWithAI() {
    setState(() => _choice = _NextStepChoice.aiGuidance);
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
            const Row(
              children: [
                Icon(Icons.build_circle_outlined, size: 18, color: AppTheme.primaryColor),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Here\'s what we found',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (causes.isNotEmpty) ...[
            const Text('What the issue is', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.black54)),
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

  /// "Possible Options" card shown right after the AI's first response:
  /// three clear next steps, colour-coded (green/orange/blue) to match the
  /// product spec.
  Widget _buildOptionsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Possible Options', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 10),
            _OptionRow(
              color: const Color(0xFF4CAF50),
              icon: Icons.bolt_rounded,
              title: 'Get Instant AI Guidance',
              subtitle: 'Keep chatting with AI to try fixing it yourself',
              onTap: _continueWithAI,
            ),
            const SizedBox(height: 10),
            _OptionRow(
              color: const Color(0xFFFF9800),
              icon: Icons.support_agent_rounded,
              title: 'Talk to an Expert',
              subtitle: 'Live video call with a technician right now',
              onTap: _talkToExpert,
            ),
            const SizedBox(height: 10),
            _OptionRow(
              color: const Color(0xFF2196F3),
              icon: Icons.build_rounded,
              title: 'Book Technician Directly',
              subtitle: 'Schedule a visit at a time that works for you',
              onTap: _bookTechnician,
            ),
            const SizedBox(height: 8),
            Text(
              'This gives you the flexibility to choose what works best.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianSuggestions() {
    return Consumer<TechnicianProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.technicians.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 18, width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
            ),
          );
        }
        final techs = provider.technicians.take(3).toList();
        if (techs.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Suggested technicians', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  TextButton(
                    onPressed: _bookTechnician,
                    child: const Text('View all', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...techs.map((t) => _SuggestedTechCard(
                    technician: t,
                    problemDescription: widget.problemDescription,
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assessment')),
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
                        'AI assessment is unavailable right now.\n${ai.error}',
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
                // Step 1 of the spec: once the AI has replied at least once,
                // let the customer choose how to proceed.
                if (ai.messages.any((m) => !m.isUser) && _choice == null)
                  _buildOptionsCard(),
                // After "Get Instant AI Guidance" is picked, keep helping —
                // surface suggested technicians inline too, in case the
                // customer changes their mind mid-chat.
                if (_choice == _NextStepChoice.aiGuidance) ...[
                  Builder(builder: (context) {
                    _maybeFetchTechnicians();
                    return _buildTechnicianSuggestions();
                  }),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _talkToExpert,
                            icon: const Icon(Icons.support_agent_rounded, size: 18),
                            label: const Text('Talk to an Expert', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _bookTechnician,
                            icon: const Icon(Icons.build_rounded, size: 18),
                            label: const Text('Book Directly', style: TextStyle(fontSize: 13)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
/// One row inside the "Possible Options" card: a coloured dot/icon, a
/// title + subtitle, and a chevron — the whole row is tappable.
class _OptionRow extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionRow({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SuggestedTechCard extends StatelessWidget {
  final Technician technician;
  final String? problemDescription;
  const _SuggestedTechCard({required this.technician, this.problemDescription});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianDetailScreen(technician: technician, problemDescription: problemDescription),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
              child: Text(
                technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(technician.name.isNotEmpty ? technician.name : 'Technician',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text('${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount})',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('${technician.experienceYears} yrs exp',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}