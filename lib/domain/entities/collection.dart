class Collection {
  final String? id;
  final String languageId;
  final String name;
  final String description;
  final String? parentId; // For nested folders
  final DateTime createdAt;
  final int sortOrder;
  /// FK into the cover_images table. null when no cover is set.
  final String? coverImageId;
  /// Relative local path, populated via JOIN when reading. Not stored in collections table.
  final String? coverImage;
  /// Whether this collection is tracked as a "book" (continuous text) so reading
  /// progress can be aggregated across its chapters. See [BookProgress].
  final bool isContinuous;

  Collection({
    this.id,
    required this.languageId,
    required this.name,
    this.description = '',
    this.parentId,
    DateTime? createdAt,
    this.sortOrder = 0,
    this.coverImageId,
    this.coverImage,
    this.isContinuous = false,
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
      'cover_image_id': coverImageId,
      'is_continuous': isContinuous ? 1 : 0,
    };
  }

  factory Collection.fromMap(Map<String, dynamic> map) {
    return Collection(
      id: map['id'] as String?,
      languageId: map['language_id'] as String,
      name: map['name'] as String,
      description: map['description'] ?? '',
      parentId: map['parent_id'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      sortOrder: map['sort_order'] ?? 0,
      coverImageId: map['cover_image_id'] as String?,
      coverImage: map['cover_image'] as String?, // from LEFT JOIN alias
      isContinuous: (map['is_continuous'] as int? ?? 0) == 1,
    );
  }

  Collection copyWith({
    String? id,
    String? languageId,
    String? name,
    String? description,
    String? parentId,
    DateTime? createdAt,
    int? sortOrder,
    String? coverImageId,
    bool clearCoverImageId = false,
    String? coverImage,
    bool clearCoverImage = false,
    bool? isContinuous,
  }) {
    return Collection(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      sortOrder: sortOrder ?? this.sortOrder,
      coverImageId: clearCoverImageId ? null : (coverImageId ?? this.coverImageId),
      coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
      isContinuous: isContinuous ?? this.isContinuous,
    );
  }

  bool get isRootLevel => parentId == null;
}
