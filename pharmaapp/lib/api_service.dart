// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:pharmaapp/medicine.dart';
import 'auth_service.dart';

class ApiService {
  static const String _baseUrl = "http://10.113.175.122:8000"; 
  
  final AuthService _authService;

  ApiService(this._authService);

  // --- PRIVATE HELPERS TO GET AUTHENTICATION HEADERS ---
  Map<String, String> get _jsonHeaders {
    final token = _authService.token;
    if (token == null) {
      throw Exception('User is not authenticated.');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Map<String, String> get _authHeaderOnly {
    final token = _authService.token;
    if (token == null) {
      throw Exception('User is not authenticated.');
    }
    return {
      'Authorization': 'Bearer $token',
    };
  }
  // --------------------------------------------------

  // --- ALL FUNCTIONS NOW AUTHENTICATED ---

  Future<List<Medicine>> fetchAllMedicines() async {
    final url = Uri.parse('$_baseUrl/medicines/');
    print('🔍 Fetching medicines from: $url'); // Debug log
    
    final response = await http.get(url, headers: _authHeaderOnly);
    
    print('📡 Response status: ${response.statusCode}'); // Debug log
    print('📦 Response body: ${response.body}'); // Debug log
    
    if (response.statusCode == 200) {
      return medicineListFromJson(response.body);
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    } else if (response.statusCode == 404) {
      throw Exception('Medicines endpoint not found. Please check server configuration.');
    } else {
      throw Exception('Failed to load medicine list. Status: ${response.statusCode}');
    }
  }

  // ... REST OF YOUR METHODS REMAIN THE SAME ...
  Future<Medicine> fetchMedicineById(int medicineId) async {
    final url = Uri.parse('$_baseUrl/medicines/$medicineId');
    final response = await http.get(url, headers: _authHeaderOnly);
    if (response.statusCode == 200) {
      return  Medicine.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load updated medicine data.');
    }
  }

  Future<Medicine> fetchMedicineByBarcode(String barcode) async {
    final url = Uri.parse('$_baseUrl/medicines/barcode/$barcode');
    final response = await http.get(url, headers: _authHeaderOnly);
    if (response.statusCode == 200) {
      return Medicine.fromJson(json.decode(response.body));
    } else if (response.statusCode == 404) {
      throw Exception('Medicine with this barcode not found.');
    } else {
      throw Exception('Failed to load medicine. Status code: ${response.statusCode}');
    }
  }

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
      'barcode': barcode, 'name': name, 'manufacturer': manufacturer,
      'strength': strength, 'price': price,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 201) {
       return Medicine.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create medicine. Server returned: ${response.body}');
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
      'barcode': barcode, 'name': name, 'manufacturer': manufacturer,
      'strength': strength, 'price': price, 'lot_number': lotNumber,
      'quantity': quantity,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 200) {
     return Medicine.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create medicine. Server returned: ${response.body}');
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
      'name': name, 'manufacturer': manufacturer, 'strength': strength,
      'price': price,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });
    final response = await http.put(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 200) {
      return Medicine.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to update medicine.');
    }
  }

  Future<void> deleteMedicine(int medicineId) async {
    final url = Uri.parse('$_baseUrl/medicines/$medicineId');
    final response = await http.delete(url, headers: _authHeaderOnly);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete medicine.');
    }
  }

  Future<void> addInventoryItem({
    required int medicineId,
    required String lotNumber,
    required int quantity,
    required DateTime expiryDate,
  }) async {
    final url = Uri.parse('$_baseUrl/inventory/receive');
    final body = json.encode({
      'medicine_id': medicineId, 'lot_number': lotNumber,
      'quantity': quantity,
      'expiry_date': "${expiryDate.year.toString().padLeft(4, '0')}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}",
    });
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode != 201) {
      throw Exception('Failed to add inventory item. Status code: ${response.statusCode}');
    }
  }

  Future<void> addInventoryFromGS1(String gs1Data, int quantity) async {
    final url = Uri.parse('$_baseUrl/inventory/receive-gs1');
    final body = json.encode({'gs1_data': gs1Data, 'quantity': quantity});
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 404 || response.statusCode == 400) {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['detail'] ?? 'Invalid GS1 data or medicine not found.');
    }
    if (response.statusCode != 201) {
      throw Exception('Failed to add inventory. Status code: ${response.statusCode}');
    }
  }

  Future<void> dispenseItem({required int itemId, required int quantity}) async {
    final url = Uri.parse('$_baseUrl/inventory/dispense');
    final body = json.encode({'item_id': itemId, 'quantity': quantity});
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 400) {
      throw Exception('Insufficient stock for this batch.');
    }
    if (response.statusCode != 200) {
      throw Exception('Failed to dispense item. Status code: ${response.statusCode}');
    }
  }

  Future<void> restockItem({required int itemId, required int quantity}) async {
    final url = Uri.parse('$_baseUrl/inventory/restock');
    final body = json.encode({'item_id': itemId, 'quantity': quantity});
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode != 200) {
      throw Exception('Failed to restock item.');
    }
  }

  Future<void> updateDetailsFromImage(int itemId, File imageFile) async {
    final url = Uri.parse('$_baseUrl/inventory/$itemId/update-details-from-image');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(_authHeaderOnly);
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      final errorBody = json.decode(response.body);
      throw Exception('Failed to update: ${errorBody['detail']}');
    }
  }

  Future<Map<String, dynamic>> extractTextFromImage(File imageFile) async {
    final url = Uri.parse('$_baseUrl/ocr/extract-text');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(_authHeaderOnly);
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      final errorBody = json.decode(response.body);
      throw Exception('OCR failed: ${errorBody['detail']}');
    }
  }

  Future<void> processVoiceAudio(File audioFile) async {
    final url = Uri.parse('$_baseUrl/voice/process-audio');
    var request = http.MultipartRequest('POST', url);
    request.headers.addAll(_authHeaderOnly);
    request.files.add(await http.MultipartFile.fromPath('file', audioFile.path));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      final errorBody = json.decode(response.body);
      throw Exception(errorBody['detail']);
    }
  }

  Future<String> askChatbot(String message) async {
    final url = Uri.parse('$_baseUrl/chatbot/query');
    final body = json.encode({'message': message});
    final response = await http.post(url, headers: _jsonHeaders, body: body);
    if (response.statusCode == 200) {
      final responseBody = json.decode(response.body);
      return responseBody['response'];
    } else {
      throw Exception('Chatbot failed to respond.');
    }
  }
}