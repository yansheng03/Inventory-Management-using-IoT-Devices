// lib/widgets/batch_review_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:capstone_app/widgets/food_item_dialog.dart';

class BatchReviewDialog extends StatefulWidget {
  final List<dynamic> changes;

  const BatchReviewDialog({
    super.key,
    required this.changes,
  });

  @override
  State<BatchReviewDialog> createState() => _BatchReviewDialogState();
}

class _BatchReviewDialogState extends State<BatchReviewDialog> {
  late List<dynamic> _localChanges;

  @override
  void initState() {
    super.initState();
    // Create a local copy of the list so we can modify it (delete items)
    _localChanges = List.from(widget.changes);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);

    return AlertDialog(
      title: const Text("Batch Update Detected"),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("The following items were recently changed:"),
            const SizedBox(height: 10),
            Flexible(
              child: _localChanges.isEmpty
                  ? const Center(child: Text("All items handled."))
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _localChanges.length,
                      itemBuilder: (context, index) {
                        final change = _localChanges[index];
                        final name = change['name'] ?? 'Unknown';
                        final action = change['action'] ?? 'unknown';
                        final category = change['category'] ?? 'others';
                        final quantity = change['quantity'] ?? 0; // NEW: Get Qty
                        final id = change['id'];

                        return ListTile(
                          leading: Icon(
                            action == 'added' ? Icons.add_circle : Icons.remove_circle,
                            color: action == 'added' ? Colors.green : Colors.red,
                          ),
                          title: Text(name.toUpperCase()),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("$action - $category"),
                              // NEW: Display Quantity
                              Text(
                                "Quantity: $quantity",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () {
                                  final item = FoodItem(
                                    id: id,
                                    name: name,
                                    category: category,
                                    quantity: quantity, 
                                    lastDetected: DateTime.now(),
                                  );
                                  
                                  showDialog(
                                    context: context,
                                    builder: (_) => FoodItemDialog(existingItem: item),
                                  );
                                },
                              ),
                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.grey),
                                onPressed: () {
                                   // 1. Delete from Firebase
                                   firebaseService.deleteFoodItem(id);
                                   
                                   // 2. Remove from UI immediately
                                   setState(() {
                                     _localChanges.removeAt(index);
                                   });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        // Add Button
        TextButton.icon(
          icon: const Icon(Icons.add),
          label: const Text("Add New Item"),
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const FoodItemDialog(),
            );
          },
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("OK"),
        ),
      ],
    );
  }
}