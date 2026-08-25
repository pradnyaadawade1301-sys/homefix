import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Lets the technician set daily start/end working hours.
/// UI-only for now; wire the save action to your technician profile API.
class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({Key? key}) : super(key: key);

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 19, minute: 0);
  bool _acceptEmergencyOutsideHours = false;

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
              onPressed: () {
                // TODO: PATCH technician profile with working hours.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Working hours saved: ${_format(_startTime)} - ${_format(_endTime)}')),
                );
              },
              child: const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}