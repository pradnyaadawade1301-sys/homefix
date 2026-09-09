import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/category_provider.dart';
import '../../models/booking_model.dart';
import '../booking/book_technician_screen.dart';
class AllCategoriesScreen extends StatefulWidget {
  const AllCategoriesScreen({super.key});

  @override
  State<AllCategoriesScreen> createState() => _AllCategoriesScreenState();
}

class _AllCategoriesScreenState extends State<AllCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  // ✅ Local asset image mapping — API image_url nahi hai toh asset use karo
  String _getAssetImage(String categoryName) {
    switch (categoryName.toLowerCase().trim()) {
      case 'civil work':          return 'assets/images/civil_work.png';
      case 'fabrication':         return 'assets/images/fabrication.png';
      case 'pop / false ceiling':
      case 'pop/false ceiling':   return 'assets/images/pop_false_ceiling.png';
      case 'general repair':      return 'assets/images/general_repair.png';
      case 'electrician':         return 'assets/images/electrician.png';
      case 'plumber':             return 'assets/images/plumber.png';
      case 'carpenter':           return 'assets/images/carpentr.png';
      case 'painter':             return 'assets/images/painter.png';
      case 'home cleaning':       return 'assets/images/home cleaning.png';
      case 'cctv':                return 'assets/images/cctv repair.png';
      case 'ac repair':           return 'assets/images/AC repair.png';
      case 'appliance repair':    return 'assets/images/appliance repair.png';
      case 'ro service':          return 'assets/images/RO-service.png';
      case 'roofer':              return 'assets/images/Roofer.png';
      default:                    return 'assets/images/worker_illustrati.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryProv = context.watch<CategoryProvider>();
    final categories = categoryProv.categories
        .where((c) => c.isActive)
        .where((c) => c.name.toLowerCase().trim() != 'refrigerator')
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        title: const Text('All Services',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: categoryProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : categoryProv.error != null
              ? Center(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(categoryProv.error!,
                        style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<CategoryProvider>().fetchCategories(),
                      child: const Text('Retry'),
                    ),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: () => context.read<CategoryProvider>().fetchCategories(),
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: categories.length,
                    itemBuilder: (_, i) {
                      final cat = categories[i];
                      return GestureDetector(
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => BookTechnicianScreen(categoryId: cat.id, categoryName: cat.name))),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16)),
                                  child: _buildImage(cat),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                                child: Text(
                                  cat.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildImage(Category cat) {
    // Network image pehle try karo, fallback asset pe
    if ((cat.iconUrl ?? '').isNotEmpty) {
      return Image.network(
        cat.iconUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _assetImage(cat.name),
      );
    }
    return _assetImage(cat.name);
  }

  Widget _assetImage(String name) {
    return Image.asset(
      _getAssetImage(name),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade100,
        child: const Icon(Icons.home_repair_service_outlined,
            color: Colors.grey, size: 48),
      ),
    );
  }
}