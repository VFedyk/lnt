class Collection {
  final int? id;
  final int languageId;
  final String name;
  final String description;
  final int? parentId; // For nested folders
  final DateTime createdAt;
  final int sortOrder;

  Collection({
    this.id,
    required this.languageId,
    required this.name,
    this.description = '',
    this.parentId,
    DateTime? createdAt,
    this.sortOrder = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_id': languageId,
      'name': name,
      'description': description,
      'parent_id': parentId,
      'created_at': createdAt.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'],
      languageId: map['language_id'],
      name: map['name'],
      description: map['description'] ?? '',
      parentId: map['parent_id'],
      createdAt: DateTime.parse(map['created_at']),
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Collection copyWith({
    int? id,
    int? languageId,
    String? name,
    String? description,
    int? parentId,
    DateTime? createdAt,
    int? sortOrder,
  }) {
    return Collection(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get isRootLevel => parentId == null;
}
