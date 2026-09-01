import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/category_provider.dart';
import 'technician_list_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  static const Map<String, IconData> _icons = {
    'Electrician': Icons.electrical_services_rounded,
    'Plumber': Icons.plumbing_rounded,
    'AC Repair': Icons.ac_unit_rounded,
    'Appliance Repair': Icons.kitchen_rounded,
    'Roofer': Icons.roofing_rounded,
    'Carpenter': Icons.carpenter_rounded,
    'Painter': Icons.format_paint_rounded,
    'RO Service': Icons.water_drop_rounded,
    'CCTV': Icons.videocam_rounded,
    'Home Cleaning': Icons.cleaning_services_rounded,
  };

  static const Map<String, String> _images = {
    'Electrician': 'assets/images/electrician.png',
    'Plumber': 'assets/images/plumber.png',
    'AC Repair': 'assets/images/AC repair.png',
    'Appliance Repair': 'assets/images/appliance repair.png',
    'Carpenter': 'assets/images/carpentr.png',
    'Painter': 'assets/images/painter.png',
    'RO Service': 'assets/images/RO-service.png',
    'CCTV': 'assets/images/cctv repair.png',
    'Home Cleaning': 'assets/images/home cleaning.png',
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CategoryProvider>();
      if (provider.categories.isEmpty) provider.fetchCategories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Services')),
      body: Consumer<CategoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.categories.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = provider.categories.where((c) => c.name != 'Refrigerator' && c.name != 'Roofer').toList();
          if (categories.isEmpty) {
            return Center(
              child: Text(
                provider.error != null ? 'Could not load services' : 'No services available yet',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, i) {
              final cat = categories[i];
              final icon = _icons[cat.name] ?? Icons.build_rounded;
              final imagePath = _images[cat.name];
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TechnicianListScreen(categoryId: cat.id, categoryName: cat.name),
                  ));
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: imagePath != null
                            ? Image.asset(
                                imagePath,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                  child: Icon(icon, color: AppTheme.primaryColor, size: 34),
                                ),
                              )
                            : Container(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                child: Icon(icon, color: AppTheme.primaryColor, size: 34),
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                        child: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}