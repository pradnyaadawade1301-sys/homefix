import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/booking_provider.dart';
import 'booking_tracking_screen.dart';

/// Step 7 of the customer flow ("Book Technician Flow"): pick/add an address,
/// pick a preferred date + time, add notes, then create the booking.
///
/// Two entry points:
/// - From AI Diagnosis "Book Technician" -> browse technicians -> select one
///   -> [preferredTechnician] is set -> booking is created already assigned
///   ("accepted") to that technician, backend-validated.
/// - Without a preferred technician, the booking starts "requested" (shown as
///   "Pending Assignment") until a technician manually accepts it.
class BookTechnicianScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? problemDescription;
  final Technician? preferredTechnician;

  const BookTechnicianScreen({
    Key? key,
    required this.categoryId,
    required this.categoryName,
    this.problemDescription,
    this.preferredTechnician,
  }) : super(key: key);

  @override
  State<BookTechnicianScreen> createState() => _BookTechnicianScreenState();
}

/// Step 4 of the spec ("Select Date & Time"): ASAP, or a scheduled Today /
/// Tomorrow / custom date with one of four fixed 2-hour slots.
enum _WhenChoice { asap, today, tomorrow, customDate }

const List<_TimeSlot> _timeSlots = [
  _TimeSlot('9 AM – 11 AM', 9),
  _TimeSlot('11 AM – 1 PM', 11),
  _TimeSlot('2 PM – 4 PM', 14),
  _TimeSlot('4 PM – 6 PM', 16),
];

class _TimeSlot {
  final String label;
  final int startHour;
  const _TimeSlot(this.label, this.startHour);
}

class _BookTechnicianScreenState extends State<BookTechnicianScreen> {
  final _notesController = TextEditingController();
  String? _selectedAddressId;
  _WhenChoice _whenChoice = _WhenChoice.asap;
  DateTime? _customDate;
  _TimeSlot? _selectedSlot;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AddressProvider>().fetchAddresses());
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _whenChoice = _WhenChoice.customDate;
        _customDate = picked;
      });
    }
  }

  /// Resolves the current "when" selection into an actual DateTime for the
  /// booking. Returns null for ASAP (no scheduledAt sent — backend treats an
  /// absent scheduledAt as "as soon as possible").
  DateTime? get _resolvedScheduledAt {
    if (_whenChoice == _WhenChoice.asap) return null;
    final hour = _selectedSlot?.startHour ?? TimeOfDay.now().hour;
    DateTime day;
    switch (_whenChoice) {
      case _WhenChoice.today:
        day = DateTime.now();
        break;
      case _WhenChoice.tomorrow:
        day = DateTime.now().add(const Duration(days: 1));
        break;
      case _WhenChoice.customDate:
        day = _customDate ?? DateTime.now();
        break;
      case _WhenChoice.asap:
        day = DateTime.now();
        break;
    }
    return DateTime(day.year, day.month, day.day, hour, 0);
  }

  Future<void> _addAddress() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _AddAddressSheet(),
    );
    if (result == true && mounted) {
      final addresses = context.read<AddressProvider>().addresses;
      if (addresses.isNotEmpty) {
        setState(() => _selectedAddressId = addresses.last.id);
      }
    }
  }

  Future<void> _confirmBooking() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an address')));
      return;
    }
    if (_whenChoice != _WhenChoice.asap && _selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a time slot')));
      return;
    }
    if (_whenChoice == _WhenChoice.customDate && _customDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a date')));
      return;
    }

    final scheduledAt = _resolvedScheduledAt;

    setState(() => _isSubmitting = true);
    try {
      final bookingProvider = context.read<BookingProvider>();
      // Whatever guided-question / AI-diagnosis / attachment data was
      // collected back in IssueDetailsScreen -> AIDiagnosisScreen rides
      // along as the Job Brief the technician sees before Accept.
      final pendingBrief = bookingProvider.pendingJobBrief;
      final pendingImages = bookingProvider.pendingJobBriefImages;
      final booking = await bookingProvider.createBooking(
            categoryId: widget.categoryId,
            addressId: _selectedAddressId!,
            problemDescription: [
              if (widget.problemDescription != null && widget.problemDescription!.isNotEmpty) widget.problemDescription,
              if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
            ].join('\n\n'),
            notes: (pendingBrief != null && (pendingBrief.hasGuidedAnswers || (pendingBrief.aiDiagnosis?.isNotEmpty ?? false)))
                ? pendingBrief.encode()
                : null,
            images: pendingImages,
            scheduledAt: scheduledAt,
            preferredTechnicianId: widget.preferredTechnician?.id,
          );
      bookingProvider.clearPendingJobBrief();
      if (!mounted) return;

      // Payment isn't collected upfront; it happens later once the
      // technician completes the job and raises an invoice (see
      // booking_tracking_screen.dart's "Pay Now" card).
      //
      // Uber-style flow from here: a clear "Booking Confirmed" moment first,
      // then straight into live tracking for this specific booking — not
      // just back to the general list — so it's unambiguous the booking
      // actually went through.
      await _showBookingConfirmedSheet(assignedTechnicianName: widget.preferredTechnician?.name);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => BookingTrackingScreen(bookingId: booking.id)),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create booking: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Brief, unmissable confirmation — a big green check plus a plain-language
  /// status line — before handing off to the tracking screen. Mirrors the
  /// "You're booked!" moment Uber shows right after you request a ride,
  /// so there's never any doubt about whether the booking actually went
  /// through.
  Future<void> _showBookingConfirmedSheet({String? assignedTechnicianName}) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (Navigator.of(sheetContext).canPop()) Navigator.of(sheetContext).pop();
        });
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: AppTheme.successColor.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: AppTheme.successColor, size: 40),
              ),
              const SizedBox(height: 18),
              const Text('Booking Confirmed!', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                assignedTechnicianName != null
                    ? '$assignedTechnicianName is on the way. You can track, chat, or cancel from the next screen.'
                    : "We're finding a nearby technician for you. You'll be notified the moment one accepts.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600], height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Book ${widget.categoryName}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (widget.preferredTechnician != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        widget.preferredTechnician!.name.isNotEmpty ? widget.preferredTechnician!.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Booking with ${widget.preferredTechnician!.name}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text(
                            '${widget.preferredTechnician!.experienceYears} yrs • ★ ${widget.preferredTechnician!.ratingAvg.toStringAsFixed(1)}',
                            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select address', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                TextButton.icon(
                  onPressed: _addAddress,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add new'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Consumer<AddressProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && provider.addresses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                if (provider.addresses.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(14)),
                    child: Text(
                      'No saved addresses yet. Tap "Add new" to add one.',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  );
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
                                  Text(a.label.isNotEmpty ? a.label : 'Address', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
            const SizedBox(height: 22),
            const Text('When do you need the technician?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            // ASAP card.
            _WhenOptionCard(
              icon: Icons.rocket_launch_rounded,
              iconColor: Colors.deepOrange,
              title: 'ASAP',
              subtitle: 'Technician comes as soon as possible',
              selected: _whenChoice == _WhenChoice.asap,
              onTap: () => setState(() {
                _whenChoice = _WhenChoice.asap;
                _selectedSlot = null;
              }),
            ),
            const SizedBox(height: 10),
            // Schedule card — expands to show Today/Tomorrow/Select Date once
            // any of the scheduled options is active.
            _WhenOptionCard(
              icon: Icons.calendar_month_rounded,
              iconColor: AppTheme.primaryColor,
              title: 'Schedule',
              subtitle: 'Pick a day and time that works for you',
              selected: _whenChoice != _WhenChoice.asap,
              onTap: () => setState(() {
                if (_whenChoice == _WhenChoice.asap) _whenChoice = _WhenChoice.today;
              }),
            ),
            if (_whenChoice != _WhenChoice.asap) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _ChoiceChipButton(
                      label: 'Today',
                      selected: _whenChoice == _WhenChoice.today,
                      onTap: () => setState(() => _whenChoice = _WhenChoice.today),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceChipButton(
                      label: 'Tomorrow',
                      selected: _whenChoice == _WhenChoice.tomorrow,
                      onTap: () => setState(() => _whenChoice = _WhenChoice.tomorrow),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ChoiceChipButton(
                      label: _whenChoice == _WhenChoice.customDate && _customDate != null
                          ? '${_customDate!.day}/${_customDate!.month}'
                          : 'Select Date',
                      selected: _whenChoice == _WhenChoice.customDate,
                      onTap: _pickCustomDate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Time slot', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _timeSlots
                    .map((slot) => _ChoiceChipButton(
                          label: slot.label,
                          selected: _selectedSlot?.label == slot.label,
                          onTap: () => setState(() => _selectedSlot = slot),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 22),
            const Text('Additional notes (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Anything else the technician should know...'),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _confirmBooking,
                child: _isSubmitting
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Confirm Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Big tappable "ASAP" / "Schedule" choice card at the top of Step 4.
class _WhenOptionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _WhenOptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey[200]!, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppTheme.primaryColor : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small pill-shaped selectable chip used for Today/Tomorrow/Select Date
/// and for the four fixed time slots.
class _ChoiceChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChipButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.primaryColor : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.primaryColor : Colors.grey[300]!),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _AddAddressSheet extends StatefulWidget {
  const _AddAddressSheet();

  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _labelController = TextEditingController(text: 'Home');
  final _line1Controller = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isSaving = false;

  Future<void> _save() async {
    if (_line1Controller.text.trim().isEmpty ||
        _cityController.text.trim().isEmpty ||
        _stateController.text.trim().isEmpty ||
        _pincodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<AddressProvider>().addAddress(
            label: _labelController.text.trim(),
            line1: _line1Controller.text.trim(),
            city: _cityController.text.trim(),
            state: _stateController.text.trim(),
            pincode: _pincodeController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save address: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _line1Controller.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add new address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(controller: _labelController, decoration: const InputDecoration(labelText: 'Label (Home, Office...)')),
          const SizedBox(height: 12),
          TextField(controller: _line1Controller, decoration: const InputDecoration(labelText: 'Address line')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'City'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: _stateController, decoration: const InputDecoration(labelText: 'State'))),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pincodeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Pincode'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save address'),
            ),
          ),
        ],
      ),
    );
  }
}