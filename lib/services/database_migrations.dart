import 'package:sqflite/sqflite.dart';

/// Database version - increment when adding new migrations
const int databaseVersion = 8;

/// Handle database upgrades from older versions
Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
  if (oldVersion < 2) {
    await db.execute(
      'ALTER TABLE texts ADD COLUMN sort_order INTEGER DEFAULT 0',
    );
  }
  if (oldVersion < 3) {
    await db.execute('ALTER TABLE collections ADD COLUMN cover_image TEXT');
  }
  if (oldVersion < 4) {
    await db.execute(
      'ALTER TABLE terms ADD COLUMN base_term_id INTEGER REFERENCES terms(id) ON DELETE SET NULL',
    );
    await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
  }
  if (oldVersion < 5) {
    await db.execute('ALTER TABLE texts ADD COLUMN cover_image TEXT');
  }
  if (oldVersion < 6) {
    await db.execute('ALTER TABLE texts ADD COLUMN status INTEGER DEFAULT 0');
  }
  if (oldVersion < 7) {
    await db.execute('''
      CREATE TABLE translations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term_id INTEGER NOT NULL,
        meaning TEXT NOT NULL,
        part_of_speech TEXT,
        base_form TEXT,
        sort_order INTEGER DEFAULT 0,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_translations_term ON translations(term_id)');

    // Migrate existing translations from terms table
    await db.execute('''
      INSERT INTO translations (term_id, meaning, sort_order)
      SELECT id, translation, 0 FROM terms WHERE translation IS NOT NULL AND translation != ''
    ''');
  }
  if (oldVersion < 8) {
    // Add base_translation_id column (replaces base_form TEXT which is left unused)
    await db.execute('ALTER TABLE translations ADD COLUMN base_translation_id INTEGER');
  }
}

/// Create fresh database with all tables
Future<void> onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE languages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE,
      right_to_left INTEGER DEFAULT 0,
      show_romanization INTEGER DEFAULT 0,
      split_by_character INTEGER DEFAULT 0,
      character_substitutions TEXT,
      regexp_word_characters TEXT,
      regexp_split_sentences TEXT,
      exceptions_split_sentences TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE texts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      language_id INTEGER NOT NULL,
      collection_id INTEGER,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      source_uri TEXT,
      created_at TEXT NOT NULL,
      last_read TEXT NOT NULL,
      position INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      cover_image TEXT,
      status INTEGER DEFAULT 0,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
      FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE SET NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE terms (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      language_id INTEGER NOT NULL,
      text TEXT NOT NULL,
      lower_text TEXT NOT NULL,
      status INTEGER DEFAULT 1,
      translation TEXT,
      romanization TEXT,
      sentence TEXT,
      created_at TEXT NOT NULL,
      last_accessed TEXT NOT NULL,
      base_term_id INTEGER,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
      FOREIGN KEY (base_term_id) REFERENCES terms (id) ON DELETE SET NULL,
      UNIQUE(language_id, lower_text)
    )
  ''');

  await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
  await db.execute('CREATE INDEX idx_terms_language ON terms(language_id)');
  await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
  await db.execute('CREATE INDEX idx_texts_language ON texts(language_id)');

  await db.execute('''
    CREATE TABLE translations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      term_id INTEGER NOT NULL,
      meaning TEXT NOT NULL,
      part_of_speech TEXT,
      base_translation_id INTEGER,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_translations_term ON translations(term_id)');

  await db.execute('''
    CREATE TABLE collections (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      language_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      parent_id INTEGER,
      created_at TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      cover_image TEXT,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
      FOREIGN KEY (parent_id) REFERENCES collections (id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX idx_collections_language ON collections(language_id)',
  );
  await db.execute(
    'CREATE INDEX idx_collections_parent ON collections(parent_id)',
  );

  await db.execute('''
    CREATE TABLE dictionaries (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      language_id INTEGER NOT NULL,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX idx_dictionaries_language ON dictionaries(language_id)',
  );
}
