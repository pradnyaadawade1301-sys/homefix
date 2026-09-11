import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/category_provider.dart';
import '../utils/working_hours.dart';
import '../services/location_service.dart';

/// Technician availability control — a master online/offline toggle.
///
/// FIXED: this used to be UI-only (a local setState switch that never told
/// the backend anything). That meant `is_available` in the DB never
/// actually changed no matter what a technician tapped here — and since
/// both the "nearest available technician" match AND the preferred-
/// technician video-call check require `is_available = true`, a
/// technician could look "Online" in this screen while still being
/// completely invisible/unbookable to customers. Now the switch calls
/// PATCH /technicians/:id/availability (via [TechnicianKycProvider]) and
/// reflects the real, persisted value.
class AvailabilityToggleScreen extends StatefulWidget {
  const AvailabilityToggleScreen({Key? key}) : super(key: key);

  @override
  State<AvailabilityToggleScreen> createState() => _AvailabilityToggleScreenState();
}

class _AvailabilityToggleScreenState extends State<AvailabilityToggleScreen> {
  bool _toggling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TechnicianKycProvider>().loadMyProfile();
    });
  }

 Future<void> _onToggle(bool value) async {
  if (_toggling) return;
  setState(() => _toggling = true);
  final ok = await context.read<TechnicianKycProvider>().setAvailability(value);
  if (mounted) setState(() => _toggling = false);
  if (!ok && mounted) {
    final error = context.read<TechnicianKycProvider>().error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Could not update availability. Please try again.')),
    );
    return;
  }
  if (ok && value && mounted) {
    final locationData = await LocationService().getCurrentLocation();
    if (locationData?.latitude != null && locationData?.longitude != null && mounted) {
      await context.read<TechnicianKycProvider>().updateLocation(
            locationData!.latitude!,
            locationData.longitude!,
          );
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Availability')),
      body: Consumer<TechnicianKycProvider>(
        builder: (context, kyc, _) {
          if (kyc.isLoading && kyc.profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final profile = kyc.profile;
          if (profile == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  kyc.error ?? 'Could not load your technician profile.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final isOnline = profile.isAvailable;
          final canGoOnline = profile.isApproved;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!canGoOnline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          profile.isPending
                              ? 'Your KYC is still pending admin approval. You can\'t receive job requests until you\'re approved.'
                              : 'Your KYC was rejected${profile.rejectionReason != null ? ': ${profile.rejectionReason}' : '.'} You can\'t receive job requests.',
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: (isOnline ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                        color: isOnline ? AppTheme.successColor : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(isOnline ? 'You are Online' : 'You are Offline',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 3),
                          Text(
                            isOnline ? 'Customers can book you right now' : 'You won\'t receive new job requests',
                            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    if (_toggling)
                      const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Switch(
                        value: isOnline,
                        activeThumbColor: AppTheme.successColor,
                        onChanged: canGoOnline ? _onToggle : null,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Weekly working hours — display-only for customers (does NOT
              // gate matching/booking), separate from the online toggle above.
              _WorkingHoursCard(
                key: ValueKey(profile.id),
                initial: profile.workingHours,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Editable weekly schedule: one row per weekday with an open/closed switch and
/// two time pickers. "Save" persists via [TechnicianKycProvider.updateWorkingHours].
class _WorkingHoursCard extends StatefulWidget {
  final Map<String, DayHours?> initial;
  const _WorkingHoursCard({super.key, required this.initial});

  @override
  State<_WorkingHoursCard> createState() => _WorkingHoursCardState();
}

class _WorkingHoursCardState extends State<_WorkingHoursCard> {
  late Map<String, DayHours?> _draft;
  bool _saving = false;

  static const _fallback = DayHours(open: '09:00', close: '18:00');

  @override
  void initState() {
    super.initState();
    _draft = {for (final k in kWeekdayKeys) k: widget.initial[k]};
  }

  bool get _dirty {
    for (final k in kWeekdayKeys) {
      final a = _draft[k];
      final b = widget.initial[k];
      if ((a == null) != (b == null)) return true;
      if (a != null && b != null && (a.open != b.open || a.close != b.close)) return true;
    }
    return false;
  }

  TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.tryParse(p[0]) ?? 9, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(String dayKey, bool isOpen) async {
    final cur = _draft[dayKey] ?? _fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: _parse(isOpen ? cur.open : cur.close),
      helpText: isOpen ? 'Opening time' : 'Closing time',
    );
    if (picked == null) return;
    final v = _fmt(picked);
    setState(() {
      if (isOpen) {
        _draft[dayKey] = DayHours(open: v, close: cur.close);
      } else {
        _draft[dayKey] = DayHours(open: cur.open, close: v);
      }
      // Keep open < close so the row (and the backend validator) stays sane.
      final d = _draft[dayKey]!;
      if (d.openMinutes >= d.closeMinutes) {
        _draft[dayKey] = isOpen
            ? DayHours(open: d.open, close: _fmt(TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute)))
            : DayHours(open: _fmt(TimeOfDay(hour: (picked.hour - 1) % 24, minute: picked.minute)), close: d.close);
      }
    });
  }

  void _applyToAll(String sourceKey) {
    final src = _draft[sourceKey];
    setState(() {
      for (final k in kWeekdayKeys) {
        _draft[k] = src == null ? null : DayHours(open: src.open, close: src.close);
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ok = await context.read<TechnicianKycProvider>().updateWorkingHours(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    final msg = ok
        ? 'Working hours updated'
        : (context.read<TechnicianKycProvider>().error ?? 'Could not save working hours');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    if (ok) setState(() {}); // widget.initial is stale until parent reloads; _dirty recomputed on next build via provider
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 20, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Working hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              TextButton(
                onPressed: () => _applyToAll('mon'),
                child: const Text('Apply Mon to all'),
              ),
            ],
          ),
          Text(
            'Shown to customers on your profile. Doesn\'t block bookings outside these hours.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          ...kWeekdayKeys.map(_dayRow),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (!_dirty || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save working hours'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(String k) {
    final v = _draft[k];
    final isOpen = v != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(kWeekdayShort[k]!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          Expanded(
            child: isOpen
                ? Row(
                    children: [
                      _timeChip(v.openLabel, () => _pickTime(k, true)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('–', style: TextStyle(color: Colors.grey)),
                      ),
                      _timeChip(v.closeLabel, () => _pickTime(k, false)),
                    ],
                  )
                : Text('Closed', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          ),
          Switch(
            value: isOpen,
            activeThumbColor: AppTheme.primaryColor,
            onChanged: (on) => setState(() => _draft[k] = on ? (widget.initial[k] ?? _fallback) : null),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
      ),
    );
  }
}