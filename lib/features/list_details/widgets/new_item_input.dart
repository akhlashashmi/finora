import 'dart:math';

import 'package:finora/data/repository/expense_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:math_expressions/math_expressions.dart';

class NewItemInput extends ConsumerStatefulWidget {
  final String listId;
  final VoidCallback onAdded;
  final FocusNode focusNode;
  final VoidCallback onShowInfoScreen;

  const NewItemInput({
    super.key,
    required this.listId,
    required this.onAdded,
    required this.focusNode,
    required this.onShowInfoScreen,
  });

  @override
  ConsumerState<NewItemInput> createState() => _NewItemInputState();
}

class _NewItemInputState extends ConsumerState<NewItemInput> {
  final _controller = TextEditingController();
  bool _isNumericKeyboard = false;

  // Define the maximum allowed number (999,999,999,999).
  static const double _maxNumberLimit = 999999999999.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _evaluateOrParseNumber(String numberStr) {
    // First try natural language patterns
    final naturalResult = _evaluateNaturalLanguage(numberStr);
    if (naturalResult != null) {
      return naturalResult;
    }

    // Then try mathematical expressions
    final mathResult = _evaluateMathExpression(numberStr);
    if (mathResult != null) {
      return mathResult;
    }

    // Finally try simple number parsing
    return _parseNumber(numberStr);
  }

  double? _evaluateNaturalLanguage(String expression) {
    final cleaned = expression.toLowerCase().trim();

    // Pattern: "X% of Y" or "X percent of Y"
    final percentOfPattern = RegExp(r'(\d+(?:\.\d+)?)\s*(?:%|percent)\s+of\s+(\d+(?:\.\d+)?)');
    final percentMatch = percentOfPattern.firstMatch(cleaned);

    if (percentMatch != null) {
      final percentage = double.tryParse(percentMatch.group(1)!);
      final baseValue = double.tryParse(percentMatch.group(2)!);

      if (percentage != null && baseValue != null) {
        return (percentage / 100) * baseValue;
      }
    }

    // Pattern: "X% tip on Y"
    final tipPattern = RegExp(r'(\d+(?:\.\d+)?)\s*%\s+tip\s+on\s+(\d+(?:\.\d+)?)');
    final tipMatch = tipPattern.firstMatch(cleaned);

    if (tipMatch != null) {
      final tipPercent = double.tryParse(tipMatch.group(1)!);
      final baseAmount = double.tryParse(tipMatch.group(2)!);

      if (tipPercent != null && baseAmount != null) {
        return (tipPercent / 100) * baseAmount;
      }
    }

    // Pattern: "X% tax on Y"
    final taxPattern = RegExp(r'(\d+(?:\.\d+)?)\s*%\s+tax\s+on\s+(\d+(?:\.\d+)?)');
    final taxMatch = taxPattern.firstMatch(cleaned);

    if (taxMatch != null) {
      final taxPercent = double.tryParse(taxMatch.group(1)!);
      final baseAmount = double.tryParse(taxMatch.group(2)!);

      if (taxPercent != null && baseAmount != null) {
        return (taxPercent / 100) * baseAmount;
      }
    }

    return null;
  }

  ParsedInput _parseInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return ParsedInput();

    // Check if it's a natural language expression first
    final naturalResult = _evaluateNaturalLanguage(trimmed);
    if (naturalResult != null) {
      return ParsedInput(number: naturalResult, title: trimmed);
    }

    // Pattern for "title number" format (e.g., "Coffee 5.99")
    final endNumberMatch = RegExp(r'^(.*?)\s+([\d\.,\+\-\*\/\(\)%^]+|sqrt\(\d+(?:\.\d+)?\))$').firstMatch(trimmed);

    if (endNumberMatch != null) {
      final title = endNumberMatch.group(1)?.trim();
      final numberPart = endNumberMatch.group(2)!;
      final number = _evaluateOrParseNumber(numberPart);

      if (number != null) {
        return ParsedInput(
          number: number,
          title: title?.isNotEmpty == true ? title : null,
        );
      }
    }

    // Pattern for "number title" format (e.g., "25.50 Grocery")
    final startNumberMatch = RegExp(r'^([\d\.,\+\-\*\/\(\)%^]+|sqrt\(\d+(?:\.\d+)?\))\s+(.*?)$').firstMatch(trimmed);

    if (startNumberMatch != null) {
      final numberPart = startNumberMatch.group(1)!;
      final title = startNumberMatch.group(2)?.trim();
      final number = _evaluateOrParseNumber(numberPart);

      if (number != null) {
        return ParsedInput(
          number: number,
          title: title?.isNotEmpty == true ? title : null,
        );
      }
    }

    // Try to parse as just a number or expression
    final onlyNumber = _evaluateOrParseNumber(trimmed);
    if (onlyNumber != null) {
      return ParsedInput(number: onlyNumber);
    }

    // If nothing else works, treat as title only
    return ParsedInput(title: trimmed);
  }

  double? _evaluateMathExpression(String expression) {
    try {
      String preparedExpression = expression
          .replaceAll(',', '')
          .replaceAll(' ', '')
          .replaceAll('**', '^') // Handle ** as power operator
          .toLowerCase();

      if (preparedExpression.isEmpty) return null;

      // Handle square root function
      if (preparedExpression.contains('sqrt(')) {
        final sqrtPattern = RegExp(r'sqrt\((\d+(?:\.\d+)?)\)');
        preparedExpression = preparedExpression.replaceAllMapped(sqrtPattern, (match) {
          final value = double.tryParse(match.group(1)!);
          if (value != null && value >= 0) {
            return sqrt(value).toString();
          }
          return match.group(0)!;
        });
      }

      // Handle percentage symbol within expressions
      preparedExpression = preparedExpression.replaceAllMapped(RegExp(r'(\d+(?:\.\d+)?)%'), (match) {
        final value = double.tryParse(match.group(1)!);
        return (value != null) ? '(${value / 100})' : match.group(0)!;
      });

      Parser p = Parser();
      Expression exp = p.parse(preparedExpression);
      ContextModel cm = ContextModel();

      final result = exp.evaluate(EvaluationType.REAL, cm);
      if (result is double && result.isFinite) {
        return result;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  double? _parseNumber(String numberStr) {
    try {
      final cleaned = numberStr.replaceAll(',', '').trim();

      // Handle percentages
      if (cleaned.endsWith('%')) {
        final value = double.tryParse(cleaned.substring(0, cleaned.length - 1));
        return value != null ? value / 100 : null;
      }

      // Handle scientific notation
      if (cleaned.contains('e') || cleaned.contains('E')) {
        return double.tryParse(cleaned);
      }

      // Handle fractions
      if (cleaned.contains('/') && !cleaned.contains('(')) {
        final parts = cleaned.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]);
          final denominator = double.tryParse(parts[1]);
          if (numerator != null && denominator != null && denominator != 0) {
            return numerator / denominator;
          }
        }
      }

      // Handle square root
      if (cleaned.startsWith('sqrt(') && cleaned.endsWith(')')) {
        final value = double.tryParse(cleaned.substring(5, cleaned.length - 1));
        if (value != null && value >= 0) {
          return sqrt(value);
        }
      }

      // Regular number parsing
      return double.tryParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Helper function to perform validation before adding.
    void addValidatedCheck(double number, String? title) {
      if (number.abs() > _maxNumberLimit) {
        // Show an error message if the number is too large.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Number cannot exceed 999 billion.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return; // Stop execution.
      }

      // If validation passes, add the item.
      ref.read(expenseRepositoryProvider).addCheck(
        listId: widget.listId,
        number: number,
        title: title,
      );
      _controller.clear();
      widget.onAdded();
    }

    // Check for natural language patterns first.
    final naturalResult = _evaluateNaturalLanguage(trimmed);
    if (naturalResult != null) {
      addValidatedCheck(naturalResult, trimmed);
      return;
    }

    // Check for mathematical expressions.
    final mathResult = _evaluateMathExpression(trimmed);
    final containsOperator = RegExp(r'[+\-*/]|\bsqrt\b|%').hasMatch(trimmed);

    if (mathResult != null && containsOperator && mathResult.toString() != trimmed) {
      addValidatedCheck(mathResult, trimmed);
      return;
    }

    // Fall back to regular parsing.
    final parsed = _parseInput(trimmed);
    if (parsed.isValid) {
      addValidatedCheck(parsed.number ?? 0.0, parsed.title);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      keyboardType: _isNumericKeyboard
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      textInputAction: TextInputAction.done,
      style: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        border: InputBorder.none,
        focusedBorder: InputBorder.none,
        prefixIcon: Icon(Icons.add_rounded,),
        suffixIcon: IconButton(
          icon: Icon(
            _isNumericKeyboard ? Icons.abc : Icons.dialpad,
            color: theme.colorScheme.onSurface.withValues(alpha:0.6),
            size: 22,
          ),
          onPressed: () {
            setState(() {
              _isNumericKeyboard = !_isNumericKeyboard;
            });
            widget.focusNode.unfocus();
            Future.delayed(
              const Duration(milliseconds: 50),
                  () => widget.focusNode.requestFocus(),
            );
          },
          tooltip: _isNumericKeyboard
              ? 'Switch to text keyboard' :
              'Switch to number pad',
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        hintText: '4.99 Coffee | 15% of 45 | 15% tip on 45',
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha:0.4),
          fontSize: 14,
        ),
      ),
      onSubmitted: _submit,
    );
  }
}

/// Data class to hold parsed input results.
class ParsedInput {
  final double? number;
  final String? title;

  ParsedInput({this.number, this.title});

  bool get isValid => number != null || title != null;
}