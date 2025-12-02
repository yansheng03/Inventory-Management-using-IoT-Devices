// lib/models/food_item.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/emoji_picker.dart';

class FoodItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final DateTime lastDetected;
  final String icon;

  static const List<String> validCategories = [
    'vegetables', 
    'fruit', 
    'meat', 
    'seafood',
    'dairy', 
    'bakery',
    'leftovers',
    'drinks', 
    'condiments', 
    'others'
  ];

  FoodItem({
    this.id = '',
    required this.name,
    required this.category,
    this.quantity = 1,
    required this.lastDetected,
  }) : icon = EmojiPicker.getEmojiForItem(name, category);

  factory FoodItem.fromFirestore(String id, Map<String, dynamic> data) {
    String name = data['name'] ?? 'No Name';
    String category = data['category'] ?? 'others';

    return FoodItem(
      id: id,
      name: name,
      category: category,
      quantity: (data['quantity'] ?? 0).toInt(),
      lastDetected: (data['lastDetected'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore(String ownerId, String deviceId) {
    return {
      'name': name,
      'name_normalized': name.toLowerCase(), 
      'category': category,
      'quantity': quantity,
      'lastDetected': Timestamp.fromDate(lastDetected),
      'owner_id': ownerId,
      'source_device_id': deviceId,
    };
  }

  Map<String, dynamic> toFirestoreUpdate() {
    return {
      'name': name,
      'name_normalized': name.toLowerCase(),
      'category': category,
      'quantity': quantity,
      'lastDetected': Timestamp.fromDate(lastDetected),
    };
  }
}