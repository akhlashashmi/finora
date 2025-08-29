import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_database.g.dart';

// --- TABLES ---

@DataClassName('ListPage')
class ListPages extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 256)();
  RealColumn get budget => real().withDefault(const Constant(0.0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

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


// --- DATABASE ---

@DriftDatabase(tables: [ListPages, Checks])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;
}


// --- PROVIDERS ---

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