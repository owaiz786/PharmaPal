// lib/medicine_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:pharmaapp/edit_medicine_screen.dart';
import 'package:intl/intl.dart';

class MedicineDetailScreen extends StatefulWidget {
  final Medicine medicine;
  const MedicineDetailScreen({super.key, required this.medicine});

  @override
  State<MedicineDetailScreen> createState() => _MedicineDetailScreenState();
}

class _MedicineDetailScreenState extends State<MedicineDetailScreen> {
  late Medicine _currentMedicine;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _currentMedicine = widget.medicine;
  }

  // --- RESTOCK DIALOG ---
  void _showRestockDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Stock to Lot #: ${item.lotNumber}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity to Add'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0) return;
              try {
                await _apiService.restockItem(
                    itemId: item.id, quantity: quantity);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Stock added successfully!'),
                    backgroundColor: Colors.green));
                await _refreshMedicineData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('Add Stock'),
          ),
        ],
      ),
    );
  }

  // --- DISPENSE DIALOG ---
  void _showDispenseDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dispense from Lot #: ${item.lotNumber}'),
        content: TextField(
          controller: quantityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              labelText: 'Quantity to Dispense (Max: ${item.quantity})'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0 || quantity > item.quantity) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Invalid quantity.'),
                    backgroundColor: Colors.orange));
                return;
              }
              try {
                await _apiService.dispenseItem(
                    itemId: item.id, quantity: quantity);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Dispensed successfully!'),
                    backgroundColor: Colors.green));
                await _refreshMedicineData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(e.toString()), backgroundColor: Colors.red));
              }
            },
            child: const Text('Dispense'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Medicine?'),
      content: Text('Are you sure you want to delete "${_currentMedicine.name}" and all of its stock? This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () async {
            try {
              await _apiService.deleteMedicine(_currentMedicine.id);
              Navigator.pop(context); // Close the dialog
              Navigator.pop(context); // Go back from the detail screen
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_currentMedicine.name} was deleted.'), backgroundColor: Colors.green),
              );
            } catch (e) {
              Navigator.pop(context); // Close the dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
              );
            }
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

  // --- REFRESH MEDICINE DATA ---
  Future<void> _refreshMedicineData() async {
    try {
      final updatedMedicine =
          await _apiService.fetchMedicineById(_currentMedicine.id);
      setState(() {
        _currentMedicine = updatedMedicine;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Could not refresh data: $e"),
          backgroundColor: Colors.red));
    }
  }

  // Note: Use the same instance name as other files — replace `_api_service` with `_apiService` if you use that elsewhere.
  // Above I used `_api_service` inside dialogs to match typical naming; if you prefer `_apiService`, change consistently.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMedicine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Details',
            onPressed: () async {
              final result = await Navigator.push<Medicine>(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      EditMedicineScreen(medicine: _currentMedicine),
                ),
              );
              if (result != null) {
                setState(() {
                  _currentMedicine = result;
                });
              }
            },
          ),
          IconButton(
          icon: const Icon(Icons.delete_forever),
          tooltip: 'Delete Medicine',
          onPressed: _showDeleteConfirmationDialog,
        ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card — showing manufacturer, total stock & price instead of category
            Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentMedicine.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text('Manufacturer: ${_currentMedicine.manufacturer ?? 'N/A'}'),
                    Text('Total Stock: ${_currentMedicine.totalQuantity} units'),
                    Text('Price: \$${_currentMedicine.price.toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Batches in Stock',
                style: Theme.of(context).textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _currentMedicine.inventoryItems.length,
                itemBuilder: (context, index) {
                  final item = _currentMedicine.inventoryItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      title: Text('Lot #: ${item.lotNumber}'),
                      subtitle: Text(
                          'Expires: ${DateFormat.yMMMd().format(item.expiryDate)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Qty: ${item.quantity}',
                              style: Theme.of(context).textTheme.titleMedium),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.green),
                            onPressed: () => _showRestockDialog(item),
                            tooltip: 'Add Stock',
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle,
                                color: Colors.redAccent),
                            onPressed: () => _showDispenseDialog(item),
                            tooltip: 'Dispense Item',
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
