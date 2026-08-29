import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/booking_provider.dart';
import 'bookings_screen.dart';

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

class _BookTechnicianScreenState extends State<BookTechnicianScreen> {
  final _notesController = TextEditingController();
  String? _selectedAddressId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AddressProvider>().fetchAddresses());
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

    DateTime? scheduledAt;
    if (_selectedDate != null) {
      final time = _selectedTime ?? TimeOfDay.now();
      scheduledAt = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, time.hour, time.minute);
    }

    setState(() => _isSubmitting = true);
    try {
      await context.read<BookingProvider>().createBooking(
            categoryId: widget.categoryId,
            addressId: _selectedAddressId!,
            problemDescription: [
              if (widget.problemDescription != null && widget.problemDescription!.isNotEmpty) widget.problemDescription,
              if (_notesController.text.trim().isNotEmpty) _notesController.text.trim(),
            ].join('\n\n'),
            scheduledAt: scheduledAt,
            preferredTechnicianId: widget.preferredTechnician?.id,
          );
      if (!mounted) return;

      // Booking is created — that's it for now. Payment isn't collected
      // upfront; it happens later once the technician completes the job and
      // raises an invoice (see booking_tracking_screen.dart's "Pay Now" card,
      // shown when booking.isInvoiced && !booking.isPaid).
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
        (route) => route.isFirst,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.preferredTechnician != null
                ? 'Booking confirmed with ${widget.preferredTechnician!.name}'
                : 'Booking created — searching for a nearby technician...',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create booking: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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