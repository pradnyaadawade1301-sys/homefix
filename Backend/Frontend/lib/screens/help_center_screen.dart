import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Help Center — searchable FAQ list with expandable answers.
class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({Key? key}) : super(key: key);

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  static const List<_Faq> _faqs = [
    _Faq(
      question: 'How do I book a service?',
      answer: 'Go to the Home tab, pick a category, choose a time slot and technician, then confirm your booking. You will get a confirmation once it is accepted.',
    ),
    _Faq(
      question: 'How can I cancel or reschedule a booking?',
      answer: 'Open the booking from the Bookings tab and tap Cancel or Reschedule. Cancellations made close to the appointment time may attract a small fee.',
    ),
    _Faq(
      question: 'What payment methods are accepted?',
      answer: 'You can pay via UPI, cards, or cash to the technician after the job is completed. Manage saved methods under Profile > Payment Methods.',
    ),
    _Faq(
      question: 'How do I contact my technician?',
      answer: 'Once a booking is confirmed, you will see a call/chat option on the booking details screen.',
    ),
    _Faq(
      question: 'Is my personal data safe?',
      answer: 'Yes. Your location and contact details are only shared with the assigned technician during an active booking. See Privacy & Security for more controls.',
    ),
    _Faq(
      question: 'How do refunds work?',
      answer: 'If a booking is cancelled after payment, the refund is processed to your original payment method within 5-7 business days.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _faqs
        : _faqs.where((f) => f.question.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Help Center')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search for help',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text('No results for "$_query"', style: TextStyle(color: Colors.grey[600])),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final faq = filtered[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.lightOutline),
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text(faq.question,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            expandedCrossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(faq.answer,
                                  style: TextStyle(fontSize: 13.5, color: Colors.grey[700], height: 1.4)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq({required this.question, required this.answer});
}