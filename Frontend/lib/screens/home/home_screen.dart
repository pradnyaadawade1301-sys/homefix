import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../models/booking_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/location_provider.dart';
import '../booking/bookings_screen.dart';
import '../issue/issue_details_screen.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import 'categories_screen.dart';
import 'technician_detail_screen.dart';
import 'technician_list_screen.dart';
import '../payment/transaction_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
  _HomeTab(),
  BookingsScreen(),
  TransactionHistoryScreen(),
  ProfileScreen(),
];

 static const _navItems = [
  _NavItemData(icon: Icons.home_rounded, label: 'Home'),
  _NavItemData(icon: Icons.history_rounded, label: 'History'),
  _NavItemData(icon: Icons.receipt_long_rounded, label: 'Transactions'),
  _NavItemData(icon: Icons.person_rounded, label: 'Profile'),
];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (i) {
          final item = _navItems[i];
          final selected = i == _selectedIndex;
          return InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => setState(() => _selectedIndex = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 18 : 14,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: selected ? AppTheme.primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                item.icon,
                color: selected ? Colors.white : Colors.grey[400],
                size: 24,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  const _NavItemData({required this.icon, required this.label});
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late final AnimationController _bannerAnimController;
  late final Animation<double> _floatAnim;
  late final Animation<double> _sparkleAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
    _bannerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _bannerAnimController, curve: Curves.easeInOut),
    );
    _sparkleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _bannerAnimController, curve: Curves.easeInOut),
    );
  }

  void _loadData() {
    context.read<CategoryProvider>().fetchCategories();
    context.read<TechnicianProvider>().fetchTechnicians();
    context.read<LocationProvider>().resolveLocation();
  }

  void _openTechnicianList({String? categoryId, String? categoryName, String? initialQuery}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => TechnicianListScreen(
        categoryId: categoryId,
        categoryName: categoryName,
        initialQuery: initialQuery,
      ),
    ));
  }

  void _openCategories() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CategoriesScreen()));
  }

  void _openNotifications() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _submitSearch(String value) {
    if (value.trim().isEmpty) return;
    _openTechnicianList(initialQuery: value.trim());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildSearchBar(),
            const SizedBox(height: 20),
            _buildPromoBanner(context),
            const SizedBox(height: 24),
            _sectionTitle('Most Booked Services', onViewAll: _openCategories),
            const SizedBox(height: 14),
            _buildCategoriesRow(),
            const SizedBox(height: 24),
            _sectionTitle('Top Picks for you', onViewAll: () => _openTechnicianList()),
            const SizedBox(height: 14),
            _buildTechnicianList(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final name = authProvider.currentUser?.name;
        final photoUrl = authProvider.currentUser?.photoUrl;
        final displayName = (name != null && name.trim().isNotEmpty) ? name.split(' ').first : 'there';
        return Row(
          children: [
            GestureDetector(
              onTap: () {
                final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                if (homeState != null) {
                  homeState.setState(() => homeState._selectedIndex = 3);
                } else {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
                }
              },
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                child: (photoUrl == null || photoUrl.isEmpty)
                    ? Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'H',
                        style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hi, $displayName', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 2),
                  Consumer<LocationProvider>(
                    builder: (context, locProvider, _) {
                      if (locProvider.isResolving && !locProvider.hasAttempted) {
                        return const Row(
                          children: [
                            SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Detecting location...',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        );
                      }
                      if (locProvider.hasLocation) {
                        return GestureDetector(
                          onTap: () => locProvider.refreshLocation(),
                          child: Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 2),
                              Flexible(
                                child: Text(
                                  locProvider.displayCityState,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF1A1F36),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (locProvider.isResolving) ...[
                                const SizedBox(width: 4),
                                const SizedBox(
                                  width: 12, height: 12,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                ),
                              ],
                            ],
                          ),
                        );
                      }
                      return GestureDetector(
                        onTap: () => locProvider.resolveLocation(),
                        child: const Row(
                          children: [
                            Icon(Icons.location_on, size: 16, color: AppTheme.primaryColor),
                            SizedBox(width: 2),
                            Text(
                              'Set your location',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A1F36)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
              ),
              child: IconButton(
                icon: const Icon(Icons.notifications_none_rounded),
                onPressed: _openNotifications,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E7D32), width: 1.4),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onSubmitted: _submitSearch,
        decoration: InputDecoration(
          hintText: 'Search service...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[500]),
          suffixIcon: GestureDetector(
            onTap: _openCategories,
            child: Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
            ),
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFB84D), Color(0xFFFF7A1A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Decorative dot grid, top-right and bottom-left corners.
            Positioned(top: 16, right: 16, child: _dotGrid()),
            Positioned(bottom: 16, left: 16, child: _dotGrid()),

            // Sparkle accents that gently twinkle beside the technician.
            AnimatedBuilder(
              animation: _sparkleAnim,
              builder: (context, child) => Positioned(
                top: 44,
                right: 118,
                child: Opacity(
                  opacity: _sparkleAnim.value,
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC94A), size: 20),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _sparkleAnim,
              builder: (context, child) => Positioned(
                top: 74,
                right: 6,
                child: Opacity(
                  opacity: 1.6 - _sparkleAnim.value,
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 12),
                ),
              ),
            ),

            // Text content — left column, always fully readable.
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 148, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // "Get 30% Off Today!" pill badge.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF241C15),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        children: [
                          TextSpan(text: '🏷️ Get '),
                          TextSpan(text: '30%', style: TextStyle(color: Color(0xFFFFC94A))),
                          TextSpan(text: ' Off Today!'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Heading — last line in white, rest in dark ink.
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.15, color: Color(0xFF241C15)),
                      children: [
                        TextSpan(text: 'Professional\nHelp for\n'),
                        TextSpan(text: 'Your Home', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Trust badges row — each is icon-on-top, label below, so
                  // narrow labels never get squeezed into a one-letter-per-line
                  // column the way a cramped horizontal Row did before.
                  Row(
                    children: [
                      _trustBadge(Icons.verified_user_rounded, 'Trusted\nExperts'),
                      _trustBadge(Icons.access_time_filled_rounded, 'On-Time\nService'),
                      _trustBadge(Icons.home_rounded, 'Quality\nGuaranteed'),
                    ],
                  ),
                ],
              ),
            ),

            // Technician illustration — bleeds off the bottom edge on the
            // right side, matching the reference banner, with a soft
            // continuous float animation.
            Positioned(
              right: -18,
              bottom: -14,
              child: AnimatedBuilder(
                animation: _floatAnim,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: child,
                ),
                child: Image.asset(
                  'assets/images/worker_illustration.png',
                  height: 190,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trustBadge(IconData icon, String label) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.55),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 15, color: const Color(0xFF241C15)),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF241C15), height: 1.2),
          ),
        ],
      ),
    );
  }

  Widget _dotGrid() {
    return SizedBox(
      width: 34,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: List.generate(
          16,
          (_) => Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.35), shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {required VoidCallback onViewAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1F36))),
        GestureDetector(
          onTap: onViewAll,
          child: const Text('View all', style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  static const Map<String, IconData> _categoryIcons = {
    'Electrician': Icons.electrical_services_rounded,
    'Plumber': Icons.plumbing_rounded,
    'AC Repair': Icons.ac_unit_rounded,
    'Appliance Repair': Icons.kitchen_rounded,
    'Roofer': Icons.roofing_rounded,
    'Carpenter': Icons.carpenter_rounded,
    'Painter': Icons.format_paint_rounded,
    'Refrigerator': Icons.kitchen_rounded,
    'Washing Machine': Icons.local_laundry_service_rounded,
    'RO Service': Icons.water_drop_rounded,
    'CCTV': Icons.videocam_rounded,
    'Home Cleaning': Icons.cleaning_services_rounded,
  };

  static const Map<String, String> _categoryImages = {
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

  Widget _buildCategoriesRow() {
    return Consumer<CategoryProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.categories.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final categories = provider.categories;
        if (categories.isEmpty) {
          return SizedBox(
            height: 84,
            child: Center(
              child: Text(
                provider.error != null ? 'Could not load services' : 'No services available yet',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          );
        }
        final shown = categories.take(9).toList();
        return SizedBox(
          height: 230,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: shown.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  mainAxisSpacing: 10,
  crossAxisSpacing: 2,
  childAspectRatio: 0.95,
),
itemBuilder: (context, i) {
  final cat = shown[i];
  final icon = _categoryIcons[cat.name] ?? Icons.build_rounded;
  final imagePath = _categoryImages[cat.name];
  return InkWell(
    borderRadius: BorderRadius.circular(18),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    onTap: () {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => IssueDetailsScreen(categoryId: cat.id, categoryName: cat.name),
      ));
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: 90,
            child: imagePath != null
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: Icon(icon, color: Colors.grey[500], size: 30),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: Icon(icon, color: Colors.grey[500], size: 30),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          cat.name,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)),
        ),
      ],
    ),
  );
},
          ),
        );
      },
    );
  }

  Widget _buildTechnicianList() {
    return Consumer<TechnicianProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.technicians.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final techs = provider.technicians;
        if (techs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            alignment: Alignment.center,
            child: Text(
              provider.error != null
                  ? 'Could not load technicians'
                  : 'No verified technicians yet — check back soon',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          );
        }
        return Column(
          children: techs.take(5).map<Widget>((t) => _TechnicianCard(technician: t)).toList(),
        );
      },
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  final Technician technician;
  const _TechnicianCard({required this.technician});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TechnicianDetailScreen(technician: technician),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4C6BF5), Color(0xFF2541D6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              child: Text(
                technician.name.isNotEmpty ? technician.name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(technician.name.isNotEmpty ? technician.name : 'Technician',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  Text(technician.categoryName,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFD166)),
                      const SizedBox(width: 2),
                      Text(
                        '${technician.ratingAvg.toStringAsFixed(1)} (${technician.ratingCount})',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 10),
                      Text('${technician.experienceYears} yrs exp',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                    ],
                  ),
                ],
              ),
            ),
            if (technician.isVerified)
              const Icon(Icons.verified_rounded, color: Colors.white, size: 20)
            else
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.8)),
          ],
        ),
      ),
    );
  }
}