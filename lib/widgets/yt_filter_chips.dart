import 'package:flutter/material.dart';

/// YouTube Music category & mood filter chips row.
class YtFilterChips extends StatelessWidget {
  final String? selectedChip;
  final ValueChanged<String?> onChipSelected;

  const YtFilterChips({
    super.key,
    this.selectedChip,
    required this.onChipSelected,
  });

  static const List<String> categories = [
    'Podcasts',
    'Romance',
    'Relax',
    'Feel good',
    'Energise',
    'Commute',
    'Party',
    'Work out',
    'Sad',
    'Focus',
    'Sleep',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedChip == cat;

          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == categories.length - 1 ? 0 : 4,
            ),
            child: InkWell(
              onTap: () {
                onChipSelected(isSelected ? null : cat);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFF212121),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.white : const Color(0x2AFFFFFF),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white,
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
