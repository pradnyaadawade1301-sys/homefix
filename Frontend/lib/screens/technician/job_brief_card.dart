import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';

/// The technician-facing "Job Brief": everything collected from the customer
/// (guided Q&A, photos/video, AI diagnosis or expert consultation notes)
/// bundled into one scannable card, shown above the Accept/action row so the
/// technician reads the full context before deciding.
///
/// Gracefully degrades: bookings created before this feature (or without a
/// JobBrief) just show the priority badge + attachments, since
/// [Booking.jobBrief] is nullable and [Booking.problemDescription] is always
/// there already (shown separately, above this card).
class JobBriefCard extends StatefulWidget {
  final Booking booking;
  const JobBriefCard({Key? key, required this.booking}) : super(key: key);

  @override
  State<JobBriefCard> createState() => _JobBriefCardState();
}

class _JobBriefCardState extends State<JobBriefCard> {
  // Collapsed by default only for sections that tend to be long; Guided
  // Q&A and the priority header always show.
  bool _attachmentsExpanded = false;
  bool _notesExpanded = true;
  bool _prepExpanded = false;

  // Simple category -> suggested tools/parts mapping. Falls back to a
  // generic toolkit line when the category isn't in the map — this is a
  // "come prepared" nudge, not a hard requirement.
  static const Map<String, List<String>> _prepByCategory = {
    'ac': ['AC testing/gauge set', 'Refrigerant (as needed)', 'Common electrical tester'],
    'air conditioning': ['AC testing/gauge set', 'Refrigerant (as needed)', 'Common electrical tester'],
    'plumbing': ['Pipe wrench set', 'Sealant/tape', 'Common fittings'],
    'electrical': ['Multimeter', 'Insulated tools', 'Common wiring/MCB spares'],
    'carpentry': ['Basic carpentry toolkit', 'Hinges/fasteners'],
    'appliance repair': ['Multimeter', 'Common spare parts for the brand'],
  };

  List<String> _recommendedPrep(String categoryName) {
    final key = categoryName.trim().toLowerCase();
    for (final entry in _prepByCategory.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return ['General toolkit', 'Multimeter', 'Basic spares for common faults'];
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final brief = booking.jobBrief;
    final isUrgent = brief?.isEmergency == true;
    final hasNotes = (brief?.aiDiagnosis?.isNotEmpty ?? false) || (brief?.consultationNotes?.isNotEmpty ?? false);
    final attachmentCount = booking.images.length + (brief?.hasVideo == true ? 1 : 0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isUrgent ? AppTheme.errorColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.15)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_outlined, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text('Job Brief', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isUrgent ? AppTheme.errorColor : AppTheme.successColor).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isUrgent ? '\ud83d\udea8 Urgent' : 'Normal',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isUrgent ? AppTheme.errorColor : AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          if (brief == null || !brief.hasGuidedAnswers) ...[
            const SizedBox(height: 10),
            Text(
              'No guided answers submitted for this job — see the issue description above.',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontStyle: FontStyle.italic),
            ),
          ] else ...[
            const SizedBox(height: 14),
            _sectionLabel('Customer answers'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (brief.startedWhen != null) _factChip(Icons.schedule_outlined, 'Started: ${brief.startedWhen}'),
                if (brief.isContinuous != null)
                  _factChip(Icons.repeat, brief.isContinuous! ? 'Continuous' : 'Occasional'),
                if (brief.previousRepair != null)
                  _factChip(Icons.build_outlined, 'Previous repair: ${brief.previousRepair! ? "Yes" : "No"}'),
                if (brief.categoryAnswers != null)
                  ...brief.categoryAnswers!.values.map((v) => _factChip(Icons.checklist_rtl_rounded, v)),
              ],
            ),
            if (brief.unusualSigns != null && brief.unusualSigns!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(brief.unusualSigns!, style: TextStyle(fontSize: 12.5, color: Colors.grey[800])),
                  ),
                ],
              ),
            ],
          ],
          if (attachmentCount > 0) ...[
            const SizedBox(height: 14),
            _collapsibleHeader(
              icon: Icons.photo_library_outlined,
              label: 'Attachments',
              trailing: '$attachmentCount',
              expanded: _attachmentsExpanded,
              onTap: () => setState(() => _attachmentsExpanded = !_attachmentsExpanded),
            ),
            if (_attachmentsExpanded) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final url in booking.images)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url, width: 72, height: 72, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                    width: 72,
                                    height: 72,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image_outlined, size: 20),
                                  )),
                        ),
                      ),
                    if (brief?.hasVideo == true)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.videocam_outlined, size: 24),
                      ),
                  ],
                ),
              ),
            ],
          ],
          if (hasNotes) ...[
            const SizedBox(height: 14),
            _collapsibleHeader(
              icon: Icons.psychology_outlined,
              label: 'AI / Expert notes',
              expanded: _notesExpanded,
              onTap: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            if (_notesExpanded) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  brief?.consultationNotes?.isNotEmpty == true ? brief!.consultationNotes! : brief!.aiDiagnosis!,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[800]),
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          _collapsibleHeader(
            icon: Icons.build_circle_outlined,
            label: 'Recommended preparation',
            expanded: _prepExpanded,
            onTap: () => setState(() => _prepExpanded = !_prepExpanded),
          ),
          if (_prepExpanded) ...[
            const SizedBox(height: 8),
            ..._recommendedPrep(booking.categoryName).map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 5, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(item, style: TextStyle(fontSize: 12.5, color: Colors.grey[700])),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) =>
      Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.grey[600]));

  Widget _factChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[700]),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey[800], fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _collapsibleHeader({
    required IconData icon,
    required String label,
    required bool expanded,
    required VoidCallback onTap,
    String? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing, style: TextStyle(fontSize: 11.5, color: Colors.grey[500])),
          ],
          const Spacer(),
          Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18, color: Colors.grey[600]),
        ],
      ),
    );
  }
}

/// One-line preview shown in the technician's job LIST (not detail screen),
/// e.g. "AC not cooling, 2 days, urgent" — so the technician gets context
/// while scrolling, without opening every card.
String jobBriefPreviewLine(Booking booking) {
  final brief = booking.jobBrief;
  final parts = <String>[];
  final desc = booking.problemDescription.trim();
  if (desc.isNotEmpty) {
    parts.add(desc.length > 40 ? '${desc.substring(0, 40)}...' : desc);
  }
  if (brief?.startedWhen != null) parts.add(brief!.startedWhen!.toLowerCase());
  if (brief?.isEmergency == true) parts.add('urgent');
  return parts.join(', ');
}