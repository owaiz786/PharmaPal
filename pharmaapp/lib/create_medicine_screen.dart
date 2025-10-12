// lib/create_medicine_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';
import 'package:intl/intl.dart';

class CreateMedicineScreen extends StatefulWidget {
  // We can now pre-fill the form with data from different sources
  final String? barcode;
  final double? ocrPrice;
  final DateTime? ocrExpiryDate;

  const CreateMedicineScreen({
    super.key,
    this.barcode,
    this.ocrPrice,
    this.ocrExpiryDate,
  });

  @override
  State<CreateMedicineScreen> createState() => _CreateMedicineScreenState();
}

class _CreateMedicineScreenState extends State<CreateMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Add controllers for the new inventory fields
  late TextEditingController _nameController;
  late TextEditingController _manufacturerController;
  late TextEditingController _strengthController;
  late TextEditingController _priceController;
  late TextEditingController _lotNumberController;
  late TextEditingController _quantityController;
  late DateTime _expiryDate;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with any data passed to the screen
    _nameController = TextEditingController();
    _manufacturerController = TextEditingController();
    _strengthController = TextEditingController();
    _priceController = TextEditingController(text: widget.ocrPrice?.toString() ?? '');
    _lotNumberController = TextEditingController();
    _quantityController = TextEditingController();
    _expiryDate = widget.ocrExpiryDate ?? DateTime.now();
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        await _apiService.smartCreateMedicine(
          barcode: widget.barcode,
          name: _nameController.text,
          manufacturer: _manufacturerController.text,
          strength: _strengthController.text,
          price: double.parse(_priceController.text),
          lotNumber: _lotNumberController.text,
          quantity: int.parse(_quantityController.text),
          expiryDate: _expiryDate,
        );
        // If successful, pop back with a success flag
        Navigator.pop(context, true); 
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
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
              
              // --- Medicine Fields ---
              const Text("Product Details", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Medicine Name'), validator: (value) => value!.isEmpty ? 'Please enter a name' : null),
              TextFormField(controller: _manufacturerController, decoration: const InputDecoration(labelText: 'Manufacturer')),
              TextFormField(controller: _strengthController, decoration: const InputDecoration(labelText: 'Strength (e.g., 500mg)')),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter a price' : null),
              
              const SizedBox(height: 24),

              // --- Inventory Fields ---
              const Text("Batch Details", style: TextStyle(fontWeight: FontWeight.bold)),
              TextFormField(controller: _lotNumberController, decoration: const InputDecoration(labelText: 'Lot Number'), validator: (value) => value!.isEmpty ? 'Please enter a Lot Number' : null),
              TextFormField(controller: _quantityController, decoration: const InputDecoration(labelText: 'Quantity'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter a quantity' : null),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(context: context, initialDate: _expiryDate, firstDate: DateTime.now(), lastDate: DateTime(2100));
                  if (pickedDate != null) {
                    setState(() { _expiryDate = pickedDate; });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                  child: Text(DateFormat.yMMMd().format(_expiryDate)),
                ),
              ),
              
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Save to Inventory'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}