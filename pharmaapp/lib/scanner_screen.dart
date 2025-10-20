import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:pharmaapp/api_service.dart';
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
  bool _isProcessing = false;

  void _showQuantityDialog(String gs1Data) {
    final apiService = Provider.of<ApiService>(context, listen: false);
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

              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              if (!mounted) return;

              try {
                await apiService.addInventoryFromGS1(gs1Data, quantity);
                
                if (!mounted) return;
                navigator.pop(); // Close dialog
                
                // Wait a bit for dialog to close, then navigate back to home
                await Future.delayed(const Duration(milliseconds: 100));
                if (mounted) {
                  Navigator.of(context).pop(); // Go back to home page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('GS1 Inventory added successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (!mounted) return;
                navigator.pop(); // Close dialog on error
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(e.toString().replaceFirst("Exception: ", "")),
                    backgroundColor: Colors.red,
                  ),
                );
                _resetScanner();
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _onBarcodeDetect(BarcodeCapture capture) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (_isProcessing) return;
    final barcodeValue = capture.barcodes.first.rawValue;
    if (barcodeValue == null) return;
    
    setState(() { _isProcessing = true; });
    _scannerController.stop();

    // Check if it's a GS1 barcode
    if (barcodeValue.contains('(01)') && barcodeValue.contains('(10)') && barcodeValue.contains('(17)')) {
      _showQuantityDialog(barcodeValue);
    } else {
      try {
        final medicine = await apiService.fetchMedicineByBarcode(barcodeValue);
        if (!mounted) return;
        _showAddInventoryDialog(medicine);
      } catch (e) {
        if (!mounted) return;
        if (e.toString().contains('not found')) {
          final result = await navigator.push<Medicine>(
            MaterialPageRoute(builder: (context) => CreateMedicineScreen(barcode: barcodeValue)),
          );
          if (result != null) {
            _showAddInventoryDialog(result);
          } else {
            _resetScanner();
          }
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceFirst("Exception: ", "")),
              backgroundColor: Colors.red,
            ),
          );
          _resetScanner();
        }
      }
    }
  }

  void _showAddInventoryDialog(Medicine medicine) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final lotNumberController = TextEditingController();
    final quantityController = TextEditingController();
    // Default expiry date is 1 year from now
    final expiryDate = ValueNotifier<DateTime>(DateTime.now().add(const Duration(days: 365)));

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
                  decoration: const InputDecoration(
                    labelText: 'Lot Number (Optional)',
                    hintText: 'Auto-generated if empty',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity Received'),
                ),
                const SizedBox(height: 16),
                ValueListenableBuilder<DateTime>(
                  valueListenable: expiryDate,
                  builder: (context, date, _) {
                    return ListTile(
                      title: const Text('Expiry Date'),
                      subtitle: Text('${date.day}/${date.month}/${date.year}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          expiryDate.value = picked;
                        }
                      },
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
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                if (!mounted) return;

                try {
                  await apiService.addInventoryItem(
                    medicineId: medicine.id,
                    lotNumber: lotNumberController.text.isEmpty 
                        ? 'LOT-${DateTime.now().millisecondsSinceEpoch}' 
                        : lotNumberController.text,
                    quantity: quantity,
                    expiryDate: expiryDate.value,
                  );
                  
                  if (!mounted) return;
                  navigator.pop(); // Close dialog
                  
                  // Wait a bit for dialog to close, then navigate back to home
                  await Future.delayed(const Duration(milliseconds: 100));
                  if (mounted) {
                    Navigator.of(context).pop(); // Go back to home page
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Inventory added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (!mounted) return;
                  navigator.pop(); // Close dialog on error
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                    ),
                  );
                  _resetScanner();
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
    if (!mounted) return;
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
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackground(
        child: Column(
          children: [
            // Status indicator at the top
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
                            // Processing overlay
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
                    // Cancel button when processing
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