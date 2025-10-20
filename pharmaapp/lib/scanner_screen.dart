// lib/scanner_screen.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/auth_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:pharmaapp/create_medicine_screen.dart';
import 'package:pharmaapp/app_background.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  late final ApiService _apiService;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(AuthService());
  }

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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetScanner();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity <= 0) return;

              try {
                await _apiService.addInventoryFromGS1(gs1Data, quantity);
                Navigator.pop(context); // Close dialog first
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('GS1 Inventory added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _resetScanner(); // Then reset scanner
              } catch (e) {
                Navigator.pop(context); // Close dialog on error too
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst("Exception: ", "")),
                    backgroundColor: Colors.red,
                  ),
                );
                _resetScanner(); // Reset scanner even on error
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcodeValue = capture.barcodes.first.rawValue;
    if (barcodeValue == null) return;
    
    setState(() {
      _isProcessing = true;
    });
    _scannerController.stop(); // Stop scanner during processing

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
            MaterialPageRoute(
              builder: (context) => CreateMedicineScreen(barcode: barcodeValue),
            ),
          );
          if (result != null) {
            _showAddInventoryDialog(result);
          } else {
            _resetScanner(); // Reset if user cancels creation
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst("Exception: ", "")),
              backgroundColor: Colors.red,
            ),
          );
          _resetScanner(); // Reset on other errors
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
                TextField(
                  controller: lotNumberController,
                  decoration: const InputDecoration(labelText: 'Lot Number'),
                ),
                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                ),
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetScanner();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final quantity = int.tryParse(quantityController.text) ?? 0;
                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid quantity'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                try {
                  await _apiService.addInventoryItem(
                    medicineId: medicine.id,
                    lotNumber: lotNumberController.text.isEmpty 
                        ? 'LOT-${DateTime.now().millisecondsSinceEpoch}' 
                        : lotNumberController.text,
                    quantity: quantity,
                    expiryDate: expiryDate.value,
                  );
                  Navigator.pop(context); // Close dialog first
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Inventory added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _resetScanner(); // Then reset scanner
                } catch (e) {
                  Navigator.pop(context); // Close dialog on error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _resetScanner(); // Reset scanner on error too
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
    // Simply start the scanner without checking if it's already starting
    _scannerController.start();
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan to Receive Stock'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            _scannerController.dispose();
            Navigator.pop(context);
          },
        ),
      ),
      body: AppBackground(
        child: Column(
          children: [
            // Status indicator
            Container(
              padding: const EdgeInsets.all(8.0),
              color: _isProcessing ? Colors.orange.withOpacity(0.1) : Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isProcessing ? Icons.hourglass_top : Icons.qr_code_scanner,
                    color: _isProcessing ? Colors.orange : Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isProcessing ? 'Processing...' : 'Ready to scan',
                    style: TextStyle(
                      color: _isProcessing ? Colors.orange : Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            MobileScanner(
                              controller: _scannerController,
                              onDetect: _onBarcodeDetect,
                            ),
                            if (_isProcessing)
                              Container(
                                color: Colors.black.withOpacity(0.7),
                                child: const Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircularProgressIndicator(color: Colors.white),
                                      SizedBox(height: 16),
                                      Text(
                                        'Processing...',
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isProcessing)
                      ElevatedButton(
                        onPressed: _resetScanner,
                        child: const Text('Cancel & Resume Scanning'),
                      ),
                  ],
                ),
              ),
            ),
          ],
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