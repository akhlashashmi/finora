import 'package:drift/drift.dart';
import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/models/backup_model.dart';
import 'package:finora/data/models/check_model.dart';
import 'package:finora/data/models/list_page_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

part 'expense_repository.g.dart';

class ExpenseRepository {
  final AppDatabase db;
  final Uuid uuid;

  ExpenseRepository({required this.db, required this.uuid});

  // --- ListPage Operations ---
  Stream<List<ListPage>> watchAllLists() => db.select(db.listPages).watch();
  Stream<ListPage?> watchListById(String id) {
    return (db.select(db.listPages)..where((tbl) => tbl.id.equals(id))).watchSingleOrNull();
  }
  Future<ListPage?> getListById(String id) => (db.select(db.listPages)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Future<void> addListPage(String name, {double budget = 0.0}) {
    final now = DateTime.now();
    final entry = ListPagesCompanion(
      id: Value(uuid.v4()),
      name: Value(name),
      budget: Value(budget),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    return db.into(db.listPages).insert(entry);
  }

  Future<void> updateListPage(ListPage entry) {
    return db.update(db.listPages).replace(entry.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteListPage(String id) {
    return (db.delete(db.listPages)..where((tbl) => tbl.id.equals(id))).go();
  }

  // --- Check Operations ---
  Stream<List<Check>> watchChecksForList(String listId) {
    return (db.select(db.checks)
      ..where((tbl) => tbl.listId.equals(listId))
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)])) // Changed to asc
        .watch();
  }

  Future<void> addCheck({required String listId, required double number, String? title}) {
    final now = DateTime.now();
    final entry = ChecksCompanion(
      id: Value(uuid.v4()),
      listId: Value(listId),
      number: Value(number),
      title: Value(title),
      createdAt: Value(now),
      updatedAt: Value(now),
    );
    return db.into(db.checks).insert(entry);
  }

  Future<void> updateCheck(Check entry) {
    return db.update(db.checks).replace(entry.copyWith(updatedAt: DateTime.now()));
  }

  Future<void> deleteCheck(String id) {
    return (db.delete(db.checks)..where((tbl) => tbl.id.equals(id))).go();
  }

  // --- Backup & Restore ---
  Future<BackupModel> createBackup() async {
    final allLists = await db.select(db.listPages).get();
    final allChecks = await db.select(db.checks).get();

    final listPageModels = allLists.map((list) {
      final associatedChecks = allChecks
          .where((check) => check.listId == list.id)
          .map((c) => CheckModel(
          id: c.id,
          title: c.title,
          number: c.number,
          isSelected: c.isSelected,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          listId: c.listId))
          .toList();

      return ListPageModel(
        id: list.id,
        name: list.name,
        budget: list.budget,
        createdAt: list.createdAt,
        updatedAt: list.updatedAt,
        checks: associatedChecks,
      );
    }).toList();

    return BackupModel(
      version: "1.0",
      createdAt: DateTime.now(),
      lists: listPageModels,
    );
  }

  /// Restores data from the backup by first deleting all existing
  /// lists and checks, then inserting all data from the backup file.
  Future<void> restoreAndMergeFromBackup(BackupModel backup) async {
    await db.transaction(() async {
      // Get existing data
      final existingLists = await db.select(db.listPages).get();
      final existingChecks = await db.select(db.checks).get();

      final existingListMap = {for (var l in existingLists) l.id: l};
      final existingCheckMap = {for (var c in existingChecks) c.id: c};

      // Merge lists
      for (final listModel in backup.lists) {
        final existingList = existingListMap[listModel.id];

        if (existingList != null) {
          // Update existing list with newer data
          final updatedList = existingList.copyWith(
            name: listModel.name,
            budget: listModel.budget,
            updatedAt: DateTime.now(),
          );
          await db.update(db.listPages).replace(updatedList);
        } else {
          // Insert new list
          await db.into(db.listPages).insert(ListPagesCompanion.insert(
            id: listModel.id,
            name: listModel.name,
            budget: Value(listModel.budget),
            createdAt: listModel.createdAt,
            updatedAt: listModel.updatedAt,
          ));
        }

        // Merge checks
        for (final checkModel in listModel.checks) {
          final existingCheck = existingCheckMap[checkModel.id];

          if (existingCheck != null) {
            // Update existing check with newer data
            final updatedCheck = existingCheck.copyWith(
              title: Value(checkModel.title),
              number: checkModel.number,
              isSelected: checkModel.isSelected,
              updatedAt: DateTime.now(),
            );
            await db.update(db.checks).replace(updatedCheck);
          } else {
            // Insert new check
            await db.into(db.checks).insert(ChecksCompanion.insert(
              id: checkModel.id,
              listId: checkModel.listId,
              title: Value(checkModel.title),
              number: checkModel.number,
              isSelected: Value(checkModel.isSelected),
              createdAt: checkModel.createdAt,
              updatedAt: checkModel.updatedAt,
            ));
          }
        }
      }
    });
  }
}

// --- PROVIDERS ---

@Riverpod(keepAlive: true)
Uuid uuid(UuidRef ref) => const Uuid();

@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(ExpenseRepositoryRef ref) {
  return ExpenseRepository(
    db: ref.watch(appDatabaseProvider),
    uuid: ref.watch(uuidProvider),
  );
}