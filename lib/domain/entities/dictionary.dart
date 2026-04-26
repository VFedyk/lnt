class Dictionary {
  final String? id;
  final String languageId;
  final String name;
  final String url;
  final int sortOrder;
  final bool isActive;
  final String? customCss;

  Dictionary({
    this.id,
    required this.languageId,
    required this.name,
    required this.url,
    this.sortOrder = 0,
    this.isActive = true,
    this.customCss,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_id': languageId,
      'name': name,
      'url': url,
      'sort_order': sortOrder,
      'is_active': isActive ? 1 : 0,
      'custom_css': customCss,
    };
  }

  factory Dictionary.fromMap(Map<String, dynamic> map) {
    return Dictionary(
      id: map['id'] as String?,
      languageId: map['language_id'] as String,
      name: map['name'],
      url: map['url'],
      sortOrder: map['sort_order'] ?? 0,
      isActive: map['is_active'] == 1,
      customCss: map['custom_css'] as String?,
    );
  }

  Dictionary copyWith({
    String? id,
    String? languageId,
    String? name,
    String? url,
    int? sortOrder,
    bool? isActive,
    String? customCss,
  }) {
    return Dictionary(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      name: name ?? this.name,
      url: url ?? this.url,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      customCss: customCss ?? this.customCss,
    );
  }

  // Validate URL format
  bool get isValidUrl => url.isNotEmpty && url.contains('###');
}
