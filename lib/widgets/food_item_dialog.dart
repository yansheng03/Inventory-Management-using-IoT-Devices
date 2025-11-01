// lib/widgets/food_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/providers/food_tracker_state.dart';

class FoodItemDialog extends StatefulWidget {
  // This optional item is the key to editing
  final FoodItem? existingItem;
  
  const FoodItemDialog({super.key, this.existingItem});

  @override
  State<FoodItemDialog> createState() => _FoodItemDialogState();
}

class _FoodItemDialogState extends State<FoodItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedCategory = 'vegetables'; // Default category

  bool _isAdding = false;
  bool get _isEditing => widget.existingItem != null;

  final List<String> _categories = [
    'vegetables', 'fruit', 'meat', 'dairy',
    'packaged', 'drinks', 'condiments', 'others',
  ];

  @override
  void initState() {
    super.initState();
    
    // If we are editing, pre-fill the form fields
    if (_isEditing) {
      _nameController.text = widget.existingItem!.name;
      _quantityController.text = widget.existingItem!.quantity.toString();
      _selectedCategory = widget.existingItem!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isAdding = true);

      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final name = _nameController.text;
      
      final foodTrackerState = context.read<FoodTrackerState>();

      try {
        if (_isEditing) {
          // --- EDIT LOGIC ---
          // Create an updated item model with the existing ID
          final updatedItem = FoodItem(
            id: widget.existingItem!.id, // Keep the original ID
            name: name,
            category: _selectedCategory,
            quantity: quantity,
            lastDetected: DateTime.now(), // Update timestamp on edit
          );
          await foodTrackerState.updateItem(updatedItem);

        } else {
          // --- ADD LOGIC ---
          // Create a new item (ID will be set by the model)
          final newItem = FoodItem(
            name: name,
            category: _selectedCategory,
            quantity: quantity,
            lastDetected: DateTime.now(),
          );
          // This now calls our new "upsert" logic
          await foodTrackerState.addItem(newItem); 
        }

        if (mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        print("Error submitting form: $e");
        // TODO: Show a SnackBar error to the user
      } finally {
        if (mounted) {
          setState(() => _isAdding = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      // Dynamic title
      title: Text(_isEditing ? 'Edit Food Item' : 'Add Food Item'),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Item Name'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: _quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter a quantity';
                    }
                    final number = int.tryParse(value);
                    if (number == null) {
                      return 'Enter a valid number';
                    }
                    if (number < 0) { // Quantity can't be negative
                      return 'Quantity must be 0 or more';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: _categories.map<DropdownMenuItem<String>>((
                    String category,
                  ) {
                    String displayText =
                        category[0].toUpperCase() + category.substring(1);
                    return DropdownMenuItem<String>(
                      value: category,
                      child: Text(displayText),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val!),
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAdding ? null : _submitForm,
          child: _isAdding
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              // Dynamic button text
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}