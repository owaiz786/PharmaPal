// lib/medicine.dart
import 'dart:convert';

// Helper to parse a list of medicines
List<Medicine> medicineListFromJson(String str) =>
    List<Medicine>.from(json.decode(str).map((x) => Medicine.fromJson(x)));

class Medicine {
  final int id;
  final String? barcode;
  final String name;
  final String? manufacturer;
  final String? strength;
  final double price;
  final DateTime expiryDate;
  final List<InventoryItem> inventoryItems;

  Medicine({
    required this.id,
    this.barcode,
    required this.name,
    this.manufacturer,
    this.strength,
    required this.price,
    required this.expiryDate,
    required this.inventoryItems,
  });

  // A computed property to get total stock quantity
  int get totalQuantity {
    if (inventoryItems.isEmpty) return 0;
    return inventoryItems.map((item) => item.quantity).reduce((a, b) => a + b);
  }

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json["id"],
        barcode: json["barcode"],
        name: json["name"],
        manufacturer: json["manufacturer"],
        strength: json["strength"],
        price: json["price"],
        expiryDate: DateTime.parse(json["expiry_date"]),
        inventoryItems: List<InventoryItem>.from(
            json["inventory_items"].map((x) => InventoryItem.fromJson(x))),
      );
}

class InventoryItem {
  final int id;
  final String lotNumber;
  final int quantity;
  final DateTime expiryDate;

  InventoryItem({
    required this.id,
    required this.lotNumber,
    required this.quantity,
    required this.expiryDate,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json["id"],
        lotNumber: json["lot_number"],
        quantity: json["quantity"],
        expiryDate: DateTime.parse(json["expiry_date"]),
      );
}