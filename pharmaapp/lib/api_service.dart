// lib/api_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pharmaapp/medicine.dart'; // Make sure this matches your project name
import 'dart:io';
class ApiService {
  // --- IMPORTANT: REPLACE WITH YOUR COMPUTER'S IP ADDRESS ---
  static const String _baseUrl = "http://10.113.175.122:8000";
  // ---------------------------------------------------------

  Future<void> addInventoryItem({
    required int medicineId,
    required String lotNumber,
    required int quantity,
    required DateTime expiryDate,
  }) async {
    final url = Uri.parse('$_baseUrl/inventory/receive');
    final body = json.encode({
      'medicine_id': medicineId,
      'lot_number': lotNumber,
      'quantity': quantity,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode != 201) {
        throw Exception('Failed to add inventory item. Status code: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server.');
    }
  }

Future<Medicine> smartCreateMedicine({
    String? barcode,
    required String name,
    String? manufacturer,
    String? strength,
    required double price,
    required String lotNumber,
    required int quantity,
    required DateTime expiryDate,
}) async {
    final url = Uri.parse('$_baseUrl/medicines/smart-create');
    final body = json.encode({
        'barcode': barcode,
        'name': name,
        'manufacturer': manufacturer,
        'strength': strength,
        'price': price,
        'lot_number': lotNumber,
        'quantity': quantity,
        'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });

    try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );
        if (response.statusCode == 200) { // Our new endpoint returns 200
            return  Medicine.fromJson(json.decode(response.body));
        } else {
            throw Exception('Failed to create medicine. Server returned: ${response.body}');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}

// lib/api_service.dart

Future<String> askChatbot(String message) async {
    final url = Uri.parse('$_baseUrl/chatbot/query');
    final body = json.encode({'message': message});
    try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );
        if (response.statusCode == 200) {
            final responseBody = json.decode(response.body);
            return responseBody['response'];
        } else {
            throw Exception('Chatbot failed to respond.');
        }
    } catch (e) {
        throw Exception('Failed to connect to the chatbot server.');
    }
}

Future<Map<String, dynamic>> extractTextFromImage(File imageFile) async {
  final url = Uri.parse('$_baseUrl/ocr/extract-text');
  
  var request = http.MultipartRequest('POST', url);
  request.files.add(
    await http.MultipartFile.fromPath('file', imageFile.path),
  );

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      // Return the JSON body which contains the 'found_text'
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception('OCR failed: ${errorBody['detail']}');
    }
  } catch (e) {
    throw Exception('Failed to connect to the server for OCR processing.');
  }
}

Future<void> updateDetailsFromImage(int itemId, File imageFile) async {
    final url = Uri.parse('$_baseUrl/inventory/$itemId/update-details-from-image');
    var request = http.MultipartRequest('POST', url);
    request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
    );
    try {
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode != 200) {
            final errorBody = json.decode(response.body);
            throw Exception('Failed to update: ${errorBody['detail']}');
        }
    } catch (e) {
        throw Exception('Failed to upload file or connect to server.');
    }
}

  // lib/api_service.dart

// Add this new function inside the ApiService class
  Future<Medicine> createMedicine({
    required String barcode,
    required String name,
    String? manufacturer,
    String? strength,
    required double price,
    required DateTime expiryDate,
  }) async {
    final url = Uri.parse('$_baseUrl/medicines/');
    final body = json.encode({
      'barcode': barcode,
      'name': name,
      'manufacturer': manufacturer,
      'strength': strength,
      'price': price,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (response.statusCode == 201) {
        return Medicine.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create medicine. Server returned: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server.');
    }
  }

  Future<List<Medicine>> fetchAllMedicines() async {
    final url = Uri.parse('$_baseUrl/medicines/');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return medicineListFromJson(response.body);
      } else {
        throw Exception('Failed to load medicine list.');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server.');
    }
  }

   Future<Medicine> fetchMedicineByBarcode(String barcode) async {
    final url = Uri.parse('$_baseUrl/medicines/barcode/$barcode');
    
    // We remove the outer try-catch block to let specific errors pass through
    final response = await http.get(url).catchError((e) {
      // This catchError only triggers for true network failures (no connection)
      throw Exception('Failed to connect to the server. Please check your connection and IP address.');
    });

    if (response.statusCode == 200) {
      return Medicine.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      // Now, this specific exception will be passed to the UI
      throw Exception('Medicine with this barcode not found.');
    } else {
      // For any other server error
      throw Exception('Failed to load medicine. Status code: ${response.statusCode}');
    }
  }
  // lib/api_service.dart

// ... (inside ApiService class)
Future<void> addInventoryFromGS1(String gs1Data, int quantity) async {
    final url = Uri.parse('$_baseUrl/inventory/receive-gs1');
    final body = json.encode({
        'gs1_data': gs1Data,
        'quantity': quantity,
    });

    try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );

        if (response.statusCode == 404 || response.statusCode == 400) {
             final errorBody = json.decode(response.body);
             throw Exception(errorBody['detail'] ?? 'Invalid GS1 data or medicine not found.');
        }
        if (response.statusCode != 201) {
            throw Exception('Failed to add inventory. Status code: ${response.statusCode}');
        }
    } catch (e) {
        throw Exception(e.toString());
    }
}

Future<void> restockItem({required int itemId, required int quantity}) async {
    final url = Uri.parse('$_baseUrl/inventory/restock');
    final body = json.encode({'item_id': itemId, 'quantity': quantity});

    try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );
        if (response.statusCode != 200) {
            throw Exception('Failed to restock item.');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}

Future<Medicine> fetchMedicineById(int medicineId) async {
    final url = Uri.parse('$_baseUrl/medicines/$medicineId');
    try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
            return Medicine.fromJson(json.decode(response.body));
        } else {
            throw Exception('Failed to load updated medicine data.');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}

Future<void> deleteMedicine(int medicineId) async {
    final url = Uri.parse('$_baseUrl/medicines/$medicineId');
    try {
        final response = await http.delete(url);

        if (response.statusCode != 200) {
            throw Exception('Failed to delete medicine.');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}

Future<Medicine> updateMedicine({
    required int medicineId,
    required String name,
    String? manufacturer,
    String? strength,
    required double price,
    required DateTime expiryDate,
}) async {
    final url = Uri.parse('$_baseUrl/medicines/$medicineId');
    final body = json.encode({
        'name': name,
        'manufacturer': manufacturer,
        'strength': strength,
        'price': price,
        'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });

    try {
        final response = await http.put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );
        if (response.statusCode == 200) {
           return Medicine.fromJson(json.decode(response.body));
        } else {
            throw Exception('Failed to update medicine.');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}

  Future<void> dispenseItem({required int itemId, required int quantity}) async {
    final url = Uri.parse('$_baseUrl/inventory/dispense');
    final body = json.encode({'item_id': itemId, 'quantity': quantity});

    try {
        final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
        );

        if (response.statusCode == 400) { // Bad Request
            throw Exception('Insufficient stock for this batch.');
        }
        if (response.statusCode != 200) {
            throw Exception('Failed to dispense item. Status code: ${response.statusCode}');
        }
    } catch (e) {
        throw Exception('Failed to connect to the server.');
    }
}
}