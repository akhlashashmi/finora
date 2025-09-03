import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

@DataClassName('ListPage')
class ListPages extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 256)();
  RealColumn get budget => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isProtected => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Check')
class Checks extends Table {
  TextColumn get id => text()();
  TextColumn get listId => text().references(ListPages, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text().nullable()();
  RealColumn get number => real()();
  BoolColumn get isSelected => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [ListPages, Checks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(listPages, listPages.sortOrder);
          await m.addColumn(listPages, listPages.isPinned);
          await m.addColumn(listPages, listPages.isProtected); // Add for v1 -> v3
          // Set initial sort order for v1 users
          await customStatement('''
            UPDATE list_pages 
            SET sort_order = (
              SELECT ROW_NUMBER() OVER (ORDER BY created_at) - 1
              FROM (SELECT * FROM list_pages) as ranked
              WHERE ranked.id = list_pages.id
            )
          ''');
        }
        if (from < 3) {
          await m.addColumn(listPages, listPages.isProtected);
        }
      },
    );
  }
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase(_openConnection());
  ref.onDispose(() => db.close());
  return db;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}