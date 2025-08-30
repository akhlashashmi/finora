import 'dart:convert';
import 'dart:io';
import 'package:finora/features/settings/backup_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final backupState = ref.watch(backupStateNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Local Backup Section
                _SectionCard(
                  title: 'Local Backup',
                  description: 'Export or import data from local files',
                  icon: Icons.storage_rounded,
                  color: theme.colorScheme.primary,
                  children: [
                    _ActionTile(
                      icon: Icons.download_for_offline_outlined,
                      title: 'Export to File',
                      subtitle: 'Save a JSON backup',
                      onTap: () async {
                        try {
                          final backup = await backupService.createBackupModel();
                          final jsonString = const JsonEncoder.withIndent('  ')
                              .convert(backup.toJson());

                          // Let user pick a folder
                          String? directoryPath =
                          await FilePicker.platform.getDirectoryPath();

                          if (directoryPath == null) {
                            // User canceled folder selection
                            return;
                          }

                          final fileName =
                              'expenses_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.json';
                          final file = File('$directoryPath/$fileName');

                          await file.writeAsString(jsonString);

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content:
                              Text('Backup saved to: $directoryPath/$fileName'),
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Export failed: $e')),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _ActionTile(
                      icon: Icons.upload_file_outlined,
                      title: 'Import from File',
                      subtitle: 'Restore data from a local JSON file',
                      onTap: () async {
                        FilePickerResult? result =
                        await FilePicker.platform.pickFiles();
                        if (result != null) {
                          File file = File(result.files.single.path!);
                          await ref
                              .read(backupStateNotifierProvider.notifier)
                              .restoreFromFile(file);

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Backup restored successfully.'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Cloud Backup Section
                _SectionCard(
                  title: 'Cloud Backup',
                  description: backupState.user != null
                      ? 'Signed in as ${backupState.user!.email}'
                      : 'Sign in to sync with the cloud',
                  icon: Icons.cloud_outlined,
                  color: theme.colorScheme.tertiary,
                  children: [
                    if (backupState.isLoading)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (!backupState.isLoading) ...[
                      if (backupState.user == null)
                        _ActionTile(
                          icon: Icons.login,
                          title: 'Sign in with Google',
                          subtitle: 'Required for cloud backup & restore',
                          onTap: () => ref
                              .read(backupStateNotifierProvider.notifier)
                              .signIn(),
                        ),
                      if (backupState.user != null) ...[
                        _ActionTile(
                          icon: Icons.cloud_download_outlined,
                          title: 'Restore from Cloud',
                          subtitle: backupState.lastBackupDate != null
                              ? 'Last backup: ${DateFormat.yMd().add_jm().format(backupState.lastBackupDate!)}'
                              : 'No cloud backups found',
                          onTap: backupState.lastBackupDate != null
                              ? () => ref
                              .read(backupStateNotifierProvider.notifier)
                              .restoreFromCloud()
                              : null,
                        ),
                        const SizedBox(height: 8),
                        _ActionTile(
                          icon: Icons.cloud_upload_outlined,
                          title: 'Backup to Cloud',
                          subtitle: 'Save your data to Google Drive',
                          onTap: () => ref
                              .read(backupStateNotifierProvider.notifier)
                              .backupToCloud(),
                        ),
                        const SizedBox(height: 8),
                        _ActionTile(
                          icon: Icons.logout,
                          title: 'Sign Out',
                          subtitle: 'Disconnect from Google account',
                          onTap: () => ref
                              .read(backupStateNotifierProvider.notifier)
                              .signOut(),
                          isDestructive: true,
                        ),
                      ],
                      if (backupState.error != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Error: ${backupState.error}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outline.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Section Content
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? theme.colorScheme.error.withOpacity(0.1)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isEnabled
                      ? (isDestructive
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant)
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? (isDestructive
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface)
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurfaceVariant
                            .withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
