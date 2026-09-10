import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../services/service_locator.dart';

/// Shows every review a customer has left for this technician — reached from
/// the technician's own profile ("My Reviews"). Reviews are written by
/// customers from WriteReviewScreen after a booking is paid.
class TechnicianReviewsScreen extends StatefulWidget {
  final String technicianId;
  final double ratingAvg;
  final int ratingCount;

  const TechnicianReviewsScreen({
    Key? key,
    required this.technicianId,
    this.ratingAvg = 0,
    this.ratingCount = 0,
  }) : super(key: key);

  @override
  State<TechnicianReviewsScreen> createState() => _TechnicianReviewsScreenState();
}

class _TechnicianReviewsScreenState extends State<TechnicianReviewsScreen> {
  late Future<List<Review>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ReviewService>().listForTechnician(widget.technicianId);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<ReviewService>().listForTechnician(widget.technicianId);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('My Reviews')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Review>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final reviews = snapshot.data ?? [];
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.ratingCount > 0 ? widget.ratingAvg.toStringAsFixed(1) : '—',
                        style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < widget.ratingAvg.round() ? Icons.star_rounded : Icons.star_border_rounded,
                            size: 20,
                            color: const Color(0xFFF5A623),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.ratingCount > 0 ? 'Based on ${widget.ratingCount} review${widget.ratingCount == 1 ? '' : 's'}' : 'No reviews yet',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('Could not load reviews', style: TextStyle(color: Colors.grey[600])),
                    ),
                  )
                else if (reviews.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.star_border_rounded, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('No reviews yet', style: TextStyle(fontSize: 14.5, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                  )
                else
                  ...reviews.map((r) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: List.generate(
                                    5,
                                    (i) => Icon(
                                      i < r.rating ? Icons.star_rounded : Icons.star_border_rounded,
                                      size: 17,
                                      color: const Color(0xFFF5A623),
                                    ),
                                  ),
                                ),
                                Text(
                                  DateFormat('d MMM yyyy').format(r.createdAt.toLocal()),
                                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(r.comment, style: TextStyle(fontSize: 13.5, color: Colors.grey[800], height: 1.4)),
                            ],
                          ],
                        ),
                      )),
              ],
            );
          },
        ),
      ),
    );
  }
}