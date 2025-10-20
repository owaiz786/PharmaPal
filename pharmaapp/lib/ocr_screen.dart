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
                // 1. Image Preview Area
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
                
                // 2. Image Selection Buttons (Always Visible)
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

                // 3. Process Button (Enabled only when an image is selected)
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

                // 4. Results Area (Visible only after processing)
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
                                Text('Extracted Text:', style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 8),
                                SelectableText(_extractedText!),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            final price = _parsePrice(_extractedText!);
                            final expiry = _parseDate(_extractedText!);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateMedicineScreen(
                                  ocrPrice: price,
                                  ocrExpiryDate: expiry,
                                ),
                              ),
                            ).then((success) {
                              if (success == true) {
                                setState(() {
                                  _selectedImage = null;
                                  _extractedText = null;
                                });
                              }
                            });
                          },
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