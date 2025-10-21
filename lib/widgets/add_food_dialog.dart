// lib/widgets/add_food_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/food_item.dart';
import '../providers/food_tracker_state.dart';
import '../services/pocketbase_service.dart'; // <-- Ensure PocketBaseService is imported
// import '../providers/device_provider.dart'; // No longer needed here
import '../utils/emoji_picker.dart';

class AddFoodDialog extends StatefulWidget {
  final FoodItem? itemToEdit;
  const AddFoodDialog({super.key, this.itemToEdit});

  @override
  State<AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<AddFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedCategory = 'vegetables';

  bool _isProcessing = false;
  bool get _isEditing => widget.itemToEdit != null;

  final List<String> _categories = [
    'vegetables', 'fruit', 'meat', 'dairy',
    'packaged', 'drinks', 'condiments', 'others',
  ];

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.itemToEdit!;
      _nameController.text = item.name;
      _quantityController.text = item.quantity.toString();
      _selectedCategory = item.category;
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
      setState(() => _isProcessing = true);

      final quantity = int.tryParse(_quantityController.text) ?? 0;
      final name = _nameController.text;

      // --- START OF MODIFICATION ---

      // V V V RESTORE THESE LINES V V V
      // --- Get the current user's linked device ID ---
      final pbService = PocketBaseService(); // Get the singleton instance
      final deviceId = pbService.getCurrentUserDeviceID(); // Fetch the ID

      // V V V REMOVE THIS LINE V V V
      // const String deviceId = DeviceProvider.dummyDeviceId; // Remove dummy constant usage

      // V V V RESTORE THIS CHECK V V V
      // --- Check if device ID was found ---
      if (deviceId == null || deviceId.isEmpty) {
         print("Error: Could not find linked device ID for the current user.");
         // Check context validity before showing SnackBar
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: User device link missing in profile.')),
            );
         }
         setState(() => _isProcessing = false);
         return; // Stop processing if no device ID
      }
      // --- END OF MODIFICATION ---


      if (_isEditing) {
        // --- UPDATE LOGIC ---
        final updatedItem = FoodItem(
          id: widget.itemToEdit!.id,
          name: name,
          category: _selectedCategory,
          quantity: quantity,
          lastDetected: DateTime.now(),
          icon: EmojiPicker.getEmojiForItem(name, _selectedCategory),
          sourceDevice: deviceId, // <-- Uses the real deviceId variable
        );
        // Use context.read safely if context might become invalid during async gap
        if (mounted) await context.read<FoodTrackerState>().updateItem(updatedItem);
      } else {
        // --- ADD LOGIC ---
        final newItem = FoodItem(
          id: '', // PocketBase generates ID
          name: name,
          category: _selectedCategory,
          quantity: quantity,
          lastDetected: DateTime.now(),
          icon: EmojiPicker.getEmojiForItem(name, _selectedCategory),
          sourceDevice: deviceId, // <-- Uses the real deviceId variable
        );
         if (mounted) await context.read<FoodTrackerState>().addItem(newItem);
      }


      if (mounted) {
        setState(() => _isProcessing = false);
        Navigator.pop(context);
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
                    if (value == null || value.isEmpty) {
                      return 'Enter a quantity';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Enter a valid number';
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
          onPressed: _isProcessing ? null : _submitForm,
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}