import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/service_locator.dart';
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

/// Step 4 of the spec ("Select Date & Time"): a scheduled Today / Tomorrow /
/// custom date with one of four fixed 2-hour slots. ASAP was removed —
/// every booking now goes through a technician Accept/Decline step, so a
/// firm slot is always required rather than "as soon as possible".
enum _WhenChoice { today, tomorrow, customDate }

/// Fixed, category-specific quick questions shown on the booking confirm
/// screen (before "Confirm Booking") — e.g. AC Repair asks about cooling /
/// gas leak / noise, Plumber asks about leak / blockage / installation.
/// Keyed by the exact category name seeded in `002_seed_categories.sql`.
const Map<String, List<_CategoryQuestion>> _categoryQuestions = {
  'AC Repair': [
    _CategoryQuestion('What\'s the issue?', ['Not cooling', 'Gas leak', 'Water leakage', 'Unusual noise', 'Not turning on']),
    _CategoryQuestion('AC type', ['Split AC', 'Window AC', 'Central AC']),
  ],
  'Plumber': [
    _CategoryQuestion('What\'s the issue?', ['Leakage', 'Blockage / clogging', 'New fitting/installation', 'Low water pressure', 'Tap/valve repair']),
    _CategoryQuestion('Where is the problem?', ['Kitchen', 'Bathroom', 'Overhead tank', 'Main pipeline']),
  ],
  'Electrician': [
    _CategoryQuestion('What\'s the issue?', ['Switch/socket not working', 'Wiring problem', 'Frequent tripping', 'New installation', 'Fan/light repair']),
    _CategoryQuestion('Is it urgent?', ['Yes, safety risk', 'No, can wait']),
  ],
  'Appliance Repair': [
    _CategoryQuestion('Which appliance?', ['Washing machine', 'Refrigerator', 'Microwave', 'Water purifier', 'Other']),
    _CategoryQuestion('What\'s the issue?', ['Not turning on', 'Making noise', 'Not working properly', 'Needs servicing']),
  ],
  'Roofer': [
    _CategoryQuestion('What\'s the issue?', ['Leakage/seepage', 'Waterproofing needed', 'Cracks', 'General maintenance']),
  ],
  'Carpenter': [
    _CategoryQuestion('What\'s the issue?', ['Furniture repair', 'New fitting', 'Door/window issue', 'Lock/hinge repair']),
  ],
  'Painter': [
    _CategoryQuestion('Type of work', ['Interior painting', 'Exterior painting', 'Touch-up/patch work', 'Waterproofing + painting']),
  ],
};

class _CategoryQuestion {
  final String question;
  final List<String> options;
  const _CategoryQuestion(this.question, this.options);
}

const List<_TimeSlot> _timeSlots = [
  _TimeSlot('9 AM – 11 AM', 9),
  _TimeSlot('11 AM – 1 PM', 11),
  _TimeSlot('2 PM – 4 PM', 14),
  _TimeSlot('4 PM – 6 PM', 16),
]; 
class _TimeSlot {
  final String label;
  final int startHour;
  final int startMinute;
  const _TimeSlot(this.label, this.startHour, [this.startMinute = 0]);
}

const String _customTimeSentinel = 'Custom time…';

class _BookTechnicianScreenState extends State<BookTechnicianScreen> {
  final _notesController = TextEditingController();
  String? _selectedAddressId;
  _WhenChoice _whenChoice = _WhenChoice.today;
  DateTime? _customDate;
  _TimeSlot? _selectedSlot;
  bool _isSubmitting = false;
  final Map<String, String> _categoryAnswers = {};
  // Tracks the raw dropdown selection per question (may be 'Other'),
  // separate from _categoryAnswers which holds the actual value sent to
  // the technician (the typed text when 'Other' is chosen).
  final Map<String, String> _categoryDropdownSelection = {};
  final Map<String, TextEditingController> _categoryOtherControllers = {};

  // Optional photos of the issue, added right on this screen — same
  // Camera/Gallery bottom-sheet pattern as IssueDetailsScreen's "AI
  // Assessment" flow. These are uploaded (and merged with any images
  // already attached via the AI Assessment flow) when the booking is
  // confirmed.
  final _picker = ImagePicker();
  final List<File> _newImages = [];
  static const int _maxImages = 5;
  final List<File> _newVideos = [];
  static const int _maxVideos = 1;

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
  /// booking.
  DateTime? get _resolvedScheduledAt {
    final hour = _selectedSlot?.startHour ?? TimeOfDay.now().hour;
    final minute = _selectedSlot?.startMinute ?? 0;
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
    }
    return DateTime(day.year, day.month, day.day, hour, minute);
  }

  Future<void> _pickCustomTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: 'Select preferred time',
    );
    if (picked == null) return;
    setState(() {
      _selectedSlot = _TimeSlot(picked.format(context), picked.hour, picked.minute);
    });
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

  Future<void> _openAddPhotoSheet() async {
    final canAddPhoto = _newImages.length < _maxImages;
    final canAddVideo = _newVideos.length < _maxVideos;
    if (!canAddPhoto && !canAddVideo) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              if (canAddPhoto) ...[
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryColor),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ],
              if (canAddVideo) ...[
                ListTile(
                  leading: const Icon(Icons.videocam_outlined, color: AppTheme.primaryColor),
                  title: const Text('Record a video'),
                  subtitle: const Text('Up to 2 minutes', style: TextStyle(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickVideo(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.video_library_outlined, color: AppTheme.primaryColor),
                  title: const Text('Choose video from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_newImages.length >= _maxImages) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 80);
    if (picked != null) {
      setState(() => _newImages.add(File(picked.path)));
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImages.removeAt(index));
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (_newVideos.isNotEmpty) return;
    final picked = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 2));
    if (picked != null) {
      setState(() => _newVideos.add(File(picked.path)));
    }
  }

  void _removeNewVideo(int index) {
    setState(() => _newVideos.removeAt(index));
  }

  void _openVideoPreview(File file) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => _BookingVideoPreviewDialog(file: file),
    );
  }

  Widget _photoThumb({required Widget child, required VoidCallback onRemove, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 10, top: 6),
      child: SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 80, height: 80, child: child),
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addPhotoTile() {
    return GestureDetector(
      onTap: _openAddPhotoSheet,
      child: Container(
        width: 80,
        height: 80,
        margin: const EdgeInsets.only(right: 10, top: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 26),
            SizedBox(height: 4),
            Text('Add', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (_selectedAddressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an address')));
      return;
    }
    if (_selectedSlot == null) {
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

      // Upload any photos added right here on this screen and merge them
      // with whatever was already attached back in the AI Assessment flow.
      final newImageUrls = <String>[];
      if (_newImages.isNotEmpty) {
        final uploadService = context.read<UploadService>();
        for (final img in _newImages) {
          newImageUrls.add(await uploadService.uploadFile(img));
        }
      }
      final allImages = [...?pendingImages, ...newImageUrls];

      // Video isn't a Booking field (only `images` is), so it rides along on
      // the Job Brief instead — same as the AI Assessment flow — so
      // JobBriefCard can render it as a proper playable thumbnail rather
      // than a raw URL dumped into the visible problem description.
      String? newVideoUrl;
      if (_newVideos.isNotEmpty) {
        final uploadService = context.read<UploadService>();
        newVideoUrl = await uploadService.uploadFile(_newVideos.first);
      }
      final brief = (_categoryAnswers.isNotEmpty || newVideoUrl != null)
          ? (pendingBrief ?? const JobBrief()).copyWith(
              categoryAnswers: _categoryAnswers.isNotEmpty ? _categoryAnswers : null,
              hasVideo: newVideoUrl != null ? true : null,
              videoUrl: newVideoUrl,
            )
          : pendingBrief;

      final booking = await bookingProvider.createBooking(
            categoryId: widget.categoryId,
            addressId: _selectedAddressId!,
            problemDescription: [
              if (widget.problemDescription != null && widget.problemDescription!.isNotEmpty) widget.problemDescription,
              if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
            ].join('\n\n'),
            notes: (brief != null && (brief.hasGuidedAnswers || brief.hasVideo || (brief.aiDiagnosis?.isNotEmpty ?? false)))
                ? brief.encode()
                : null,
            images: allImages.isNotEmpty ? allImages : null,
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
    for (final c in _categoryOtherControllers.values) {
      c.dispose();
    }
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
            const SizedBox(height: 4),
            Text(
              'Every booking is reviewed by a technician before it\'s confirmed, so pick a day and time that works for you.',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
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
            DropdownButtonFormField<String>(
              // If the user picked a custom time via the clock picker, its
              // label (e.g. "6:45 PM") won't match any of the fixed slots,
              // so it's injected into the items list below on the fly.
              value: _selectedSlot?.label,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: 'Select a time slot',
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                ..._timeSlots.map((slot) => DropdownMenuItem(value: slot.label, child: Text(slot.label))),
                if (_selectedSlot != null && !_timeSlots.any((s) => s.label == _selectedSlot!.label))
                  DropdownMenuItem(
                    value: _selectedSlot!.label,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 6),
                        Text(_selectedSlot!.label),
                      ],
                    ),
                  ),
                DropdownMenuItem(
                  value: _customTimeSentinel,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.access_time, size: 16, color: Colors.teal),
                      SizedBox(width: 6),
                      Text('Choose your own time', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == _customTimeSentinel) {
                  _pickCustomTime();
                  return;
                }
                setState(() => _selectedSlot = _timeSlots.firstWhere((s) => s.label == value));
              },
            ),
            if ((_categoryQuestions[widget.categoryName] ?? const []).isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('About your ${widget.categoryName} issue', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text('Helps the technician come prepared', style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
              const SizedBox(height: 10),
              ...(_categoryQuestions[widget.categoryName] ?? const []).map((q) {
                final otherController = _categoryOtherControllers.putIfAbsent(
                  q.question,
                  () => TextEditingController(text: _categoryDropdownSelection[q.question] == 'Other' ? _categoryAnswers[q.question] : null),
                );
                final isOtherSelected = _categoryDropdownSelection[q.question] == 'Other';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _categoryDropdownSelection[q.question],
                        isExpanded: true,
                        decoration: InputDecoration(
                          hintText: 'Select an option',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          ...q.options.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))),
                          const DropdownMenuItem(value: 'Other', child: Text('Other (type your issue)')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _categoryDropdownSelection[q.question] = value;
                            if (value == 'Other') {
                              _categoryAnswers[q.question] = otherController.text.trim();
                            } else {
                              _categoryAnswers[q.question] = value;
                            }
                          });
                        },
                      ),
                      if (isOtherSelected) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: otherController,
                          decoration: const InputDecoration(hintText: 'Describe your issue...'),
                          onChanged: (text) => _categoryAnswers[q.question] = text.trim(),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Photos & Video (optional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${_newImages.length}/$_maxImages photos, ${_newVideos.length}/$_maxVideos video',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11.5)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Helps the technician come prepared', style: TextStyle(fontSize: 11.5, color: Colors.grey[600])),
            const SizedBox(height: 10),
            SizedBox(
              height: 110,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ..._newImages.asMap().entries.map((e) => _photoThumb(
                        child: Image.file(e.value, fit: BoxFit.cover),
                        onRemove: () => _removeNewImage(e.key),
                      )),
                  ..._newVideos.asMap().entries.map((e) => _photoThumb(
                        onTap: () => _openVideoPreview(e.value),
                        onRemove: () => _removeNewVideo(e.key),
                        child: Container(
                          color: Colors.black87,
                          child: const Center(
                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 34),
                          ),
                        ),
                      )),
                  if (_newImages.length < _maxImages || _newVideos.length < _maxVideos) _addPhotoTile(),
                ],
              ),
            ),
            const SizedBox(height: 8),
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

/// Full-screen video preview for a video attached right on this screen —
/// tap to toggle playback, tap the close button to dismiss. Mirrors
/// IssueDetailsScreen's own preview dialog (kept as a separate private
/// class here since each screen owns its widget tree independently).
class _BookingVideoPreviewDialog extends StatefulWidget {
  final File file;
  const _BookingVideoPreviewDialog({required this.file});

  @override
  State<_BookingVideoPreviewDialog> createState() => _BookingVideoPreviewDialogState();
}

class _BookingVideoPreviewDialogState extends State<_BookingVideoPreviewDialog> {
  late final VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _initialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.all(0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_initialized)
            GestureDetector(
              onTap: () => setState(() {
                _controller.value.isPlaying ? _controller.pause() : _controller.play();
              }),
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            )
          else
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}