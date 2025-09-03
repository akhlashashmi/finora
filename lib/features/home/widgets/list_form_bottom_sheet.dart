import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/home/widgets/password_screen.dart';
import 'package:finora/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ListFormBottomSheet extends ConsumerStatefulWidget {
  final ListPage? listPage; // null for creating new, non-null for editing

  const ListFormBottomSheet({super.key, this.listPage});

  @override
  ConsumerState<ListFormBottomSheet> createState() =>
      _ListFormBottomSheetState();
}

class _ListFormBottomSheetState extends ConsumerState<ListFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;
  bool _isLoading = false;
  late bool _isProtected;

  bool get _isEditing => widget.listPage != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.listPage?.name ?? '');
    _budgetController = TextEditingController(
      text: widget.listPage?.budget != null && widget.listPage!.budget > 0
          ? widget.listPage!.budget.toString()
          : '',
    );
    _isProtected = widget.listPage?.isProtected ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _handleProtectionToggle(bool value) async {
    final passwordService = ref.read(passwordServiceProvider);

    if (value) {
      // User wants to enable protection
      final isPasswordSet = await passwordService.isPasswordSet();

      if (isPasswordSet) {
        // Password already exists, just enable protection
        setState(() => _isProtected = true);
      } else {
        // Need to create a password first
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinEntryScreen(
              mode: PinEntryMode.create,
              title: 'Create App PIN',
              subtitle: 'This PIN will be used for all protected lists.',
              onPinCreated: (pin) {
                setState(() => _isProtected = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('App PIN created. list will be protected.'),
                  ),
                );
              },
            ),
          ),
        );
      }
    } else {
      // User wants to disable protection - always require PIN verification
      final isPasswordSet = await passwordService.isPasswordSet();
      if (!isPasswordSet) {
        // No PIN set, just disable
        setState(() => _isProtected = false);
        return;
      }

      // Verify PIN before disabling protection
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinEntryScreen(
            mode: PinEntryMode.verify,
            title: 'Enter PIN',
            subtitle: 'Verify your PIN to disable protection',
            onVerified: () {
              setState(() => _isProtected = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Protection disabled for this list.'),
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final name = _nameController.text.trim();
      final budget = double.tryParse(_budgetController.text) ?? 0.0;

      if (_isEditing) {
        final updatedListPage = widget.listPage!.copyWith(
          name: name,
          budget: budget,
          isProtected: _isProtected,
        );
        await ref
            .read(expenseRepositoryProvider)
            .updateListPage(updatedListPage);
      } else {
        await ref
            .read(expenseRepositoryProvider)
            .addListPage(name, budget: budget, isProtected: _isProtected);
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + keyboardPadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha:0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Container(
                  //   padding: const EdgeInsets.all(12),
                  //   decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(16)),
                  //   child: Icon(_isEditing ? Icons.edit_rounded : Icons.add_rounded, color: colorScheme.primary, size: 24),
                  // ),
                  // const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit List' : 'New List',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _isEditing
                              ? 'Modify list details'
                              : 'Create a new list',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('List Name', Icons.label_outline),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Enter list name',
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withValues(alpha:0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Please enter a list name'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    _buildSectionHeader(
                      'Budget (Optional)',
                      Icons.account_balance_wallet_outlined,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _budgetController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: '0.00',
                        // prefixText: '\$ ',
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withValues(alpha:0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildProtectionToggle(theme, colorScheme),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Text(_isEditing ? 'Save Changes' : 'Create List'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProtectionToggle(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withValues(alpha:0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              // decoration: BoxDecoration(
              //   color: _isProtected
              //       ? colorScheme.primaryContainer
              //       : colorScheme.surfaceVariant.withValues(alpha:0.5),
              //   borderRadius: BorderRadius.circular(8),
              // ),
              child: Icon(
                _isProtected ? Icons.shield_rounded : Icons.shield_outlined,
                color: _isProtected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password Protection',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Require PIN to access',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: _isProtected,
              onChanged: _handleProtectionToggle,
              activeColor: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
