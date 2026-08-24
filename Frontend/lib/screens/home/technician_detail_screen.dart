import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../booking/book_technician_screen.dart';
import '../consultation/searching_technician_screen.dart';

class TechnicianDetailScreen extends StatelessWidget {
  final Technician technician;
  final String? problemDescription;
  const TechnicianDetailScreen({Key? key, required this.technician, this.problemDescription}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.primaryColor,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryColor, AppTheme.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.white,
                    child: Text(
                      technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          technician.name.isNotEmpty ? technician.name : 'Technician',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (technician.isVerified)
                        const Icon(Icons.verified_rounded, color: AppTheme.primaryColor),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(technician.categoryName, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _StatChip(icon: Icons.star_rounded, iconColor: const Color(0xFFF5A623),
                          label: '${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount} reviews)'),
                      const SizedBox(width: 10),
                      _StatChip(icon: Icons.work_history_outlined, iconColor: AppTheme.primaryColor,
                          label: '${technician.experienceYears} yrs experience'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: technician.isAvailable
                          ? AppTheme.successColor.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          technician.isAvailable ? Icons.check_circle_rounded : Icons.cancel_rounded,
                          color: technician.isAvailable ? AppTheme.successColor : Colors.grey,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          technician.isAvailable ? 'Available now' : 'Currently unavailable',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: technician.isAvailable ? AppTheme.successColor : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: technician.isAvailable
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => BookTechnicianScreen(
                                    categoryId: technician.categoryId,
                                    categoryName: technician.categoryName,
                                    problemDescription: problemDescription,
                                    preferredTechnician: technician,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: const Text('Book Now'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: technician.isAvailable
                          ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SearchingTechnicianScreen(
                                    categoryId: technician.categoryId,
                                    categoryName: technician.categoryName,
                                    note: problemDescription,
                                    preferredTechnicianId: technician.id,
                                    preferredTechnicianName: technician.name,
                                  ),
                                ),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.videocam_rounded),
                      label: const Text('Video Call'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  const _StatChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}