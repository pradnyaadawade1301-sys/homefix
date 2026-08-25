import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Technician availability control — a master online/offline toggle plus
/// per-day working availability. UI-only for now; wire the toggle to your
/// technician status API once ready.
class AvailabilityToggleScreen extends StatefulWidget {
  const AvailabilityToggleScreen({Key? key}) : super(key: key);

  @override
  State<AvailabilityToggleScreen> createState() => _AvailabilityToggleScreenState();
}

class _AvailabilityToggleScreenState extends State<AvailabilityToggleScreen> {
  bool _isOnline = true;
  final Map<String, bool> _days = {
    'Monday': true,
    'Tuesday': true,
    'Wednesday': true,
    'Thursday': true,
    'Friday': true,
    'Saturday': true,
    'Sunday': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Availability')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                    color: (_isOnline ? AppTheme.successColor : Colors.grey).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isOnline ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                    color: _isOnline ? AppTheme.successColor : Colors.grey,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_isOnline ? 'You are Online' : 'You are Offline',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 3),
                      Text(
                        _isOnline ? 'Customers can book you right now' : 'You won\'t receive new job requests',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isOnline,
                  activeThumbColor: AppTheme.successColor,
                  onChanged: (v) => setState(() => _isOnline = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Weekly availability',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _days.keys.map((day) {
                return Column(
                  children: [
                    SwitchListTile(
                      title: Text(day, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                      value: _days[day]!,
                      activeThumbColor: AppTheme.primaryColor,
                      onChanged: (v) => setState(() => _days[day] = v),
                    ),
                    if (day != _days.keys.last) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}