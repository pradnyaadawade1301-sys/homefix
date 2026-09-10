import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';

/// Final screen of the whole booking journey — shown once payment is done
/// and the customer has either submitted a review or chosen to skip it.
/// Gives a clear "you're all set" moment instead of just popping back
/// silently, and offers a way straight back to Home.
class TaskCompletedScreen extends StatelessWidget {
  final Booking booking;
  final bool reviewed;

  const TaskCompletedScreen({
    Key? key,
    required this.booking,
    this.reviewed = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final techName = booking.technician?.name;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 46,
                backgroundColor: Color(0xFFE8F8EE),
                child: Icon(Icons.task_alt_rounded, color: AppTheme.successColor, size: 52),
              ),
              const SizedBox(height: 24),
              const Text(
                'All done!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your ${booking.categoryName.isNotEmpty ? booking.categoryName : 'service'} booking is complete and paid for.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    _row(Icons.build_outlined, 'Service', booking.categoryName.isNotEmpty ? booking.categoryName : '\u2014'),
                    if (techName != null && techName.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _row(Icons.person_outline_rounded, 'Technician', techName),
                    ],
                    const SizedBox(height: 12),
                    _row(
                      reviewed ? Icons.star_rounded : Icons.star_border_rounded,
                      'Review',
                      reviewed ? 'Submitted, thank you!' : 'Not submitted',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                  child: const Text('Back to Home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(fontSize: 13.5, color: Colors.grey[600])),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}