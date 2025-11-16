// lib/medicine.dart
import 'dart:convert';

// Helper to parse a list of medicines
List<Medicine> medicineListFromJson(String str) =>
    List<Medicine>.from(json.decode(str).map((x) => Medicine.fromJson(x)));

class Medicine {
  final int id;
  final String? barcode;
  final String name;
  final String? strength;
  final double price;
  final DateTime expiryDate;
  final List<InventoryItem> inventoryItems;
  
  // New relational fields
  final int? manufacturerId;
  final Manufacturer? manufacturerDetails;
  final List<Category> categories;
  
  // Keep backward compatibility
  final String? category; // Single category for display
  final bool requiresPrescription;
  final String? storageInstructions;
  final String? sideEffects;

  Medicine({
    required this.id,
    this.barcode,
    required this.name,
    this.strength,
    required this.price,
    required this.expiryDate,
    required this.inventoryItems,
    this.manufacturerId,
    this.manufacturerDetails,
    this.categories = const [],
    this.category,
    this.requiresPrescription = false,
    this.storageInstructions,
    this.sideEffects,
  });

  // A computed property to get total stock quantity
  int get totalQuantity {
    if (inventoryItems.isEmpty) return 0;
    return inventoryItems.map((item) => item.quantity).reduce((a, b) => a + b);
  }

  // Get manufacturer name (from details or fallback)
  String? get manufacturerName {
    return manufacturerDetails?.name;
  }

  // Get category names as string
  String get categoryNames {
    if (categories.isNotEmpty) {
      return categories.map((c) => c.name).join(', ');
    }
    return category ?? 'Uncategorized';
  }

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json["id"],
        barcode: json["barcode"],
        name: json["name"],
        strength: json["strength"],
        price: json["price"] is int ? (json["price"] as int).toDouble() : json["price"],
        expiryDate: DateTime.parse(json["expiry_date"]),
        inventoryItems: List<InventoryItem>.from(
            json["inventory_items"].map((x) => InventoryItem.fromJson(x))),
        manufacturerId: json["manufacturer_id"],
        manufacturerDetails: json["manufacturer_details"] != null 
            ? Manufacturer.fromJson(json["manufacturer_details"])
            : null,
        categories: json["categories"] != null
            ? List<Category>.from(json["categories"].map((x) => Category.fromJson(x)))
            : [],
        category: json["category"],
        requiresPrescription: json["requires_prescription"] ?? false,
        storageInstructions: json["storage_instructions"],
        sideEffects: json["side_effects"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "barcode": barcode,
        "name": name,
        "strength": strength,
        "price": price,
        "expiry_date": expiryDate.toIso8601String(),
        "inventory_items": List<dynamic>.from(inventoryItems.map((x) => x.toJson())),
        "manufacturer_id": manufacturerId,
        "manufacturer_details": manufacturerDetails?.toJson(),
        "categories": List<dynamic>.from(categories.map((x) => x.toJson())),
        "category": category,
        "requires_prescription": requiresPrescription,
        "storage_instructions": storageInstructions,
        "side_effects": sideEffects,
      };
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

  Map<String, dynamic> toJson() => {
        "id": id,
        "lot_number": lotNumber,
        "quantity": quantity,
        "expiry_date": expiryDate.toIso8601String(),
      };
}

// New models for relational data
class Manufacturer {
  final int id;
  final String name;
  final String? contactEmail;
  final String? phone;
  final String? address;
  final String? country;
  final String? website;
  final bool isVerified;

  Manufacturer({
    required this.id,
    required this.name,
    this.contactEmail,
    this.phone,
    this.address,
    this.country,
    this.website,
    this.isVerified = false,
  });

  factory Manufacturer.fromJson(Map<String, dynamic> json) => Manufacturer(
        id: json["id"],
        name: json["name"],
        contactEmail: json["contact_email"],
        phone: json["phone"],
        address: json["address"],
        country: json["country"],
        website: json["website"],
        isVerified: json["is_verified"] ?? false,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "contact_email": contactEmail,
        "phone": phone,
        "address": address,
        "country": country,
        "website": website,
        "is_verified": isVerified,
      };
}

class Category {
  final int id;
  final String name;
  final String? description;

  Category({
    required this.id,
    required this.name,
    this.description,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json["id"],
        name: json["name"],
        description: json["description"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "description": description,
      };
}