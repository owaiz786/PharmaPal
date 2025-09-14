// lib/scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:pharmaapp/create_medicine_screen.dart';
import 'package:pharmaapp/app_background.dart'; // UPDATED: Import the background widget

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final ApiService _apiService = ApiService();
  bool _isProcessing = false;

  // --- ALL YOUR LOGIC FUNCTIONS ARE UNCHANGED ---
  void _showQuantityDialog(String gs1Data) {
    final quantityController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Enter Quantity'),
        content: TextField(
          controller: quantityController,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Quantity Received'),
        ),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _resetScanner(); }, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0) return;

              try {
                await _apiService.addInventoryFromGS1(gs1Data, quantity);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GS1 Inventory added successfully!'), backgroundColor: Colors.green));
                _resetScanner();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red));
              }
            },
            child: const Text('Submit'),
          )
        ],
      ),
    );
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodeValue = capture.barcodes.first.rawValue;
    if (barcodeValue == null) return;
    setState(() { _isProcessing = true; });
    _scannerController.stop();

    if (barcodeValue.contains('(01)') && barcodeValue.contains('(10)') && barcodeValue.contains('(17)')) {
      _showQuantityDialog(barcodeValue);
    } else {
      try {
        final medicine = await _apiService.fetchMedicineByBarcode(barcodeValue);
        _showAddInventoryDialog(medicine);
      } catch (e) {
        if (e.toString().contains('not found')) {
          final result = await Navigator.push<Medicine>(
            context,
            MaterialPageRoute(builder: (context) => CreateMedicineScreen(barcode: barcodeValue)),
          );
          if (result != null) {
            _showAddInventoryDialog(result);
          } else {
            _resetScanner();
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst("Exception: ", "")), backgroundColor: Colors.red));
          _resetScanner();
        }
      }
    }
  }

  void _showAddInventoryDialog(Medicine medicine) {
    final lotNumberController = TextEditingController();
    final quantityController = TextEditingController();
    final expiryDate = ValueNotifier<DateTime>(DateTime.now());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Add to Inventory: ${medicine.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: lotNumberController, decoration: const InputDecoration(labelText: 'Lot Number')),
                TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number),
                const SizedBox(height: 20),
                ValueListenableBuilder<DateTime>(
                  valueListenable: expiryDate,
                  builder: (context, value, child) {
                    return InkWell(
                      onTap: () async {
                        final pickedDate = await showDatePicker(
                          context: context,
                          initialDate: value,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (pickedDate != null) {
                          expiryDate.value = pickedDate;
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Expiry Date'),
                        child: Text("${value.toLocal()}".split(' ')[0]),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(context); _resetScanner(); }, child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _apiService.addInventoryItem(
                    medicineId: medicine.id,
                    lotNumber: lotNumberController.text,
                    quantity: int.parse(quantityController.text),
                    expiryDate: expiryDate.value,
                  );
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Inventory added successfully!'), backgroundColor: Colors.green),
                  );
                  _resetScanner();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _resetScanner() {
    setState(() { _isProcessing = false; });
    _scannerController.start();
  }

  // UPDATED: The build method is now simplified and includes the AppBackground
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // The drawer is removed, and this will now show a back arrow
      appBar: AppBar(
        title: const Text('Scan to Receive Stock'),
      ),
      body: AppBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Point camera at a barcode',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                width: 300,
                // Using a ClipRRect to give the scanner view rounded corners
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetect,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
}