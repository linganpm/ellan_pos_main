import 'package:flutter/material.dart';
import '../../core/utils/font_utility.dart';
import '../../data/models/category_model.dart';
import 'product_item_card.dart';

/// Colorful, touch-friendly category selector for the product picker.
class CategoryCard extends StatelessWidget {
  final CategoryModel category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ProductItemCard.accentFor(category.id);
    return Semantics(
      button: true,
      selected: isSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 14, bottom: 4),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: isSelected ? 0.38 : 0.18),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    category.name,
                    style: FontUtility.subheading.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
