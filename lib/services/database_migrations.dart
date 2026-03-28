import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Database version - increment when adding new migrations
const int databaseVersion = 19;

const _uuid = Uuid();

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
    await db.execute(
      'CREATE INDEX idx_translations_term ON translations(term_id)',
    );

    // Migrate existing translations from terms table
    await db.execute('''
      INSERT INTO translations (term_id, meaning, sort_order)
      SELECT id, translation, 0 FROM terms WHERE translation IS NOT NULL AND translation != ''
    ''');
  }
  if (oldVersion < 8) {
    // Add base_translation_id column (replaces base_form TEXT which is left unused)
    await db.execute(
      'ALTER TABLE translations ADD COLUMN base_translation_id INTEGER',
    );
  }
  if (oldVersion < 9) {
    await db.execute('''
      CREATE TABLE text_foreign_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text_id INTEGER NOT NULL,
        lower_text TEXT NOT NULL,
        language_id INTEGER NOT NULL,
        term_id INTEGER,
        FOREIGN KEY (text_id) REFERENCES texts (id) ON DELETE CASCADE,
        FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE SET NULL,
        UNIQUE(text_id, lower_text)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_tfw_text ON text_foreign_words(text_id)',
    );
  }
  if (oldVersion < 10) {
    await db.execute('''
      CREATE TABLE review_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term_id INTEGER NOT NULL UNIQUE,
        card_data TEXT NOT NULL,
        next_due TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_review_cards_term ON review_cards(term_id)',
    );
    await db.execute(
      'CREATE INDEX idx_review_cards_due ON review_cards(next_due)',
    );

    await db.execute('''
      CREATE TABLE review_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term_id INTEGER NOT NULL,
        log_data TEXT NOT NULL,
        reviewed_at TEXT NOT NULL,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_review_logs_term ON review_logs(term_id)',
    );
    await db.execute(
      'CREATE INDEX idx_review_logs_date ON review_logs(reviewed_at)',
    );
  }
  if (oldVersion < 11) {
    await db.execute('ALTER TABLE languages ADD COLUMN language_code TEXT');
    // Backfill known language codes from language names
    const nameToCode = {
      'arabic': 'ar',
      'bulgarian': 'bg',
      'chinese': 'zh',
      'czech': 'cs',
      'danish': 'da',
      'dutch': 'nl',
      'english': 'en',
      'estonian': 'et',
      'finnish': 'fi',
      'french': 'fr',
      'german': 'de',
      'greek': 'el',
      'hebrew': 'he',
      'hindi': 'hi',
      'hungarian': 'hu',
      'indonesian': 'id',
      'irish': 'ga',
      'italian': 'it',
      'japanese': 'ja',
      'korean': 'ko',
      'latvian': 'lv',
      'lithuanian': 'lt',
      'norwegian': 'nb',
      'polish': 'pl',
      'portuguese': 'pt',
      'romanian': 'ro',
      'russian': 'ru',
      'slovak': 'sk',
      'slovenian': 'sl',
      'spanish': 'es',
      'swedish': 'sv',
      'thai': 'th',
      'turkish': 'tr',
      'ukrainian': 'uk',
      'vietnamese': 'vi',
    };
    for (final entry in nameToCode.entries) {
      await db.execute(
        "UPDATE languages SET language_code = ? WHERE LOWER(name) = ?",
        [entry.value, entry.key],
      );
    }
  }
  if (oldVersion < 12) {
    await db.execute(
      'CREATE INDEX idx_texts_lang_status ON texts(language_id, status)',
    );
    await db.execute(
      'CREATE INDEX idx_texts_lang_collection ON texts(language_id, collection_id)',
    );
    await db.execute(
      'CREATE INDEX idx_review_logs_term_date ON review_logs(term_id, reviewed_at)',
    );
  }
  if (oldVersion < 13) {
    await db.execute(
      'ALTER TABLE languages ADD COLUMN use_word_segmentation INTEGER DEFAULT 0',
    );
  }
  if (oldVersion < 14) {
    await db.execute(
      'ALTER TABLE dictionaries ADD COLUMN custom_css TEXT',
    );
  }
  if (oldVersion < 15) {
    await db.execute('''
      CREATE TABLE term_status_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term_id INTEGER NOT NULL,
        status INTEGER NOT NULL,
        changed_at TEXT NOT NULL,
        FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_term_status_log_term ON term_status_log(term_id)',
    );
    await db.execute(
      'CREATE INDEX idx_term_status_log_date ON term_status_log(changed_at)',
    );
    await db.rawInsert('''
      INSERT INTO term_status_log (term_id, status, changed_at)
      SELECT id, 1, created_at FROM terms
    ''');
    await db.rawInsert('''
      INSERT INTO term_status_log (term_id, status, changed_at)
      SELECT id, status, last_accessed FROM terms
      WHERE status != 1
    ''');
  }
  if (oldVersion < 16) {
    await db.execute('''
      CREATE TABLE radical_progress (
        radical_char TEXT PRIMARY KEY,
        practiced_count INTEGER NOT NULL DEFAULT 0,
        last_practiced TEXT
      )
    ''');
  }
  if (oldVersion < 17) {
    await db.execute('''
      CREATE TABLE term_sentences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        term_id INTEGER NOT NULL,
        sentence TEXT NOT NULL,
        source_text_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY (term_id) REFERENCES terms(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_term_sentences_term ON term_sentences(term_id)',
    );
  }
  if (oldVersion < 18) {
    await _migrateToUuids(db);
  }
  if (oldVersion < 19) {
    await _recoverOrphanedEpubTexts(db);
  }
}

/// Migrate all integer primary keys to TEXT UUIDs (v17 → v18).
///
/// Strategy:
/// 1. Turn off FK enforcement so we can freely drop/recreate tables.
/// 2. Read all rows, generate UUID mappings for every integer PK.
/// 3. Create new tables with TEXT PKs.
/// 4. Copy rows with UUID PKs and mapped UUID FK references.
/// 5. Drop old tables, rename new ones.
/// 6. Re-enable FK enforcement.
Future<void> _migrateToUuids(Database db) async {
  await db.execute('PRAGMA foreign_keys = OFF');

  // ── 1. Generate UUID maps (oldIntId → newUuid) for each table ──

  Map<int, String> genMap(List<Map<String, Object?>> rows) => {
        for (final r in rows) r['id'] as int: _uuid.v4(),
      };

  final langIds = genMap(await db.rawQuery('SELECT id FROM languages'));
  final collIds = genMap(await db.rawQuery('SELECT id FROM collections'));
  final textIds = genMap(await db.rawQuery('SELECT id FROM texts'));
  final termIds = genMap(await db.rawQuery('SELECT id FROM terms'));
  final transIds = genMap(await db.rawQuery('SELECT id FROM translations'));
  final tfwIds = genMap(await db.rawQuery('SELECT id FROM text_foreign_words'));
  final rcIds = genMap(await db.rawQuery('SELECT id FROM review_cards'));
  final rlIds = genMap(await db.rawQuery('SELECT id FROM review_logs'));
  final tslIds = genMap(await db.rawQuery('SELECT id FROM term_status_log'));
  final tsIds = genMap(await db.rawQuery('SELECT id FROM term_sentences'));
  final dictIds = genMap(await db.rawQuery('SELECT id FROM dictionaries'));

  // ── 2. Create new tables with TEXT PKs ──

  await db.execute('''
    CREATE TABLE new_languages (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      language_code TEXT,
      right_to_left INTEGER DEFAULT 0,
      show_romanization INTEGER DEFAULT 0,
      split_by_character INTEGER DEFAULT 0,
      use_word_segmentation INTEGER DEFAULT 0,
      character_substitutions TEXT,
      regexp_word_characters TEXT,
      regexp_split_sentences TEXT,
      exceptions_split_sentences TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE new_collections (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      parent_id TEXT,
      created_at TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      cover_image TEXT,
      FOREIGN KEY (language_id) REFERENCES new_languages (id) ON DELETE CASCADE,
      FOREIGN KEY (parent_id) REFERENCES new_collections (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_texts (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      collection_id TEXT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      source_uri TEXT,
      created_at TEXT NOT NULL,
      last_read TEXT NOT NULL,
      position INTEGER DEFAULT 0,
      sort_order INTEGER DEFAULT 0,
      cover_image TEXT,
      status INTEGER DEFAULT 0,
      FOREIGN KEY (language_id) REFERENCES new_languages (id) ON DELETE CASCADE,
      FOREIGN KEY (collection_id) REFERENCES new_collections (id) ON DELETE SET NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE new_terms (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      text TEXT NOT NULL,
      lower_text TEXT NOT NULL,
      status INTEGER DEFAULT 1,
      translation TEXT,
      romanization TEXT,
      sentence TEXT,
      created_at TEXT NOT NULL,
      last_accessed TEXT NOT NULL,
      base_term_id TEXT,
      FOREIGN KEY (language_id) REFERENCES new_languages (id) ON DELETE CASCADE,
      FOREIGN KEY (base_term_id) REFERENCES new_terms (id) ON DELETE SET NULL,
      UNIQUE(language_id, lower_text)
    )
  ''');

  await db.execute('''
    CREATE TABLE new_translations (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      meaning TEXT NOT NULL,
      part_of_speech TEXT,
      base_translation_id TEXT,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_dictionaries (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      custom_css TEXT,
      FOREIGN KEY (language_id) REFERENCES new_languages (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_text_foreign_words (
      id TEXT PRIMARY KEY,
      text_id TEXT NOT NULL,
      lower_text TEXT NOT NULL,
      language_id TEXT NOT NULL,
      term_id TEXT,
      FOREIGN KEY (text_id) REFERENCES new_texts (id) ON DELETE CASCADE,
      FOREIGN KEY (language_id) REFERENCES new_languages (id) ON DELETE CASCADE,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE SET NULL,
      UNIQUE(text_id, lower_text)
    )
  ''');

  await db.execute('''
    CREATE TABLE new_review_cards (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL UNIQUE,
      card_data TEXT NOT NULL,
      next_due TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_review_logs (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      log_data TEXT NOT NULL,
      reviewed_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_term_status_log (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      status INTEGER NOT NULL,
      changed_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
    )
  ''');

  await db.execute('''
    CREATE TABLE new_term_sentences (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      sentence TEXT NOT NULL,
      source_text_id TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES new_terms (id) ON DELETE CASCADE
    )
  ''');

  // ── 3. Copy data with UUID PKs and mapped FK references ──

  for (final row in await db.rawQuery('SELECT * FROM languages')) {
    final oldId = row['id'] as int;
    await db.insert('new_languages', {
      'id': langIds[oldId],
      'name': row['name'],
      'language_code': row['language_code'],
      'right_to_left': row['right_to_left'],
      'show_romanization': row['show_romanization'],
      'split_by_character': row['split_by_character'],
      'use_word_segmentation': row['use_word_segmentation'],
      'character_substitutions': row['character_substitutions'],
      'regexp_word_characters': row['regexp_word_characters'],
      'regexp_split_sentences': row['regexp_split_sentences'],
      'exceptions_split_sentences': row['exceptions_split_sentences'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM collections')) {
    final oldId = row['id'] as int;
    final oldLangId = row['language_id'] as int?;
    final newLangId = oldLangId != null ? langIds[oldLangId] : null;
    if (newLangId == null) continue; // skip orphaned rows
    final oldParentId = row['parent_id'] as int?;
    await db.insert('new_collections', {
      'id': collIds[oldId],
      'language_id': newLangId,
      'name': row['name'],
      'description': row['description'],
      'parent_id': oldParentId != null ? collIds[oldParentId] : null,
      'created_at': row['created_at'],
      'sort_order': row['sort_order'],
      'cover_image': row['cover_image'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM texts')) {
    final oldId = row['id'] as int;
    final oldLangId = row['language_id'] as int?;
    final newLangId = oldLangId != null ? langIds[oldLangId] : null;
    if (newLangId == null) continue; // skip orphaned rows
    final oldCollId = row['collection_id'] as int?;
    await db.insert('new_texts', {
      'id': textIds[oldId],
      'language_id': newLangId,
      'collection_id': oldCollId != null ? collIds[oldCollId] : null,
      'title': row['title'],
      'content': row['content'],
      'source_uri': row['source_uri'],
      'created_at': row['created_at'],
      'last_read': row['last_read'],
      'position': row['position'],
      'sort_order': row['sort_order'],
      'cover_image': row['cover_image'],
      'status': row['status'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM terms')) {
    final oldId = row['id'] as int;
    final oldLangId = row['language_id'] as int?;
    final newLangId = oldLangId != null ? langIds[oldLangId] : null;
    if (newLangId == null) continue; // skip orphaned rows
    final oldBaseId = row['base_term_id'] as int?;
    await db.insert('new_terms', {
      'id': termIds[oldId],
      'language_id': newLangId,
      'text': row['text'],
      'lower_text': row['lower_text'],
      'status': row['status'],
      'translation': row['translation'],
      'romanization': row['romanization'],
      'sentence': row['sentence'],
      'created_at': row['created_at'],
      'last_accessed': row['last_accessed'],
      'base_term_id': oldBaseId != null ? termIds[oldBaseId] : null,
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM translations')) {
    final oldId = row['id'] as int;
    final oldTermId = row['term_id'] as int?;
    final newTermId = oldTermId != null ? termIds[oldTermId] : null;
    if (newTermId == null) continue; // skip orphaned translations
    final oldBaseTransId = row['base_translation_id'] as int?;
    await db.insert('new_translations', {
      'id': transIds[oldId],
      'term_id': newTermId,
      'meaning': row['meaning'],
      'part_of_speech': row['part_of_speech'],
      'base_translation_id':
          oldBaseTransId != null ? transIds[oldBaseTransId] : null,
      'sort_order': row['sort_order'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM dictionaries')) {
    final oldId = row['id'] as int;
    final oldLangId = row['language_id'] as int?;
    final newLangId = oldLangId != null ? langIds[oldLangId] : null;
    if (newLangId == null) continue; // skip orphaned rows
    await db.insert('new_dictionaries', {
      'id': dictIds[oldId],
      'language_id': newLangId,
      'name': row['name'],
      'url': row['url'],
      'sort_order': row['sort_order'],
      'is_active': row['is_active'],
      'custom_css': row['custom_css'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM text_foreign_words')) {
    final oldId = row['id'] as int;
    final oldTextId = row['text_id'] as int?;
    final newTextId = oldTextId != null ? textIds[oldTextId] : null;
    if (newTextId == null) continue; // skip orphaned rows
    final oldLangId = row['language_id'] as int?;
    final newLangId = oldLangId != null ? langIds[oldLangId] : null;
    if (newLangId == null) continue;
    final oldTermId = row['term_id'] as int?;
    await db.insert('new_text_foreign_words', {
      'id': tfwIds[oldId],
      'text_id': newTextId,
      'lower_text': row['lower_text'],
      'language_id': newLangId,
      'term_id': oldTermId != null ? termIds[oldTermId] : null,
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM review_cards')) {
    final oldId = row['id'] as int;
    final oldTermId = row['term_id'] as int?;
    final newTermId = oldTermId != null ? termIds[oldTermId] : null;
    if (newTermId == null) continue; // skip orphaned rows
    await db.insert('new_review_cards', {
      'id': rcIds[oldId],
      'term_id': newTermId,
      'card_data': row['card_data'],
      'next_due': row['next_due'],
      'created_at': row['created_at'],
      'updated_at': row['updated_at'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM review_logs')) {
    final oldId = row['id'] as int;
    final oldTermId = row['term_id'] as int?;
    final newTermId = oldTermId != null ? termIds[oldTermId] : null;
    if (newTermId == null) continue; // skip orphaned rows
    await db.insert('new_review_logs', {
      'id': rlIds[oldId],
      'term_id': newTermId,
      'log_data': row['log_data'],
      'reviewed_at': row['reviewed_at'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM term_status_log')) {
    final oldId = row['id'] as int;
    final oldTermId = row['term_id'] as int?;
    final newTermId = oldTermId != null ? termIds[oldTermId] : null;
    if (newTermId == null) continue; // skip orphaned rows
    await db.insert('new_term_status_log', {
      'id': tslIds[oldId],
      'term_id': newTermId,
      'status': row['status'],
      'changed_at': row['changed_at'],
    });
  }

  for (final row in await db.rawQuery('SELECT * FROM term_sentences')) {
    final oldId = row['id'] as int;
    final oldTermId = row['term_id'] as int?;
    final newTermId = oldTermId != null ? termIds[oldTermId] : null;
    if (newTermId == null) continue; // skip orphaned rows
    final oldSrcTextId = row['source_text_id'] as int?;
    await db.insert('new_term_sentences', {
      'id': tsIds[oldId],
      'term_id': newTermId,
      'sentence': row['sentence'],
      'source_text_id':
          oldSrcTextId != null ? textIds[oldSrcTextId] : null,
      'created_at': row['created_at'],
    });
  }

  // ── 4. Drop old tables and rename new ones ──

  // Drop in reverse dependency order to avoid any implicit issues
  await db.execute('DROP TABLE IF EXISTS term_sentences');
  await db.execute('DROP TABLE IF EXISTS term_status_log');
  await db.execute('DROP TABLE IF EXISTS review_logs');
  await db.execute('DROP TABLE IF EXISTS review_cards');
  await db.execute('DROP TABLE IF EXISTS text_foreign_words');
  await db.execute('DROP TABLE IF EXISTS translations');
  await db.execute('DROP TABLE IF EXISTS dictionaries');
  await db.execute('DROP TABLE IF EXISTS terms');
  await db.execute('DROP TABLE IF EXISTS texts');
  await db.execute('DROP TABLE IF EXISTS collections');
  await db.execute('DROP TABLE IF EXISTS languages');

  await db.execute('ALTER TABLE new_languages RENAME TO languages');
  await db.execute('ALTER TABLE new_collections RENAME TO collections');
  await db.execute('ALTER TABLE new_texts RENAME TO texts');
  await db.execute('ALTER TABLE new_terms RENAME TO terms');
  await db.execute('ALTER TABLE new_translations RENAME TO translations');
  await db.execute('ALTER TABLE new_dictionaries RENAME TO dictionaries');
  await db.execute('ALTER TABLE new_text_foreign_words RENAME TO text_foreign_words');
  await db.execute('ALTER TABLE new_review_cards RENAME TO review_cards');
  await db.execute('ALTER TABLE new_review_logs RENAME TO review_logs');
  await db.execute('ALTER TABLE new_term_status_log RENAME TO term_status_log');
  await db.execute('ALTER TABLE new_term_sentences RENAME TO term_sentences');

  // ── 5. Recreate indexes ──

  await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
  await db.execute('CREATE INDEX idx_terms_language ON terms(language_id)');
  await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
  await db.execute('CREATE INDEX idx_texts_language ON texts(language_id)');
  await db.execute('CREATE INDEX idx_texts_lang_status ON texts(language_id, status)');
  await db.execute('CREATE INDEX idx_texts_lang_collection ON texts(language_id, collection_id)');
  await db.execute('CREATE INDEX idx_translations_term ON translations(term_id)');
  await db.execute('CREATE INDEX idx_collections_language ON collections(language_id)');
  await db.execute('CREATE INDEX idx_collections_parent ON collections(parent_id)');
  await db.execute('CREATE INDEX idx_dictionaries_language ON dictionaries(language_id)');
  await db.execute('CREATE INDEX idx_tfw_text ON text_foreign_words(text_id)');
  await db.execute('CREATE INDEX idx_review_cards_term ON review_cards(term_id)');
  await db.execute('CREATE INDEX idx_review_cards_due ON review_cards(next_due)');
  await db.execute('CREATE INDEX idx_review_logs_term ON review_logs(term_id)');
  await db.execute('CREATE INDEX idx_review_logs_date ON review_logs(reviewed_at)');
  await db.execute('CREATE INDEX idx_review_logs_term_date ON review_logs(term_id, reviewed_at)');
  await db.execute('CREATE INDEX idx_term_status_log_term ON term_status_log(term_id)');
  await db.execute('CREATE INDEX idx_term_status_log_date ON term_status_log(changed_at)');
  await db.execute('CREATE INDEX idx_term_sentences_term ON term_sentences(term_id)');

  await db.execute('PRAGMA foreign_keys = ON');
}

/// Recover EPUB texts that ended up at root (collection_id IS NULL) because
/// their book collection was missing from the DB at migration time.
///
/// Groups orphaned EPUB texts by source_uri (format: 'epub://BookTitle') and
/// creates a new recovery collection for each group that has 2+ texts.
Future<void> _recoverOrphanedEpubTexts(Database db) async {
  final orphaned = await db.rawQuery(
    "SELECT id, language_id, source_uri FROM texts "
    "WHERE collection_id IS NULL AND source_uri LIKE 'epub://%'",
  );
  if (orphaned.isEmpty) return;

  // Group by source_uri.
  final grouped = <String, List<Map<String, Object?>>>{};
  for (final row in orphaned) {
    final uri = row['source_uri'] as String;
    grouped.putIfAbsent(uri, () => []).add(row);
  }

  for (final entry in grouped.entries) {
    final sourceUri = entry.key;
    final rows = entry.value;
    if (rows.length < 2) continue; // lone text — leave at root

    final title = sourceUri.substring('epub://'.length);
    final languageId = rows.first['language_id'] as String;
    final collectionId = _uuid.v4();

    await db.insert('collections', {
      'id': collectionId,
      'language_id': languageId,
      'name': title,
      'description': '',
      'parent_id': null,
      'created_at': DateTime.now().toIso8601String(),
      'sort_order': 0,
      'cover_image': null,
    });

    for (final row in rows) {
      await db.update(
        'texts',
        {'collection_id': collectionId},
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  }
}

/// Create fresh database with all tables (UUID PKs from the start)
Future<void> onCreate(Database db, int version) async {
  await db.execute('''
    CREATE TABLE languages (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      language_code TEXT,
      right_to_left INTEGER DEFAULT 0,
      show_romanization INTEGER DEFAULT 0,
      split_by_character INTEGER DEFAULT 0,
      use_word_segmentation INTEGER DEFAULT 0,
      character_substitutions TEXT,
      regexp_word_characters TEXT,
      regexp_split_sentences TEXT,
      exceptions_split_sentences TEXT
    )
  ''');

  await db.execute('''
    CREATE TABLE texts (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      collection_id TEXT,
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
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      text TEXT NOT NULL,
      lower_text TEXT NOT NULL,
      status INTEGER DEFAULT 1,
      translation TEXT,
      romanization TEXT,
      sentence TEXT,
      created_at TEXT NOT NULL,
      last_accessed TEXT NOT NULL,
      base_term_id TEXT,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
      FOREIGN KEY (base_term_id) REFERENCES terms (id) ON DELETE SET NULL,
      UNIQUE(language_id, lower_text)
    )
  ''');

  await db.execute('CREATE INDEX idx_terms_lower ON terms(lower_text)');
  await db.execute('CREATE INDEX idx_terms_language ON terms(language_id)');
  await db.execute('CREATE INDEX idx_terms_base ON terms(base_term_id)');
  await db.execute('CREATE INDEX idx_texts_language ON texts(language_id)');
  await db.execute(
    'CREATE INDEX idx_texts_lang_status ON texts(language_id, status)',
  );
  await db.execute(
    'CREATE INDEX idx_texts_lang_collection ON texts(language_id, collection_id)',
  );

  await db.execute('''
    CREATE TABLE translations (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      meaning TEXT NOT NULL,
      part_of_speech TEXT,
      base_translation_id TEXT,
      sort_order INTEGER DEFAULT 0,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_translations_term ON translations(term_id)',
  );

  await db.execute('''
    CREATE TABLE collections (
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      name TEXT NOT NULL,
      description TEXT,
      parent_id TEXT,
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
      id TEXT PRIMARY KEY,
      language_id TEXT NOT NULL,
      name TEXT NOT NULL,
      url TEXT NOT NULL,
      sort_order INTEGER DEFAULT 0,
      is_active INTEGER DEFAULT 1,
      custom_css TEXT,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE
    )
  ''');

  await db.execute(
    'CREATE INDEX idx_dictionaries_language ON dictionaries(language_id)',
  );

  await db.execute('''
    CREATE TABLE text_foreign_words (
      id TEXT PRIMARY KEY,
      text_id TEXT NOT NULL,
      lower_text TEXT NOT NULL,
      language_id TEXT NOT NULL,
      term_id TEXT,
      FOREIGN KEY (text_id) REFERENCES texts (id) ON DELETE CASCADE,
      FOREIGN KEY (language_id) REFERENCES languages (id) ON DELETE CASCADE,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE SET NULL,
      UNIQUE(text_id, lower_text)
    )
  ''');
  await db.execute('CREATE INDEX idx_tfw_text ON text_foreign_words(text_id)');

  await db.execute('''
    CREATE TABLE review_cards (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL UNIQUE,
      card_data TEXT NOT NULL,
      next_due TEXT NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_review_cards_term ON review_cards(term_id)',
  );
  await db.execute(
    'CREATE INDEX idx_review_cards_due ON review_cards(next_due)',
  );

  await db.execute('''
    CREATE TABLE review_logs (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      log_data TEXT NOT NULL,
      reviewed_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
    )
  ''');
  await db.execute('CREATE INDEX idx_review_logs_term ON review_logs(term_id)');
  await db.execute(
    'CREATE INDEX idx_review_logs_date ON review_logs(reviewed_at)',
  );
  await db.execute(
    'CREATE INDEX idx_review_logs_term_date ON review_logs(term_id, reviewed_at)',
  );
  await db.execute('''
    CREATE TABLE term_status_log (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      status INTEGER NOT NULL,
      changed_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES terms (id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_term_status_log_term ON term_status_log(term_id)',
  );
  await db.execute(
    'CREATE INDEX idx_term_status_log_date ON term_status_log(changed_at)',
  );
  await db.execute('''
    CREATE TABLE radical_progress (
      radical_char TEXT PRIMARY KEY,
      practiced_count INTEGER NOT NULL DEFAULT 0,
      last_practiced TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE term_sentences (
      id TEXT PRIMARY KEY,
      term_id TEXT NOT NULL,
      sentence TEXT NOT NULL,
      source_text_id TEXT,
      created_at TEXT NOT NULL,
      FOREIGN KEY (term_id) REFERENCES terms(id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_term_sentences_term ON term_sentences(term_id)',
  );
}
