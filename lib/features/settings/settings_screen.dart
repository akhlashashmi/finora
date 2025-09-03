import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/home/widgets/password_screen.dart';
import 'package:finora/features/list_details/help_screen.dart';
import 'package:finora/features/settings/backup_service.dart';
import 'package:finora/core/widgets/custom_divider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _appPasswordKey = 'app_password_hash';

final passwordServiceProvider = Provider<PasswordService>((ref) {
  return PasswordService();
});

class PasswordService {
  String? _hashPassword(String password) {
    if (password.isEmpty) return null;
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = _hashPassword(password);
    if (hash != null) {
      await prefs.setString(_appPasswordKey, hash);
    }
  }

  Future<bool> verifyPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_appPasswordKey);
    if (storedHash == null) return false;
    return storedHash == _hashPassword(password);
  }

  Future<bool> isPasswordSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_appPasswordKey);
  }

  Future<void> removePassword() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_appPasswordKey);
  }
}

// Settings Screen

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  void _onChangePin() async {
    final passwordService = ref.read(passwordServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (await passwordService.isPasswordSet()) {
      // Must verify old pin first
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PinEntryScreen(
            mode: PinEntryMode.verify,
            title: 'Enter Old PIN',
            subtitle: 'Verify your current PIN to continue',
            onVerified: () {
              // Now, show create screen for new PIN
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PinEntryScreen(
                    mode: PinEntryMode.create,
                    title: 'Create New PIN',
                    subtitle: 'Enter your new 6-digit PIN',
                    onPinCreated: (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('PIN changed successfully.'),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      // No pin set, just create one
      navigator.push(
        MaterialPageRoute(
          builder: (_) => PinEntryScreen(
            mode: PinEntryMode.create,
            title: 'Create App PIN',
            subtitle: 'Set a 6-digit PIN to secure your list',
            onPinCreated: (_) {
              messenger.showSnackBar(
                const SnackBar(content: Text('App PIN created successfully.')),
              );
            },
          ),
        ),
      );
    }
  }

  void _onRemovePin() async {
    final passwordService = ref.read(passwordServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!await passwordService.isPasswordSet()) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No App PIN is currently set.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove App PIN?'),
        content: const Text(
          'This action is irreversible and will remove protection from all of your currently protected Lists.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove PIN'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => PinEntryScreen(
          mode: PinEntryMode.verify,
          title: 'Enter PIN to Confirm',
          subtitle: 'Verify your PIN to remove it permanently',
          onVerified: () async {
            await passwordService.removePassword();
            await ref.read(expenseRepositoryProvider).unprotectAllLists();
            messenger.showSnackBar(
              const SnackBar(
                content: Text(
                  'App PIN removed. All lists are now unprotected.',
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final backupService = ref.watch(backupServiceProvider);
    final backupState = ref.watch(backupStateNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 0.5,
            surfaceTintColor: theme.colorScheme.surfaceTint.withValues(
              alpha: 0.1,
            ),
            backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.95),
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
              style: IconButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            title: Text(
              'Settings & Backup',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Local Backup Section
                _SectionHeader(
                  title: 'Local Backup',
                  description: 'Export or import data from local files',
                  icon: Icons.storage_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.download_for_offline_outlined,
                  title: 'Export to File',
                  subtitle: 'Save a JSON backup to your device',
                  onTap: () async {
                    try {
                      final backup = await backupService.createBackupModel();
                      final jsonString = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(backup.toJson());

                      String? directoryPath = await FilePicker.platform
                          .getDirectoryPath();
                      if (directoryPath == null) return;

                      final fileName =
                          'finora_backup_${DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now())}.json';
                      final file = File('$directoryPath/$fileName');
                      await file.writeAsString(jsonString);

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Backup saved to: $directoryPath/$fileName',
                          ),
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
                _SettingsTile(
                  icon: Icons.upload_file_outlined,
                  title: 'Import from File',
                  subtitle: 'Restore data from a local JSON file',
                  onTap: () async {
                    FilePickerResult? result = await FilePicker.platform
                        .pickFiles();
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

                const SizedBox(height: 24),
                // Security Section
                _SectionHeader(
                  title: 'Security',
                  description: 'Manage your application PIN',
                  icon: Icons.security_rounded,
                  color: theme.colorScheme.secondary,
                ),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.password_rounded,
                  title: 'Change PIN',
                  subtitle: 'Update your 6-digit application PIN',
                  onTap: _onChangePin,
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'Remove PIN',
                  subtitle: 'This will unprotect all your lists',
                  onTap: _onRemovePin,
                  isDestructive: true,
                ),

                const SizedBox(height: 24),
                // Cloud Backup Section
                _SectionHeader(
                  title: 'Cloud Backup',
                  description: backupState.user != null
                      ? 'Signed in as ${backupState.user!.email}'
                      : 'Sign in to sync with the cloud',
                  icon: Icons.cloud_outlined,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(height: 12),

                if (backupState.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (!backupState.isLoading) ...[
                  if (backupState.user == null)
                    _SettingsTile(
                      icon: Icons.login,
                      title: 'Sign in with Google',
                      subtitle: 'Required for cloud backup & restore',
                      onTap: () => ref
                          .read(backupStateNotifierProvider.notifier)
                          .signIn(),
                    ),

                  if (backupState.user != null) ...[
                    _SettingsTile(
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
                    _SettingsTile(
                      icon: Icons.cloud_upload_outlined,
                      title: 'Backup to Cloud',
                      subtitle: 'Save your data to Google Drive',
                      onTap: () => ref
                          .read(backupStateNotifierProvider.notifier)
                          .backupToCloud(),
                    ),
                    const SizedBox(height: 8),
                    _SettingsTile(
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: theme.colorScheme.onErrorContainer,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Error: ${backupState.error}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // NEW SECTION START
                const SizedBox(height: 24),
                // About Section
                _SectionHeader(
                  title: 'About',
                  description: 'Guides, policies, and licenses',
                  icon: Icons.info_outline_rounded,
                  color: Colors.teal,
                ),
                const SizedBox(height: 12),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Quick Guide',
                  subtitle: 'Learn how to use the app\'s features',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HelpScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'Read our data handling practices',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Privacy Policy'),
                        content: const SingleChildScrollView(
                          child: Text(
                            'Your data is stored locally on your device. If you use the Cloud Backup feature, your data is securely stored in a private folder within your own Google Drive account, accessible only by this app. We do not collect or have access to any of your personal financial data.\n\nThis is a placeholder policy. A full privacy policy will be available here upon release.',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Open Source Licenses',
                  subtitle: 'View licenses for packages used in the app',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'Finora',
                      applicationVersion: '1.0.0',
                    );
                  },
                ),
                // NEW SECTION END
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// Clean section header widget
class _SectionHeader extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
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
                  color: theme.colorScheme.onSurface,
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
    );
  }
}

// Clean settings tile widget
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsTile({
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isEnabled
                    ? (isDestructive
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isEnabled
                            ? (isDestructive
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.onSurface)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isEnabled
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.5,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isEnabled)
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.6,
                  ),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
