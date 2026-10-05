import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/category_provider.dart';
import '../utils/working_hours.dart';

/// Lets the technician set daily start/end working hours.
/// Saves to PATCH /technicians/:id/working-hours via TechnicianKycProvider.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({Key? key}) : super(key: key);

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);
  bool _acceptEmergencyOutsideHours = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Start from the technician's saved hours (first working day found), if any.
    final saved = context.read<TechnicianKycProvider>().profile?.workingHours ?? const {};
    for (final k in kWeekdayKeys) {
      final d = saved[k];
      if (d != null) {
        _startTime = _parse(d.open) ?? _startTime;
        _endTime = _parse(d.close) ?? _endTime;
        break;
      }
    }
  }

  TimeOfDay? _parse(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving) return;
    if (_endTime.hour * 60 + _endTime.minute <= _startTime.hour * 60 + _startTime.minute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }
    final provider = context.read<TechnicianKycProvider>();
    final saved = provider.profile?.workingHours ?? const <String, DayHours?>{};
    // Apply the chosen window to every day the technician already works; if
    // none is set yet, default to all 7 days.
    final worksAny = saved.values.any((d) => d != null);
    final window = DayHours(open: _hhmm(_startTime), close: _hhmm(_endTime));
    final hours = <String, DayHours?>{
      for (final k in kWeekdayKeys) k: (!worksAny || saved[k] != null) ? window : null,
    };
    setState(() => _saving = true);
    final ok = await provider.updateWorkingHours(hours);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Working hours saved: ${_format(_startTime)} - ${_format(_endTime)}'
            : (provider.error ?? 'Could not save working hours')),
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String _format(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Working Hours')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined, color: AppTheme.primaryColor),
                  title: const Text('Start time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  trailing: Text(_format(_startTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  onTap: () => _pickTime(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.nights_stay_outlined, color: AppTheme.primaryColor),
                  title: const Text('End time', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  trailing: Text(_format(_endTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                  onTap: () => _pickTime(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              title: const Text('Accept emergency jobs outside these hours',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
              subtitle: const Text('You may be shown urgent requests even when offline',
                  style: TextStyle(fontSize: 12.5)),
              value: _acceptEmergencyOutsideHours,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (v) => setState(() => _acceptEmergencyOutsideHours = v),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}