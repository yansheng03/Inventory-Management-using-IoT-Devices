// lib/models/food_item.dart
import '../utils/emoji_picker.dart'; // <-- Import our new helper

class FoodItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final DateTime lastDetected;
  final String icon; // <-- This is now a computed app-only field

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.lastDetected,
    required this.icon, // <-- Add to constructor
  });

  // Factory to create a FoodItem from a PocketBase record
  factory FoodItem.fromJson(Map<String, dynamic> json, String id) {
    String name = json['item_name'] ?? 'No Name';
    String category = json['category'] ?? 'others';

    return FoodItem(
      id: id,
      name: name,
      category: category,
      quantity: (json['quantity'] ?? 0).toInt(),
      lastDetected: DateTime.parse(json['last_detected']),
      // --- EMOJI LOGIC ---
      // Compute the icon based on name and category
      icon: EmojiPicker.getEmojiForItem(name, category),
    );
  }

  // Method to convert a FoodItem to JSON for sending to PocketBase
  // Notice 'icon' is NOT included here, as it's not in your DB schema.
  Map<String, dynamic> toJson() {
    return {
      'item_name': name,
      'category': category,
      'quantity': quantity,
      'last_detected': lastDetected.toIso8601String(),
    };
  }
}