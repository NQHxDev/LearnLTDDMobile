class Device {
  final int id;
  final String name;
  final String? description;
  final String category;
  final double price;
  final String? brand;
  final String? modelNumber;
  final String? imageUrl;
  final int stockQuantity;
  final int minAge;
  final int maxAge;
  final bool isAvailable;
  final double averageRating;
  final int reviewCount;
  final DateTime? createdAt;

  const Device({
    required this.id,
    required this.name,
    this.description,
    required this.category,
    required this.price,
    this.brand,
    this.modelNumber,
    this.imageUrl,
    required this.stockQuantity,
    required this.minAge,
    required this.maxAge,
    required this.isAvailable,
    required this.averageRating,
    required this.reviewCount,
    this.createdAt,
  });

  static const List<String> defaultCategories = [
    'SmartWatch',
    'Tablet',
    'EducationalToy',
    'ElectronicDevice',
    'SafetyDevice',
    'Monitor',
    'Other',
  ];

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'],
      category: json['category'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      brand: json['brand'],
      modelNumber: json['modelNumber'],
      imageUrl: json['imageUrl'],
      stockQuantity: json['stockQuantity'] ?? 0,
      minAge: json['minAge'] ?? 0,
      maxAge: json['maxAge'] ?? 0,
      isAvailable: json['isAvailable'] ?? false,
      averageRating: (json['averageRating'] ?? 0).toDouble(),
      reviewCount: json['reviewCount'] ?? 0,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'price': price,
      'brand': brand,
      'modelNumber': modelNumber,
      'imageUrl': imageUrl,
      'stockQuantity': stockQuantity,
      'minAge': minAge,
      'maxAge': maxAge,
      'isAvailable': isAvailable,
      'averageRating': averageRating,
      'reviewCount': reviewCount,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  bool get inStock => stockQuantity > 0;
}
