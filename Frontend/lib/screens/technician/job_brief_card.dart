import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';

/// Shows everything the customer provided before the technician arrives —
/// the guided pre-job questionnaire answers (see [JobBrief]), any AI
/// diagnosis or video-consultation notes carried over, and photos the
/// customer attached to the booking. Used on [TechnicianJobDetailScreen].
///
/// Renders nothing but an empty-state message if the booking has neither a
/// [JobBrief] nor any [Booking.images] — callers already guard on this via
/// `if (current.jobBrief != null || current.images.isNotEmpty)`, but this
/// widget stays defensive on its own too.
class JobBriefCard extends StatelessWidget {
  final Booking booking;
  const JobBriefCard({Key? key, required this.booking}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final brief = booking.jobBrief;
    final images = booking.images;

    if (brief == null && images.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              Text('Job Brief', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.grey[800])),
            ],
          ),
          const SizedBox(height: 12),

          if (brief != null && brief.hasVideo) _flagChip('📹 Video consultation done', AppTheme.primaryColor),

          if (brief != null && brief.hasGuidedAnswers) ...[
            const SizedBox(height: 4),
            Text('Customer answers', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 8),
            _answerRow('When did it start?', brief.startedWhen),
            _answerRow('Is it continuous or occasional?', _yesNoUnknown(brief.isContinuous, yes: 'Continuous', no: 'Occasional')),
            _answerRow('Any previous repair attempts?', _yesNoUnknown(brief.previousRepair)),
            _answerRow('Emergency?', _yesNoUnknown(brief.isEmergency)),
            _answerRow('Unusual signs noticed', brief.unusualSigns),
          ],

          if (brief != null && (brief.aiDiagnosis?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 14),
            _notesBlock(
              icon: Icons.psychology_outlined,
              label: 'AI Diagnosis',
              text: brief.aiDiagnosis!,
            ),
          ],

          if (brief != null && (brief.consultationNotes?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 14),
            _notesBlock(
              icon: Icons.videocam_outlined,
              label: 'Consultation Notes',
              text: brief.consultationNotes!,
            ),
          ],

          if (brief == null || (!brief.hasGuidedAnswers && !brief.hasVideo && (brief.aiDiagnosis?.isEmpty ?? true) && (brief.consultationNotes?.isEmpty ?? true))) ...[
            if (images.isEmpty)
              Text(
                'No additional details provided by the customer.',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[500], fontStyle: FontStyle.italic),
              ),
          ],

          if (images.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Photos (${images.length})', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.grey[600])),
            const SizedBox(height: 8),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _openFullImage(context, images[i]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      images[i],
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 84,
                        height: 84,
                        color: Colors.grey[200],
                        child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          width: 84,
                          height: 84,
                          color: Colors.grey[100],
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _yesNoUnknown(bool? value, {String yes = 'Yes', String no = 'No'}) {
    if (value == null) return null;
    return value ? yes : no;
  }

  Widget _answerRow(String question, String? answer) {
    if (answer == null || answer.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 4),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                children: [
                  TextSpan(text: '$question ', style: TextStyle(color: Colors.grey[600])),
                  TextSpan(text: answer, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notesBlock({required IconData icon, required String label, required String text}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppTheme.primaryColor),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.primaryColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(text, style: TextStyle(fontSize: 13, color: Colors.grey[800], height: 1.4)),
        ],
      ),
    );
  }

  Widget _flagChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }

  void _openFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: Image.network(
            url,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
          ),
        ),
      ),
    );
  }
}