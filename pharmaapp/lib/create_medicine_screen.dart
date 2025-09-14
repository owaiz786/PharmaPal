// lib/create_medicine_screen.dart
import 'package:flutter/material.dart';
import 'package:pharmaapp/api_service.dart';
import 'package:pharmaapp/medicine.dart';

class CreateMedicineScreen extends StatefulWidget {
  final String barcode;
  const CreateMedicineScreen({super.key, required this.barcode});

  @override
  State<CreateMedicineScreen> createState() => _CreateMedicineScreenState();
}

class _CreateMedicineScreenState extends State<CreateMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Controllers for form fields
  final _nameController = TextEditingController();
  final _manufacturerController = TextEditingController();
  final _strengthController = TextEditingController();
  final _priceController = TextEditingController();
  DateTime _expiryDate = DateTime.now();

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newMedicine = await _apiService.createMedicine(
          barcode: widget.barcode,
          name: _nameController.text,
          manufacturer: _manufacturerController.text,
          strength: _strengthController.text,
          price: double.parse(_priceController.text),
          expiryDate: _expiryDate,
        );
        // If successful, pop the screen and return the new medicine object
        Navigator.pop(context, newMedicine);
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
        title: const Text('Create New Medicine'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Text('Barcode: ${widget.barcode}', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Medicine/Product Name'),
                validator: (value) => value!.isEmpty ? 'Please enter a name' : null,
              ),
              TextFormField(
                controller: _manufacturerController,
                decoration: const InputDecoration(labelText: 'Manufacturer'),
              ),
              TextFormField(
                controller: _strengthController,
                decoration: const InputDecoration(labelText: 'Strength (e.g., 500mg)'),
              ),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) => value!.isEmpty ? 'Please enter a price' : null,
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _expiryDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    setState(() { _expiryDate = pickedDate; });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Default Expiry Date'),
                  child: Text("${_expiryDate.toLocal()}".split(' ')[0]),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Save and Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}