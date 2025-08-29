import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:finora/data/models/backup_model.dart';
import 'package:finora/data/models/check_model.dart';
import 'package:finora/data/models/list_page_model.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'backup_service.g.dart';

// --- SERVICE CLASS (UPDATED FOR FIRESTORE) ---
class BackupService {
  final ExpenseRepository _repo;
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;

  BackupService(this._repo, this._auth, this._googleSignIn, this._firestore);

  // --- Google Sign-In (Corrected based on your example) ---
  Future<User?> signInWithGoogle() async {
    // This pattern is from your working auth_repository.dart
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // User cancelled the sign-in

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      // Correctly passing accessToken and idToken
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    return userCredential.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<BackupModel> createBackupModel() async {
    return _repo.createBackup();
  }

  // --- Restore Logic (Now calls the new merge method in the repository) ---
  Future<void> restoreFromBackupModel(BackupModel backup) async {
    await _repo.restoreAndMergeFromBackup(backup);
  }

  // --- Upload Logic (UPDATED FOR FIRESTORE) ---
  // Add conflict resolution to uploadBackup
  Future<void> uploadBackup(BackupModel backup) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not signed in");

    // Get existing backup to merge if needed
    final existingBackup = await downloadBackup();
    final mergedBackup = existingBackup != null
        ? _mergeBackups(existingBackup, backup)
        : backup;

    final backupJson = mergedBackup.toJson();
    final dataToUpload = {
      ...backupJson,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    final docRef = _firestore.collection('backups').doc(user.uid);
    await docRef.set(dataToUpload);
  }

// Add merge method
  BackupModel _mergeBackups(BackupModel existing, BackupModel newBackup) {
    final mergedLists = <ListPageModel>[];

    // Create map of existing lists
    final existingListMap = {for (var l in existing.lists) l.id: l};

    for (final newList in newBackup.lists) {
      final existingList = existingListMap[newList.id];

      if (existingList != null) {
        // Merge checks from both lists
        final existingCheckMap = {for (var c in existingList.checks) c.id: c};
        final mergedChecks = List<CheckModel>.from(existingList.checks);

        for (final newCheck in newList.checks) {
          if (!existingCheckMap.containsKey(newCheck.id)) {
            mergedChecks.add(newCheck);
          }
        }

        // Use the newer list data
        final isNewer = newList.updatedAt.isAfter(existingList.updatedAt);
        mergedLists.add(newList.copyWith(
          checks: mergedChecks,
          updatedAt: isNewer ? newList.updatedAt : existingList.updatedAt,
        ));
      } else {
        mergedLists.add(newList);
      }
    }

    // Add lists that only exist in existing backup
    for (final existingList in existing.lists) {
      if (!mergedLists.any((l) => l.id == existingList.id)) {
        mergedLists.add(existingList);
      }
    }

    return BackupModel(
      version: newBackup.version,
      createdAt: DateTime.now(),
      lists: mergedLists,
    );
  }

  // --- Download Logic (UPDATED FOR FIRESTORE) ---
  Future<BackupModel?> downloadBackup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Not signed in");

    final docRef = _firestore.collection('backups').doc(user.uid);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null; // No backup exists
    }
    return BackupModel.fromJson(snapshot.data()!);
  }

  // --- Timestamp Logic (UPDATED FOR FIRESTORE) ---
  Future<DateTime?> getLatestBackupTimestamp() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final docRef = _firestore.collection('backups').doc(user.uid);
      final snapshot = await docRef.get();
      if (!snapshot.exists) return null;

      // Get the timestamp from the document field
      final timestamp = snapshot.data()?['lastUpdated'] as Timestamp?;
      return timestamp?.toDate();
    } catch (e) {
      return null;
    }
  }
}

// --- STATE MODEL (Remains the same) ---
class BackupState {
  final User? user;
  final bool isLoading;
  final String? error;
  final DateTime? lastBackupDate;

  BackupState({
    this.user,
    this.isLoading = false,
    this.error,
    this.lastBackupDate,
  });

  BackupState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    DateTime? lastBackupDate,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return BackupState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
      lastBackupDate: lastBackupDate ?? this.lastBackupDate,
    );
  }
}

// --- STATE NOTIFIER (MODERNIZED) ---
@riverpod
class BackupStateNotifier extends _$BackupStateNotifier {
  @override
  BackupState build() {
    final currentUser = ref.read(firebaseAuthProvider).currentUser;
    if (currentUser != null) {
      _fetchLastBackupDate();
      return BackupState(user: currentUser);
    }
    return BackupState();
  }

  BackupService get _service => ref.read(backupServiceProvider);

  Future<void> _fetchLastBackupDate() async {
    final date = await _service.getLatestBackupTimestamp();
    state = state.copyWith(lastBackupDate: date);
  }

  Future<void> signIn() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await _service.signInWithGoogle();
      if (user != null) {
        state = state.copyWith(user: user, isLoading: false);
        await _fetchLastBackupDate();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = state.copyWith(
      clearUser: true,
      isLoading: false,
      lastBackupDate: null,
    );
  }

  Future<void> backupToCloud() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final backup = await _service.createBackupModel();
      await _service.uploadBackup(backup);
      await _fetchLastBackupDate();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> restoreFromCloud() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final backup = await _service.downloadBackup();
      if (backup != null) {
        await _service.restoreFromBackupModel(backup);
      } else {
        throw Exception("No backup found in cloud.");
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> restoreFromFile(File file) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final jsonString = await file.readAsString();
      final backup = BackupModel.fromJson(jsonDecode(jsonString));
      await _service.restoreFromBackupModel(backup);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: "Failed to restore from file: ${e.toString()}",
      );
    }
  }
}

// --- PROVIDERS (MODERNIZED FOR FIRESTORE) ---
@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(Ref ref) => GoogleSignIn();

@Riverpod(keepAlive: true)
FirebaseFirestore firebaseFirestore(Ref ref) => FirebaseFirestore.instance;

@Riverpod(keepAlive: true)
BackupService backupService(Ref ref) {
  return BackupService(
    ref.watch(expenseRepositoryProvider),
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
    ref.watch(firebaseFirestoreProvider), // Switched to Firestore
  );
}
