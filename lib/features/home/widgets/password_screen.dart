import 'package:finora/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Defines the purpose of the PIN entry screen.
enum PinEntryMode {
  /// To verify an existing PIN for a list.
  verify,

  /// To create a new 6-digit PIN.
  create,
}

class PinEntryScreen extends ConsumerStatefulWidget {
  final VoidCallback? onVerified;
  final Function(String)? onPinCreated;
  final PinEntryMode mode;
  final String? title;
  final String? subtitle;

  const PinEntryScreen({
    super.key,
    required this.mode,
    this.onVerified,
    this.onPinCreated,
    this.title,
    this.subtitle,
  }) : assert(
  (mode == PinEntryMode.verify && onVerified != null) ||
      (mode == PinEntryMode.create && onPinCreated != null),
  'Correct parameters must be provided for the selected PinEntryMode',
  );

  @override
  ConsumerState<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends ConsumerState<PinEntryScreen>
    with TickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  bool _isError = false;
  String _errorMessage = '';

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_isLoading) return;
    setState(() => _isError = false); // Reset error on new input

    if (widget.mode == PinEntryMode.create) {
      if (!_isConfirming && _pin.length < 6) {
        setState(() => _pin += digit);
        if (_pin.length == 6) {
          // Add a small delay for a smoother transition to confirmation step
          Future.delayed(
              const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _isConfirming = true);
          });
        }
      } else if (_isConfirming && _confirmPin.length < 6) {
        setState(() => _confirmPin += digit);
        if (_confirmPin.length == 6) {
          _validateAndCreatePin();
        }
      }
    } else { // Verify mode
      if (_pin.length < 6) {
        setState(() => _pin += digit);
        if (_pin.length == 6) {
          _verifyPin();
        }
      }
    }
    HapticFeedback.lightImpact();
  }

  void _removeDigit() {
    if (_isLoading) return;
    setState(() => _isError = false);

    if (widget.mode == PinEntryMode.create && _isConfirming) {
      if (_confirmPin.isNotEmpty) {
        setState(() =>
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1));
      }
    } else if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
    HapticFeedback.lightImpact();
  }

  Future<void> _validateAndCreatePin() async {
    if (_pin == _confirmPin) {
      HapticFeedback.heavyImpact();
      setState(() => _isLoading = true);
      await ref.read(passwordServiceProvider).setPassword(_pin);
      if (mounted) {
        widget.onPinCreated!(_pin);
        Navigator.of(context).pop();
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _isError = true;
        _errorMessage = "PINs don't match. Please try again.";
        _pin = '';
        _confirmPin = '';
        _isConfirming = false;
      });
      _shakeController.forward(from: 0);
    }
  }

  Future<void> _verifyPin() async {
    setState(() => _isLoading = true);

    final isValid = await ref.read(passwordServiceProvider).verifyPassword(_pin);

    if (mounted) {
      if (isValid) {
        HapticFeedback.heavyImpact();
        Navigator.of(context).pop();
        widget.onVerified!();
      } else {
        HapticFeedback.heavyImpact();
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Incorrect PIN. Try again.';
          _pin = '';
        });
        _shakeController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String currentPin = _isConfirming ? _confirmPin : _pin;
    String title, subtitle;

    if (widget.mode == PinEntryMode.create) {
      title = widget.title ?? (_isConfirming ? 'Confirm PIN' : 'Set a PIN');
      subtitle = widget.subtitle ?? (_isConfirming
          ? 'Enter your PIN again to confirm'
          : 'Create a 6-digit PIN for the app');
    } else {
      title = widget.title ?? 'Enter PIN';
      subtitle = widget.subtitle ?? 'Enter your 6-digit PIN to continue';
    }

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  color: colorScheme.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: theme.textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              AnimatedBuilder(
                animation: _shakeController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_shakeAnimation.value, 0),
                    child: child,
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    final isActive = index < currentPin.length;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? colorScheme.error
                            : isActive
                            ? colorScheme.primary
                            : colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(
                height: 32,
                child: _isError
                    ? Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: colorScheme.error),
                  ),
                )
                    : null,
              ),
              const Spacer(),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                _buildNumberPad(theme),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
          ['1', '2', '3'].map((n) => _buildNumberButton(n, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
          ['4', '5', '6'].map((n) => _buildNumberButton(n, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children:
          ['7', '8', '9'].map((n) => _buildNumberButton(n, theme)).toList(),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Spacer to align 0 in the center
            const SizedBox(width: 72),
            _buildNumberButton('0', theme),
            _buildBackspaceButton(theme),
          ],
        ),
      ],
    );
  }

  Widget _buildNumberButton(String number, ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _addDigit(number),
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              number,
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(ThemeData theme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _removeDigit,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Icon(
              Icons.backspace_outlined,
              color: theme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}