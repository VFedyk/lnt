enum TextStatus {
  pending(0),
  inProgress(1),
  finished(2);

  final int value;
  const TextStatus(this.value);

  static TextStatus fromValue(int value) {
    return TextStatus.values.firstWhere(
      (s) => s.value == value,
      orElse: () => TextStatus.pending,
    );
  }
}

class TextDocument {
  final int? id;
  final int languageId;
  final int? collectionId; // Optional folder/collection
  final String title;
  final String content;
  final String sourceUri;
  final DateTime createdAt;
  final DateTime lastRead;
  final int position;
  final int sortOrder; // For ordering chapters within a collection
  final String? coverImage; // Path to cover image file
  final TextStatus status;

  TextDocument({
    this.id,
    required this.languageId,
    this.collectionId,
    required this.title,
    required this.content,
    this.sourceUri = '',
    DateTime? createdAt,
    DateTime? lastRead,
    this.position = 0,
    this.sortOrder = 0,
    this.coverImage,
    this.status = TextStatus.pending,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastRead = lastRead ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'language_id': languageId,
      'collection_id': collectionId,
      'title': title,
      'content': content,
      'source_uri': sourceUri,
      'created_at': createdAt.toIso8601String(),
      'last_read': lastRead.toIso8601String(),
      'position': position,
      'sort_order': sortOrder,
      'cover_image': coverImage,
      'status': status.value,
    };
  }

  factory TextDocument.fromMap(Map<String, dynamic> map) {
    return TextDocument(
      id: map['id'],
      languageId: map['language_id'],
      collectionId: map['collection_id'],
      title: map['title'],
      content: map['content'],
      sourceUri: map['source_uri'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      lastRead: DateTime.parse(map['last_read']),
      position: map['position'] ?? 0,
      sortOrder: map['sort_order'] ?? 0,
      coverImage: map['cover_image'],
      status: TextStatus.fromValue(map['status'] ?? 0),
    );
  }

  TextDocument copyWith({
    int? id,
    int? languageId,
    int? collectionId,
    String? title,
    String? content,
    String? sourceUri,
    DateTime? createdAt,
    DateTime? lastRead,
    int? position,
    int? sortOrder,
    String? coverImage,
    bool clearCoverImage = false,
    TextStatus? status,
  }) {
    return TextDocument(
      id: id ?? this.id,
      languageId: languageId ?? this.languageId,
      collectionId: collectionId ?? this.collectionId,
      title: title ?? this.title,
      content: content ?? this.content,
      sourceUri: sourceUri ?? this.sourceUri,
      createdAt: createdAt ?? this.createdAt,
      lastRead: lastRead ?? this.lastRead,
      position: position ?? this.position,
      sortOrder: sortOrder ?? this.sortOrder,
      coverImage: clearCoverImage ? null : (coverImage ?? this.coverImage),
      status: status ?? this.status,
    );
  }

  // Word count for word-based languages
  int get wordCount => content.split(RegExp(r'\s+')).length;

  // Character count for character-based languages (excludes whitespace and punctuation)
  int get characterCount {
    int count = 0;
    final punctuationPattern = RegExp(r'[\p{P}\p{S}\s]', unicode: true);

    for (int i = 0; i < content.length; i++) {
      final char = content[i];
      if (!punctuationPattern.hasMatch(char)) {
        count++;
      }
    }

    return count;
  }

  // Get appropriate count label based on language type
  String getCountLabel(bool splitByCharacter) {
    if (splitByCharacter) {
      return '$characterCount characters';
    } else {
      return '$wordCount words';
    }
  }
}
