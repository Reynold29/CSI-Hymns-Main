import 'package:flutter/material.dart';
import 'package:hymns_latest/categories/dynamic_category_screen.dart';

class Categories extends StatelessWidget {
  const Categories({super.key});

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
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.9,
              ),
              delegate: SliverChildListDelegate([
                _buildCategoryCard(context, "Birthday", [361], [215]),
                _buildCategoryCard(context, "Marriage", [358, 359, 360], [188, 189, 190]),
                _buildCategoryCard(context, "House Warming", [362], [227, 228, 229, 230, 231, 232, 233, 234]),
                _buildCategoryCard(context, "Funeral", [310, 311,312], []),
                _buildCategoryCard(context, "Mangala", null, [227, 228, 229, 230, 231, 232, 233, 234]),
                _buildCategoryCard(context, "Children's Prayer", [328, 329, 330, 331, 332, 333, 334, 335, 336, 337, 338, 339, 340, 341, 342, 343, 344, 345, 346, 347, 348, 349], [200, 201, 202, 203, 204, 205, 206, 207, 208, 209]),
                _buildCategoryCard(context, "Lord's Supper", [273, 274, 275, 276, 277, 278, 279], [184, 185, 186, 187]),
                _buildCategoryCard(context, "Travelling", [363], []),
                _buildCategoryCard(context, "Sickness", [367], []),
              ]),
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
      onTap: () {
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
}
