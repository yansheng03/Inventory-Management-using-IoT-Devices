// lib/widgets/batch_review_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:capstone_app/models/food_item.dart';
import 'package:capstone_app/services/firebase_service.dart';
import 'package:capstone_app/widgets/food_item_dialog.dart';

class BatchReviewDialog extends StatelessWidget {
  // Removed alertId as we handle this locally now
  final List<dynamic> changes;

  const BatchReviewDialog({
    super.key,
    required this.changes,
  });

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
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: changes.length,
                itemBuilder: (context, index) {
                  final change = changes[index];
                  final name = change['name'] ?? 'Unknown';
                  final action = change['action'] ?? 'unknown';
                  final category = change['category'] ?? 'others';
                  final id = change['id'];

                  return ListTile(
                    leading: Icon(
                      action == 'added' ? Icons.add_circle : Icons.remove_circle,
                      color: action == 'added' ? Colors.green : Colors.red,
                    ),
                    title: Text(name.toUpperCase()),
                    subtitle: Text("$action - $category"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Edit Button
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () {
                            // Construct a temp FoodItem to pass to the dialog
                            // We use the ID so it updates the REAL doc
                            final item = FoodItem(
                              id: id,
                              name: name,
                              category: category,
                              quantity: 1, 
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
                             firebaseService.deleteFoodItem(id);
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
            // Simply close the dialog. No DB "dismiss" needed.
            Navigator.of(context).pop();
          },
          child: const Text("OK, All Good"),
        ),
      ],
    );
  }
}