// lib/ocr_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/auth_service.dart'; // Add this import
import 'package:pharmaapp/app_background.dart';
import 'package:pharmaapp/create_medicine_screen.dart';
import 'package:intl/intl.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  late final ApiService _apiService; // Change to late final
  File? _selectedImage;
  String? _extractedText;
  bool _isProcessing = false;
  bool _isAIParsing = false;
  Map<String, dynamic>? _parsedData;
  @override
  void initState() {
    super.initState();
    
    // Initialize ApiService with AuthService
    _apiService = ApiService(AuthService());
  }
 
  // --- HELPER FUNCTIONS TO PARSE OCR TEXT ---
  double? _parsePrice(String text) {
    final priceRegex = RegExp(r'(?:MRP|Rs\.?|\$)\s*[:\- ]?\s*(\d+\.?\d*)', caseSensitive: false);
    final match = priceRegex.firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }

  DateTime? _parseDate(String text) {
  final dateRegex = RegExp(r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2}|\d{1,2}\s(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s\d{2,4})', caseSensitive: false);
  final match = dateRegex.firstMatch(text);
  if (match != null) {
    try {
      // Try common date formats
      final dateString = match.group(0)!;
      try {
        return DateFormat('dd/MM/yyyy').parse(dateString);
      } catch (e) {
        try {
          return DateFormat('MM/dd/yyyy').parse(dateString);
        } catch (e) {
          try {
            return DateFormat('yyyy/MM/dd').parse(dateString);
          } catch (e) {
            return null;
          }
        }
      }
    } catch (e) {
      return null;
    }
  }
  return null;
}

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _extractedText = null; // Clear previous results
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _isProcessing = true;
      _extractedText = null;
      _parsedData = null; // Reset parsed data
    });
    try {
      final result = await _apiService.extractTextFromImage(_selectedImage!);
      setState(() {
        _extractedText = result['found_text'];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst("Exception: ", "")), 
          backgroundColor: Colors.red
        ),
      );
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _parseWithAI() async {
    if (_extractedText == null || _extractedText!.isEmpty) return;
    
    setState(() {
      _isAIParsing = true;
    });
    
    try {
      final parsedData = await _apiService.parseMedicineText(_extractedText!);
      setState(() {
        _parsedData = parsedData;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI parsing completed!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('AI parsing failed: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _isAIParsing = false;
      });
    }
  }

  void _navigateToCreateScreen() {
    // Use AI parsed data if available, otherwise use basic regex parsing
    final String? name = _parsedData?['name'];
    final String? manufacturer = _parsedData?['manufacturer'];
    final String? strength = _parsedData?['strength'];
    final double? price = _parsedData?['price']?.toDouble();
    final String? lotNumber = _parsedData?['lot_number'];
    
    // Parse date from AI or use regex fallback
    DateTime? expiryDate;
    if (_parsedData?['expiry_date'] != null) {
      try {
        expiryDate = DateTime.parse(_parsedData!['expiry_date']);
      } catch (e) {
        print('Failed to parse AI date: ${_parsedData!['expiry_date']}');
      }
    }
    if (expiryDate == null) {
      expiryDate = _parseDate(_extractedText!);
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateMedicineScreen(
          ocrPrice: price ?? _parsePrice(_extractedText!),
          ocrExpiryDate: expiryDate,
          // Pre-fill other fields from AI parsing
          prefillName: name,
          prefillManufacturer: manufacturer,
          prefillStrength: strength,
          prefillLotNumber: lotNumber,
        ),
      ),
    ).then((success) {
      if (success == true) {
        setState(() {
          _selectedImage = null;
          _extractedText = null;
          _parsedData = null;
        });
      }
    });
  }

  // --- BUILD METHOD IS RESTRUCTURED FOR BETTER UX ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract from Image (OCR)'),
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Preview Area (unchanged)
                Container(
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedImage == null
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_search, size: 80, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Select an image to begin'),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_selectedImage!, fit: BoxFit.contain),
                        ),
                ),
                
                const SizedBox(height: 24),
                
                // Image Selection Buttons (unchanged)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      onPressed: _isProcessing ? null : () => _pickImage(ImageSource.gallery),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Camera'),
                      onPressed: _isProcessing ? null : () => _pickImage(ImageSource.camera),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),

                // Process Button
                ElevatedButton(
                  onPressed: (_selectedImage == null || _isProcessing) ? null : _processImage,
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                        )
                      : const Text('Extract Text'),
                ),

                // AI Parse Button (new)
                if (_extractedText != null && !_isProcessing)
                  Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: ElevatedButton.icon(
                      onPressed: _isAIParsing ? null : _parseWithAI,
                      icon: _isAIParsing 
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.auto_awesome),
                      label: _isAIParsing 
                          ? const Text('AI Parsing...')
                          : const Text('AI Smart Parse'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                // Results Area
                if (_extractedText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('Extracted Text:', style: Theme.of(context).textTheme.titleMedium),
                                    if (_parsedData != null)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          'AI Parsed',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SelectableText(_extractedText!),
                                
                                // Show AI parsed data preview
                                if (_parsedData != null) ...[
                                  const SizedBox(height: 16),
                                  const Divider(),
                                  Text('AI Extracted Data:', style: Theme.of(context).textTheme.titleSmall),
                                  const SizedBox(height: 8),
                                  ..._parsedData!.entries.where((entry) => entry.value != null).map(
                                    (entry) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                                      child: Row(
                                        children: [
                                          Text('${entry.key}: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Expanded(child: Text(entry.value.toString())),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _navigateToCreateScreen,
                          child: const Text('Continue to Add Item'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}