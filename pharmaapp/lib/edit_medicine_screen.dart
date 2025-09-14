// lib/edit_medicine_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';

class EditMedicineScreen extends StatefulWidget {
  final Medicine medicine;
  const EditMedicineScreen({super.key, required this.medicine});

  @override
  State<EditMedicineScreen> createState() => _EditMedicineScreenState();
}

class _EditMedicineScreenState extends State<EditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _nameController;
  late TextEditingController _manufacturerController;
  late TextEditingController _strengthController;
  late TextEditingController _priceController;
  late DateTime _expiryDate;

  @override
  void initState() {
    super.initState();
    // Pre-fill the form with the existing medicine data
    _nameController = TextEditingController(text: widget.medicine.name);
    _manufacturerController = TextEditingController(text: widget.medicine.manufacturer);
    _strengthController = TextEditingController(text: widget.medicine.strength);
    _priceController = TextEditingController(text: widget.medicine.price.toString());
    _expiryDate = widget.medicine.expiryDate;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updatedMedicine = await _apiService.updateMedicine(
          medicineId: widget.medicine.id,
          name: _nameController.text,
          manufacturer: _manufacturerController.text,
          strength: _strengthController.text,
          price: double.parse(_priceController.text),
          expiryDate: _expiryDate,
        );
        Navigator.pop(context, updatedMedicine); // Return the updated object
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
        title: const Text('Edit Medicine Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Barcode: ${widget.medicine.barcode ?? 'N/A'}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Medicine Name'), validator: (value) => value!.isEmpty ? 'Please enter a name' : null),
              TextFormField(controller: _manufacturerController, decoration: const InputDecoration(labelText: 'Manufacturer')),
              TextFormField(controller: _strengthController, decoration: const InputDecoration(labelText: 'Strength (e.g., 500mg)')),
              TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number, validator: (value) => value!.isEmpty ? 'Please enter a price' : null),
              // ... (DatePicker and Button are the same as Create Screen)
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Save Changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}