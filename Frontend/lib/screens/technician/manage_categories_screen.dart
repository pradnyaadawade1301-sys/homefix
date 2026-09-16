import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/category_provider.dart';

/// Lets an already-approved technician add or remove the categories they
/// serve (e.g. add Painting to an existing Plumbing profile) — reachable
/// from the technician's own Profile screen. Reuses the same category chip
/// picker as TechnicianKycScreen, but pre-checks whatever the technician
/// already has (TechnicianKycProvider.profile.categoryIds) and saves via
/// PUT /technicians/me/categories instead of the one-time registration POST.
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  late Set<String> _selectedCategoryIds;
  bool _saving = false;
  String? _localError;

  @override
  void initState() {
    super.initState();
    final profile = context.read<TechnicianKycProvider>().profile;
    _selectedCategoryIds = {...(profile?.categoryIds ?? const [])};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().fetchCategories();
    });
  }

  Future<void> _handleSave() async {
    if (_selectedCategoryIds.isEmpty) {
      setState(() => _localError = 'Select at least one category');
      return;
    }
    setState(() {
      _saving = true;
      _localError = null;
    });
    final ok = await context.read<TechnicianKycProvider>().updateCategories(_selectedCategoryIds.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categories updated')),
      );
      Navigator.of(context).pop();
    } else {
      setState(() => _localError = context.read<TechnicianKycProvider>().error ?? 'Could not save — try again');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pick every service you offer — customers can find and book you under any of these.',
                style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Consumer<CategoryProvider>(
                    builder: (context, catProvider, _) {
                      if (catProvider.isLoading && catProvider.categories.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: catProvider.categories.map((c) {
                          final selected = _selectedCategoryIds.contains(c.id);
                          return FilterChip(
                            label: Text(c.name),
                            selected: selected,
                            onSelected: (v) => setState(() {
                              if (v) {
                                _selectedCategoryIds.add(c.id);
                              } else {
                                _selectedCategoryIds.remove(c.id);
                              }
                            }),
                            selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                            checkmarkColor: AppTheme.primaryColor,
                            labelStyle: TextStyle(
                              color: selected ? AppTheme.primaryColor : Colors.black87,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                            ),
                            side: BorderSide(color: selected ? AppTheme.primaryColor : Colors.grey.shade300),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ),
              if (_localError != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_localError!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _handleSave,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}