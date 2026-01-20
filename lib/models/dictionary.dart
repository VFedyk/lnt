// FILE: lib/models/dictionary.dart
class Dictionary {
  final int? id;
  final int languageId;
  final String name;
  final String url;
  final int sortOrder;
  final bool isActive;

  Dictionary({
    this.id,
    required this.languageId,
    required this.name,
    required this.url,
    this.sortOrder = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_id': languageId,
      'name': name,
      'url': url,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Dictionary.fromMap(Map<String, dynamic> map) {
    return Dictionary(
      id: map['id'],
      languageId: map['language_id'],
      name: map['name'],
      url: map['url'],
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] == 1,
    );
  }

  Dictionary copyWith({
    int? id,
    int? languageId,
    String? name,
    String? url,
    int? sortOrder,
    bool? isActive,
  }) {
    return Dictionary(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      name: name ?? this.name,
      url: url ?? this.url,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  // Validate URL format
  bool get isValidUrl => url.isNotEmpty && url.contains('###');
}
