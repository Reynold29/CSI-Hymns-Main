import 'package:flutter/material.dart';
import 'package:hymns_latest/categories/dynamic_category_screen.dart';
import 'package:hymns_latest/screens/custom_categories_screen.dart';
import 'package:hymns_latest/screens/custom_category_viewer.dart';
import 'package:hymns_latest/services/supabase_service.dart';
import 'package:hymns_latest/utils/haptic_feedback_manager.dart';

class Categories extends StatefulWidget {
  const Categories({super.key});

  @override
  State<Categories> createState() => _CategoriesState();
}

class _CategoriesState extends State<Categories> {
  int _reloadToken = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Common Hymns',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_reloadToken),
              future: SupabaseService().fetchCustomCategoriesUnified(),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                if (snap.hasError) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Failed to load custom categories'),
                    ),
                  );
                }
                final customCats = (snap.data ?? []);
                final children = <Widget>[
                  _buildCategoryCard(context, "Birthday", [361], [215]),
                  _buildCategoryCard(context, "Marriage", [358, 359, 360], [188, 189, 190]),
                  _buildCategoryCard(context, "House Warming", [362], [227, 228, 229, 230, 231, 232, 233, 234]),
                  _buildCategoryCard(context, "Funeral", [310, 311,312], []),
                  _buildCategoryCard(context, "Mangala", null, [227, 228, 229, 230, 231, 232, 233, 234]),
                  _buildCategoryCard(context, "Children's Prayer", [328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349], [200, 201, 202, 203, 204, 205, 206, 207, 208, 209]),
                  _buildCategoryCard(context, "Lord's Supper", [273, 274, 275, 276, 277, 278, 279], [184, 185, 186, 187]),
                  _buildCategoryCard(context, "Travelling", [363], []),
                  _buildCategoryCard(context, "Sickness", [367], []),
                  // Dynamic custom categories cards
                  ...customCats.map((c) => _buildCustomCategoryRuntimeCard(context, (c['name'] as String), (c['id'] as num).toInt())),
                  // Persistent create card
                  _buildCustomCategoriesCard(context),
                ];
                return SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                  ),
                  delegate: SliverChildListDelegate(children),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Legacy chip builder removed in favor of grid cards

  Widget _buildCategoryCard(BuildContext context, String category, List<int>? hymnNumbers, List<int>? keerthaneNumbers) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        await HapticFeedbackManager.lightClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DynamicCategoryScreen(
              category: category,
              hymnNumbers: hymnNumbers,
              keerthaneNumbers: keerthaneNumbers,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildCustomCategoriesCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FutureBuilder<int?>(
      future: _guestRemainingSlots(),
      builder: (context, snap) {
        final showBadge = (snap.data != null);
        final remaining = snap.data ?? 0;
        return InkWell(
          onTap: () async {
            await HapticFeedbackManager.lightClick();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomCategoriesScreen()),
            );
            if (mounted) setState(() => _reloadToken++);
          },
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primaryContainer, colorScheme.secondaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, color: colorScheme.onPrimaryContainer),
                      const SizedBox(width: 8),
                      Text('Custom', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              if (showBadge)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: colorScheme.outlineVariant),
                    ),
                    child: Text('$remaining/${SupabaseService.localCategoryLimit}', style: Theme.of(context).textTheme.labelSmall),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomCategoryRuntimeCard(BuildContext context, String name, int categoryId) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        await HapticFeedbackManager.lightClick();
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomCategoryViewerScreen(categoryId: categoryId, categoryName: name),
          ),
        );
        if (mounted) setState(() => _reloadToken++);
      },
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Center(
          child: Text(name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
        ),
      ),
    );
  }

  Future<int?> _guestRemainingSlots() async {
    final svc = SupabaseService();
    if (svc.currentUser != null) return null; // hide badge for logged-in users
    final rows = await svc.fetchCustomCategoriesUnified();
    final active = rows.where((e) => (e['deleted'] ?? 0) == 0).length;
    return (SupabaseService.localCategoryLimit - active).clamp(0, SupabaseService.localCategoryLimit);
  }
}
