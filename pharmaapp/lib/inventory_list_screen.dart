// lib/inventory_list_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:pharmaapp/medicine_detail_screen.dart';
import 'package:pharmaapp/scanner_screen.dart';
import 'package:pharmaapp/app_background.dart'; // UPDATED: Import the new background widget

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Medicine>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _medicinesFuture = _apiService.fetchAllMedicines();
  }

  Future<void> _refreshInventory() async {
    setState(() {
      _medicinesFuture = _apiService.fetchAllMedicines();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('View Inventory'),
              onTap: () { Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Scan Item'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen()));
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Current Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInventory,
            tooltip: 'Refresh List',
          ),
        ],
      ),
      // UPDATED: The body is now wrapped with the AppBackground widget
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: _refreshInventory,
          child: FutureBuilder<List<Medicine>>(
            future: _medicinesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                // Completed the error UI
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _refreshInventory,
                        child: const Text('Try Again'),
                      )
                    ],
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                // Completed the empty state UI
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No medicines found.', style: TextStyle(fontSize: 18)),
                      Text('Pull down to refresh, or scan an item.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              }

              final medicines = snapshot.data!;
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: medicines.length,
                itemBuilder: (context, index) {
                  final medicine = medicines[index];
                  return Dismissible(
                    key: Key(medicine.id.toString()),
                    // Completed the Dismissible logic
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) async {
                      try {
                        await _apiService.deleteMedicine(medicine.id);
                        setState(() {
                          medicines.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${medicine.name} deleted'), backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.medication_outlined),
                        title: Text(medicine.name),
                        subtitle: Text(medicine.manufacturer ?? 'N/A'),
                        trailing: Text('Stock: ${medicine.totalQuantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => MedicineDetailScreen(medicine: medicine)),
                          ).then((_) => _refreshInventory());
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}