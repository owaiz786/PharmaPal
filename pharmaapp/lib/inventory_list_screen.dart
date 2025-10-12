// lib/inventory_list_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:pharmaapp/medicine_detail_screen.dart';
import 'package:pharmaapp/scanner_screen.dart';
import 'package:pharmaapp/app_background.dart';
import 'package:pharmaapp/ocr_screen.dart';
import 'package:pharmaapp/chat_bot_screen.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

FlutterSoundRecorder? _recorder;
bool _isRecorderInitialized = false;
bool _isRecording = false;
String? _audioPath;

class _InventoryListScreenState extends State<InventoryListScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Medicine>> _medicinesFuture;

  @override
  void initState() {
    super.initState();
    _medicinesFuture = _apiService.fetchAllMedicines();
    _recorder = FlutterSoundRecorder();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw RecordingPermissionException('Microphone permission not granted');
    }
    await _recorder!.openRecorder();
    _isRecorderInitialized = true;
  }

  @override
  void dispose() {
    _recorder!.closeRecorder();
    _recorder = null;
    super.dispose();
  }

  // --- RECORDING LOGIC ---
  void _toggleRecording() async {
    if (!_isRecorderInitialized) return;

    if (_isRecording) {
      final path = await _recorder!.stopRecorder();
      setState(() {
        _isRecording = false;
        _audioPath = path;
      });
      if (_audioPath != null) {
        _processRecordedAudio(File(_audioPath!));
      }
    } else {
      setState(() => _isRecording = true);
      await _recorder!.startRecorder(toFile: 'temp_audio.aac');
    }
  }

  void _processRecordedAudio(File audioFile) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text("Processing..."),
          ],
        ),
      ),
    );

    try {
      await _apiService.processVoiceAudio(audioFile);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item added via voice!'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshInventory();
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(e.toString().replaceFirst("Exception: ", "")),
          backgroundColor: Colors.red,
        ),
      );
    }
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
              child: Text(
                'Menu',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.inventory, color: Colors.teal),
              title: const Text('View Inventory'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner, color: Colors.teal),
              title: const Text('Scan Item'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScannerScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.document_scanner_outlined, color: Colors.teal),
              title: const Text('Extract from Image (OCR)'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OcrScreen()),
                );
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
      body: AppBackground(
        child: RefreshIndicator(
          onRefresh: _refreshInventory,
          child: FutureBuilder<List<Medicine>>(
            future: _medicinesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${snapshot.error}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _refreshInventory,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No medicines found.', style: TextStyle(fontSize: 18)),
                      Text('Pull down to refresh, or scan an item.',
                          style: TextStyle(color: Colors.grey)),
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
                    background: Container(
                      color: Colors.redAccent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child:
                          const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    direction: DismissDirection.endToStart,
                    onDismissed: (direction) async {
                      try {
                        await _apiService.deleteMedicine(medicine.id);
                        setState(() {
                          medicines.removeAt(index);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('${medicine.name} deleted'),
                              backgroundColor: Colors.green),
                        );
                      } catch (e) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text('Failed to delete: $e'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: Card(
                      margin:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 4,
                      child: ListTile(
                        leading: const Icon(Icons.medication_outlined,
                            color: Colors.teal),
                        title: Text(medicine.name,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(medicine.manufacturer ?? 'N/A'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Stock: ${medicine.totalQuantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    MedicineDetailScreen(medicine: medicine)),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _toggleRecording,
            tooltip: 'Add via Voice',
            heroTag: 'voice_fab',
            backgroundColor:
                _isRecording ? Colors.redAccent : Theme.of(context).colorScheme.primary,
            child: Icon(_isRecording ? Icons.stop : Icons.mic),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatbotScreen()),
              );
            },
            tooltip: 'Ask PharmPal',
            heroTag: 'chat_fab',
            child: const Icon(Icons.chat_bubble_outline),
          ),
        ],
      ),
    );
  }
}
