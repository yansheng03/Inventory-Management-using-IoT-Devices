import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/food_tracker_state.dart';

class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;

  const CategoryChip({super.key, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    var appState = context.read<FoodTrackerState>();
    return GestureDetector(
      onTap: () => appState.setCategory(label),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.green[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.green : Colors.grey.shade300),
        ),
        child: Text(
          label[0].toUpperCase() + label.substring(1),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: selected ? Colors.green[700] : Colors.grey[600],
          ),
        ),
      ),
    );
  }
}
