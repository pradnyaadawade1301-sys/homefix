import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../models/consultation_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/consultation_provider.dart';
import '../home/technician_list_screen.dart';

/// Shown right after a Live Video Consultation call ends. If the technician
/// sent a post-call recommendation (see TechnicianPostCallScreen), it's shown
/// front-and-center with Accept/Decline. Either way, the customer can also
/// pick a date/time slot and address themselves to turn the consultation
/// into a real on-site booking with the same technician
/// (POST /consultations/:id/escalate), or rate the call and leave without
/// booking.
class PostCallScreen extends StatefulWidget {
  final String consultationId;
  final String categoryId;
  final String categoryName;
  final String? technicianName;

  const PostCallScreen({
    Key? key,
    required this.consultationId,
    required this.categoryId,
    required this.categoryName,
    this.technicianName,
  }) : super(key: key);

  @override
  State<PostCallScreen> createState() => _PostCallScreenState();
}

class _PostCallScreenState extends State<PostCallScreen> {
  final _notesController = TextEditingController();
  String? _selectedAddressId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isBooking = false;
  bool _booked = false;
  int? _rating;

  // The technician's post-call recommendation, if any — fetched separately
  // from the addresses since it lives on the Consultation itself, not
  // something this screen already had.
  Consultation? _consultation;
  bool _isLoadingRecommendation = true;
  bool _isDecliningRecommendation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressProvider>().fetchAddresses();
      _loadRecommendation();
    });
  }

  Future<void> _loadRecommendation() async {
    try {
      final consultation = await context.read<ConsultationProvider>().refreshStatus(widget.consultationId);
      if (!mounted) return;
      setState(() {
        _consultation = consultation;
        _isLoadingRecommendation = false;
      });
    } catch (_) {
      // Non-fatal — the self-serve "Book Visit Slot" flow below still works
      // without knowing about a recommendation.
      if (mounted) setState(() => _isLoadingRecommendation = false);
    }
  }

  Future<void> _declineRecommendation() async {
    setState(() => _isDecliningRecommendation = true);
    try {
      await context.read<ConsultationProvider>().declineRecommendation(widget.consultationId);
      if (!mounted) return;
      setState(() {
        _consultation = _consultation?.copyWith(recommendationStatus: 'declined');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not decline: $e')));
    } finally {
      if (mounted) setState(() => _isDecliningRecommendation = false);
    }
  }

  /// Accepting a recommendation books ASAP (no date/time picker needed —
  /// that's what makes Accept faster than the manual "Book Visit Slot" flow
  /// below) with just an address. The technician's summary/price are filled
  /// in automatically server-side (see ConsultationService.Escalate falling
  /// back to the recommendation when problemDescription/EstimatedPrice
  /// aren't explicitly provided), so this doesn't need to resend them.
  Future<void> _acceptRecommendation() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an address below, then tap Accept again')),
      );
      return;
    }
    setState(() => _isBooking = true);
    try {
      await context.read<ConsultationProvider>().escalateToBooking(
            widget.consultationId,
            addressId: _selectedAddressId!,
          );
      if (!mounted) return;
      setState(() => _booked = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not book the visit: $e')));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _rate(int stars) async {
    setState(() => _rating = stars);
    try {
      await context.read<ConsultationProvider>().rateConsultation(widget.consultationId, rating: stars);
    } catch (_) {
      // Non-blocking — rating failure shouldn't stop the customer from booking.
    }
  }

  Future<void> _bookSlot() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an address')));
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a date for the visit')));
      return;
    }

    final time = _selectedTime ?? TimeOfDay.now();
    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      time.hour,
      time.minute,
    );

    setState(() => _isBooking = true);
    try {
      // Fold the video consultation into the Job Brief the technician sees
      // before Accept — hasVideo:true records that a live call already
      // happened, and the customer's post-call notes (if any) carry over
      // as the consultation notes rather than being lost.
      final consultBrief = JobBrief(
        hasVideo: true,
        consultationNotes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : 'Video consultation completed with ${widget.technicianName ?? 'the technician'} before this visit.',
      );
      await context.read<ConsultationProvider>().escalateToBooking(
            widget.consultationId,
            addressId: _selectedAddressId!,
            problemDescription: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
            notes: consultBrief.encode(),
            scheduledAt: scheduledAt,
          );
      if (!mounted) return;
      setState(() => _booked = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not book the slot: $e')));
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  void _skip() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TechnicianListScreen(categoryId: widget.categoryId, categoryName: widget.categoryName),
      ),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_booked) {
      return Scaffold(
        appBar: AppBar(title: const Text('Call Complete')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 56),
                  const SizedBox(height: 16),
                  const Text('Visit slot booked!', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 6),
                  Text(
                    _selectedDate != null
                        ? 'Scheduled for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            '${_selectedTime != null ? ' at ${_selectedTime!.format(context)}' : ''}'
                        : 'Your technician will visit soon.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) =>
                              TechnicianListScreen(categoryId: widget.categoryId, categoryName: widget.categoryName),
                        ),
                        (route) => route.isFirst,
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Call Complete')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.technicianName != null
                          ? 'Your call with ${widget.technicianName} has ended.'
                          : 'Your video consultation has ended.',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoadingRecommendation) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
            ] else if (_consultation?.hasPendingRecommendation == true) ...[
              _RecommendationCard(
                summary: _consultation!.recommendationSummary ?? '',
                price: _consultation!.recommendationPrice,
                isBooking: _isBooking,
                isDeclining: _isDecliningRecommendation,
                onAccept: _acceptRecommendation,
                onDecline: _declineRecommendation,
              ),
              const SizedBox(height: 18),
            ] else if (_consultation?.recommendationStatus == 'declined') ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You declined the technician\'s recommendation. You can still book a visit slot yourself below.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
            ],
            const Text('How was the call?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => _rate(star),
                  icon: Icon(
                    _rating != null && star <= _rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: const Color(0xFFF5A623),
                    size: 28,
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            const Text('Need an on-site visit? Book a slot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              'Same technician will come home to fix the issue.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select address', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                TextButton.icon(
                  onPressed: () async {
                    await context.read<AddressProvider>().fetchAddresses();
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Consumer<AddressProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.addresses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (provider.addresses.isEmpty) {
                  return Text('No saved addresses yet — add one from your profile.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]));
                }
                return Column(
                  children: provider.addresses.map((a) {
                    final selected = a.id == _selectedAddressId;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedAddressId = a.id),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey[200]!, width: selected ? 1.6 : 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: selected ? AppTheme.primaryColor : Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.label.isNotEmpty ? a.label : 'Address',
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${a.line1}${a.line2 != null && a.line2!.isNotEmpty ? ', ${a.line2}' : ''}, ${a.city}, ${a.state} ${a.pincode}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 18),
            const Text('Preferred date & time', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      _selectedDate == null
                          ? 'Choose date'
                          : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      _selectedTime == null ? 'Choose time' : _selectedTime!.format(context),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Additional notes (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Anything else the technician should know...'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isBooking ? null : _bookSlot,
                child: _isBooking
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Book Visit Slot'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _isBooking ? null : _skip,
                child: const Text('Not now'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The technician's post-call recommendation, front-and-center with an
/// Accept/Decline choice — this is the whole point of PostCallScreen when a
/// recommendation exists, so it's styled to stand out from the plain
/// self-serve "Book Visit Slot" flow below it.
class _RecommendationCard extends StatelessWidget {
  final String summary;
  final double? price;
  final bool isBooking;
  final bool isDeclining;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RecommendationCard({
    required this.summary,
    required this.price,
    required this.isBooking,
    required this.isDeclining,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final busy = isBooking || isDeclining;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.25), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined, size: 18, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text("Technician's recommendation",
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              if (price != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '~₹${price!.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.primaryColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(summary, style: const TextStyle(fontSize: 13.5, height: 1.4)),
          const SizedBox(height: 4),
          Text(
            price != null
                ? 'Suggested price for an on-site visit — the technician may confirm the final cost after inspecting.'
                : 'The technician suggests an on-site visit to look into this further.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : onDecline,
                  child: isDeclining
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Decline'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: busy ? null : onAccept,
                  child: isBooking
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Accept & Book Visit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Pick an address below, then tap Accept.',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}