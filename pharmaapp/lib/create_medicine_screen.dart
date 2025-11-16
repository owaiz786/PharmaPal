// lib/create_medicine_screen.dart - UPDATED FOR RELATIONAL DATA
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/auth_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:intl/intl.dart';

class CreateMedicineScreen extends StatefulWidget {
  final String? barcode;
  final double? ocrPrice;
  final DateTime? ocrExpiryDate;
  final String? prefillName;
  final String? prefillManufacturer;
  final String? prefillStrength;
  final String? prefillLotNumber;

  const CreateMedicineScreen({
    super.key,
    this.barcode,
    this.ocrPrice,
    this.ocrExpiryDate,
    this.prefillName,
    this.prefillManufacturer,
    this.prefillStrength,
    this.prefillLotNumber,
  });

  @override
  State<CreateMedicineScreen> createState() => _CreateMedicineScreenState();
}

class _CreateMedicineScreenState extends State<CreateMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _manufacturerController;
  late TextEditingController _strengthController;
  late TextEditingController _priceController;
  late TextEditingController _lotNumberController;
  late TextEditingController _quantityController;
  late TextEditingController _storageInstructionsController;
  late TextEditingController _sideEffectsController;
  late DateTime _expiryDate;

  // For relational data
  List<String> _selectedCategories = []; // Changed to list for multiple categories
  bool _requiresPrescription = false;

  // Common categories for quick selection
  final List<String> _commonCategories = [
    'Analgesics',
    'Antibiotics', 
    'Antihistamines',
    'Vitamins',
    'Cardiovascular',
    'Diabetes',
    'Gastrointestinal',
    'Dermatological',
    'Respiratory',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    
    _apiService = ApiService(AuthService());
    
    // Initialize controllers
    _nameController = TextEditingController(text: widget.prefillName ?? '');
    _manufacturerController = TextEditingController(text: widget.prefillManufacturer ?? '');
    _strengthController = TextEditingController(text: widget.prefillStrength ?? '');
    _priceController = TextEditingController(text: widget.ocrPrice?.toString() ?? '');
    _lotNumberController = TextEditingController(text: widget.prefillLotNumber ?? '');
    _quantityController = TextEditingController();
    _storageInstructionsController = TextEditingController();
    _sideEffectsController = TextEditingController();
    _expiryDate = widget.ocrExpiryDate ?? DateTime.now();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _apiService.smartCreateMedicine(
          barcode: widget.barcode,
          name: _nameController.text,
          manufacturerName: _manufacturerController.text.isEmpty ? null : _manufacturerController.text, // Changed parameter name
          strength: _strengthController.text.isEmpty ? null : _strengthController.text,
          price: double.parse(_priceController.text),
          lotNumber: _lotNumberController.text,
          quantity: int.parse(_quantityController.text),
          expiryDate: _expiryDate,
          categoryNames: _selectedCategories, // Now passing list of categories
          requiresPrescription: _requiresPrescription,
          storageInstructions: _storageInstructionsController.text.isEmpty ? null : _storageInstructionsController.text,
          sideEffects: _sideEffectsController.text.isEmpty ? null : _sideEffectsController.text,
        );
        Navigator.pop(context, true); 
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showCategorySelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _commonCategories.length,
                      itemBuilder: (context, index) {
                        final category = _commonCategories[index];
                        final isSelected = _selectedCategories.contains(category);
                        
                        return CheckboxListTile(
                          title: Text(category),
                          value: isSelected,
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedCategories.clear();
                          });
                        },
                        child: const Text('Clear All'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {}); // Update the main screen
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (widget.barcode != null)
                Text('Barcode: ${widget.barcode}', style: Theme.of(context).textTheme.titleMedium),
              
              const SizedBox(height: 16),
              
              // --- Product Details ---
              const Text("Product Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),

              // Category Selection - Updated for multiple selection
              InkWell(
                onTap: _showCategorySelection,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Categories',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                  child: _selectedCategories.isEmpty
                      ? const Text('Select categories...', style: TextStyle(color: Colors.grey))
                      : Text(
                          _selectedCategories.join(', '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
              if (_selectedCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Selected: ${_selectedCategories.length} category(ies)',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],

              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController, 
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  border: OutlineInputBorder(),
                ), 
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _manufacturerController, 
                decoration: const InputDecoration(
                  labelText: 'Manufacturer',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _strengthController, 
                decoration: const InputDecoration(
                  labelText: 'Strength (e.g., 500mg)',
                  border: OutlineInputBorder(),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _priceController, 
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ), 
                keyboardType: TextInputType.number, 
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),

              const SizedBox(height: 16),

              // Additional fields
              TextFormField(
                controller: _storageInstructionsController,
                decoration: const InputDecoration(
                  labelText: 'Storage Instructions (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _sideEffectsController,
                decoration: const InputDecoration(
                  labelText: 'Side Effects (Optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: const Text('Requires Prescription'),
                value: _requiresPrescription,
                onChanged: (bool value) {
                  setState(() {
                    _requiresPrescription = value;
                  });
                },
              ),
              
              const SizedBox(height: 24),

              // --- Batch Details ---
              const Text("Batch Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _lotNumberController, 
                decoration: const InputDecoration(
                  labelText: 'Lot Number',
                  border: OutlineInputBorder(),
                ), 
                validator: (value) => value!.isEmpty ? 'Please enter a Lot Number' : null,
              ),
              
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _quantityController, 
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                ), 
                keyboardType: TextInputType.number, 
                validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Expiry Date Picker
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context, 
                    initialDate: _expiryDate, 
                    firstDate: DateTime.now(), 
                    lastDate: DateTime(2100)
                  );
                  if (pickedDate != null) {
                    setState(() { _expiryDate = pickedDate; });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat.yMMMd().format(_expiryDate)),
                      const Icon(Icons.calendar_today, size: 20),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Save to Inventory', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}