// lib/widgets/food_item_dialog.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/providers/food_tracker_state.dart';

class FoodItemDialog extends StatefulWidget {
  final FoodItem? existingItem;
  
  const FoodItemDialog({super.key, this.existingItem});

  @override
  State<FoodItemDialog> createState() => _FoodItemDialogState();
}

class _FoodItemDialogState extends State<FoodItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedCategory = 'vegetables'; 

  bool _isAdding = false;
  bool get _isEditing => widget.existingItem != null;

  final List<String> _categories = FoodItem.validCategories;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.existingItem!.name;
      _quantityController.text = widget.existingItem!.quantity.toString();
      _selectedCategory = widget.existingItem!.category;
      
      if (!_categories.contains(_selectedCategory)) {
        _selectedCategory = 'others'; 
      }
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
          final updatedItem = FoodItem(
            id: widget.existingItem!.id, 
            name: name,
            category: _selectedCategory,
            quantity: quantity,
            lastDetected: DateTime.now(), 
          );
          await foodTrackerState.updateItem(updatedItem);
          
          if (mounted) Navigator.pop(context, updatedItem); 

        } else {
          final newItem = FoodItem(
            name: name,
            category: _selectedCategory,
            quantity: quantity,
            lastDetected: DateTime.now(),
          );
          await foodTrackerState.addItem(newItem); 
          
          // Return the new item
          if (mounted) Navigator.pop(context, newItem);
        }

      } catch (e) {
        final message = e.toString().replaceAll("Exception: ", "");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(message), backgroundColor: Colors.red),
           );
        }
      } finally {
        if (mounted) setState(() => _isAdding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    if (value == null || value.isEmpty) return 'Enter a quantity';
                    final number = int.tryParse(value);
                    if (number == null || number < 0) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  items: _categories.map<DropdownMenuItem<String>>((String category) {
                    String displayText = category[0].toUpperCase() + category.substring(1);
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}