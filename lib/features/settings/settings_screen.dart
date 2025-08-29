import 'dart:convert';
import 'dart:io';
import 'package:finora/features/settings/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isLocalBackupExpanded = false;
  bool _isCloudBackupExpanded = false;

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final backupState = ref.watch(backupStateNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Backup')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
        children: [
          // Local Backup Expansion Tile
          _StyledExpansionTile(
            title: 'Local Backup & Restore',
            subtitle: 'Export or import data from a file',
            icon: Icons.storage_rounded,
            isExpanded: _isLocalBackupExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() => _isLocalBackupExpanded = isExpanded);
            },
            children: [
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: const Text('Export to File'),
                subtitle: const Text('Save a JSON backup to your device'),
                onTap: () async {
                  try {
                    final backup = await backupService.createBackupModel();
                    final jsonString = const JsonEncoder.withIndent(
                      '  ',
                    ).convert(backup.toJson());
                    final tempDir = await getTemporaryDirectory();
                    final fileName =
                        'expenses_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.json';
                    final file = File('${tempDir.path}/$fileName');
                    await file.writeAsString(jsonString);

                    await Share.shareXFiles([
                      XFile(file.path),
                    ], text: 'Here is my expense backup.');
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: $e')),
                    );
                  }
                },
              ),
              // CustomDivider(),
              ListTile(
                leading: const Icon(Icons.upload_file_outlined),
                title: const Text('Import from File'),
                subtitle: const Text('Restore data from a local JSON file'),
                onTap: () async {
                  FilePickerResult? result = await FilePicker.platform
                      .pickFiles();
                  if (result != null) {
                    File file = File(result.files.single.path!);
                    await ref
                        .read(backupStateNotifierProvider.notifier)
                        .restoreFromFile(file);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Cloud Backup Expansion Tile
          _StyledExpansionTile(
            title: 'Cloud Backup',
            subtitle: 'Sign in to sync with the cloud',
            icon: Icons.cloud_upload_outlined,
            isExpanded: _isCloudBackupExpanded,
            onExpansionChanged: (isExpanded) {
              setState(() => _isCloudBackupExpanded = isExpanded);
            },
            children: [
              if (backupState.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (!backupState.isLoading) ...[
                if (backupState.user == null)
                  ListTile(
                    leading: const Icon(Icons.login),
                    title: const Text('Sign in with Google'),
                    subtitle: const Text('Required for cloud backup & restore'),
                    onTap: () =>
                        ref.read(backupStateNotifierProvider.notifier).signIn(),
                  ),
                if (backupState.user != null) ...[
                  // CustomDivider(),
                  ListTile(
                    leading: const Icon(Icons.cloud_download_outlined),
                    title: const Text('Restore from Cloud'),
                    subtitle: backupState.lastBackupDate != null
                        ? Text(
                            'Last backup: ${DateFormat.yMd().add_jm().format(backupState.lastBackupDate!)}',
                          )
                        : const Text('No cloud backups found'),
                    onTap: backupState.lastBackupDate != null
                        ? () => ref
                              .read(backupStateNotifierProvider.notifier)
                              .restoreFromCloud()
                        : null,
                  ),

                  // CustomDivider(),
                  ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: const Text('Backup to Cloud'),
                    subtitle: Text('Signed in as ${backupState.user!.email}'),
                    onTap: () => ref
                        .read(backupStateNotifierProvider.notifier)
                        .backupToCloud(),
                  ),

                  // CustomDivider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Sign Out'),
                    onTap: () => ref
                        .read(backupStateNotifierProvider.notifier)
                        .signOut(),
                  ),
                ],
                if (backupState.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                    child: Text(
                      'Error: ${backupState.error}',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A reusable expansion tile with the desired outlined UI design.
class _StyledExpansionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isExpanded;
  final ValueChanged<bool> onExpansionChanged;
  final List<Widget> children;

  const _StyledExpansionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: ExpansionTile(
        onExpansionChanged: onExpansionChanged,
        shape: const Border(), // Remove the default border when expanded
        leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: isExpanded
            ? null
            : Text(
                subtitle,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
        childrenPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        children: children,
      ),
    );
  }
}
