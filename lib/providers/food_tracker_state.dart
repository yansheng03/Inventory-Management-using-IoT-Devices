import 'package:flutter/material.dart';
import '../models/food_item.dart';

class FoodTrackerState extends ChangeNotifier {
  String selectedCategory = 'all';
  String searchQuery = '';

  final List<FoodItem> _allItems = [
    FoodItem('Tomatoes', 'vegetables', '3 pcs', 'Best before Nov 28', 'in fridge', '🍅'),
    FoodItem('Potatoes', 'vegetables', '5 pcs', 'Best before Dec 15', 'in cupboard', '🥔'),
    FoodItem('Cabbage', 'vegetables', '2 pcs', 'Best before Dec 4', 'in fridge', '🥬'),
    FoodItem('Broccoli', 'vegetables', '4 pcs', 'Best before Nov 30', 'in fridge', '🥦'),
    FoodItem('Chicken Breast', 'meat', '2 packs', 'Best before Dec 1', 'in freezer', '🍗'),
    FoodItem('Milk', 'dairy', '2 bottles', 'Best before Nov 25', 'in fridge', '🥛'),
    FoodItem('Apples', 'fruit', '6 pcs', 'Best before Dec 10', 'in fridge', '🍎'),
  ];

  List<FoodItem> get filteredItems {
    return _allItems.where((item) {
      final matchesCategory =
          selectedCategory == 'all' || item.category == selectedCategory;
      final matchesSearch =
          item.name.toLowerCase().contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void updateSearch(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void addItem(FoodItem item) {
    _allItems.add(item);
    notifyListeners();
  }
}
