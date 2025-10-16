/// PHASE 2: SKELETON CODE - Smart Forms
///
/// PURPOSE:
/// - Autosaving forms with debouncing
/// - Inline validation with user-friendly errors
/// - Input formatters (currency, phone, percentage)
/// - Field dependencies (show/hide based on other fields)
/// - Progress tracking (X of Y fields complete)
/// - Draft restoration on navigation

library smart_form;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum FieldType {
  text,
  email,
  phone,
  currency,
  percentage,
  number,
  date,
  time,
  dropdown,
}

enum ValidationTrigger {
  onChange, // Validate on every change
  onBlur, // Validate when field loses focus
  onSubmit, // Validate only on form submit
}

// ============================================================================
// SMART FORM FIELD
// ============================================================================

class SmartFormField {
  final String id;
  final String label;
  final FieldType type;
  final String? initialValue;
  final bool required;
  final List<String? Function(String?)> validators;
  final ValidationTrigger validationTrigger;
  final String? helpText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final List<String>? dependsOn;
  final bool Function(Map<String, String>)? visibilityCondition;

  const SmartFormField({
    required this.id,
    required this.label,
    required this.type,
    this.initialValue,
    this.required = false,
    this.validators = const [],
    this.validationTrigger = ValidationTrigger.onBlur,
    this.helpText,
    this.prefixIcon,
    this.suffixIcon,
    this.dependsOn,
    this.visibilityCondition,
  });

  /// Get input formatter based on field type
  List<TextInputFormatter> getFormatters() {
    switch (type) {
      case FieldType.phone:
        return [PhoneFormatter()];
      case FieldType.currency:
        return [CurrencyFormatter()];
      case FieldType.percentage:
        return [PercentageFormatter()];
      case FieldType.number:
        return [FilteringTextInputFormatter.digitsOnly];
      default:
        return [];
    }
  }

  /// Get keyboard type based on field type
  TextInputType getKeyboardType() {
    switch (type) {
      case FieldType.email:
        return TextInputType.emailAddress;
      case FieldType.phone:
        return TextInputType.phone;
      case FieldType.currency:
      case FieldType.percentage:
      case FieldType.number:
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
  }
}

// ============================================================================
// SMART FORM STATE
// ============================================================================

class SmartFormState {
  final Map<String, String> values;
  final Map<String, String?> errors;
  final Set<String> touchedFields;
  final bool isDirty;
  final bool isValid;
  final DateTime? lastSaved;

  const SmartFormState({
    this.values = const {},
    this.errors = const {},
    this.touchedFields = const {},
    this.isDirty = false,
    this.isValid = true,
    this.lastSaved,
  });

  SmartFormState copyWith({
    Map<String, String>? values,
    Map<String, String?>? errors,
    Set<String>? touchedFields,
    bool? isDirty,
    bool? isValid,
    DateTime? lastSaved,
  }) {
    return SmartFormState(
      values: values ?? this.values,
      errors: errors ?? this.errors,
      touchedFields: touchedFields ?? this.touchedFields,
      isDirty: isDirty ?? this.isDirty,
      isValid: isValid ?? this.isValid,
      lastSaved: lastSaved ?? this.lastSaved,
    );
  }

  int get completedFieldCount => values.length;
}

// ============================================================================
// MAIN SMART FORM WIDGET
// ============================================================================

class SmartForm extends StatefulWidget {
  final List<SmartFormField> fields;
  final Future<void> Function(Map<String, String>) onSave;
  final Duration autosaveDelay;
  final bool showProgress;
  final VoidCallback? onCancel;

  const SmartForm({
    super.key,
    required this.fields,
    required this.onSave,
    this.autosaveDelay = const Duration(seconds: 2),
    this.showProgress = true,
    this.onCancel,
  });

  @override
  State<SmartForm> createState() => _SmartFormState();
}

class _SmartFormState extends State<SmartForm> {
  late SmartFormState _formState;
  Timer? _autosaveTimer;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // TODO(Phase 3): Load draft from local storage
    _formState = SmartFormState(
      values: Map.fromEntries(
        widget.fields
            .where((f) => f.initialValue != null)
            .map((f) => MapEntry(f.id, f.initialValue!)),
      ),
    );

    // Initialize controllers and focus nodes
    for (final field in widget.fields) {
      _controllers[field.id] = TextEditingController(text: field.initialValue);
      _focusNodes[field.id] = FocusNode();

      // Set up focus listener for onBlur validation
      _focusNodes[field.id]!.addListener(() {
        if (!_focusNodes[field.id]!.hasFocus) {
          _onFieldBlur(field);
        }
      });
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showProgress) _buildProgressIndicator(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.fields.length,
            itemBuilder: (context, index) {
              final field = widget.fields[index];

              // Check visibility condition
              if (field.visibilityCondition != null &&
                  !field.visibilityCondition!(_formState.values)) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildField(field),
              );
            },
          ),
        ),
        _buildActionButtons(),
        if (_formState.lastSaved != null) _buildLastSavedIndicator(),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    final totalFields = widget.fields.length;
    final completedFields = _formState.completedFieldCount;
    final progress = completedFields / totalFields;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress: $completedFields of $totalFields fields',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }

  Widget _buildField(SmartFormField field) {
    final controller = _controllers[field.id]!;
    final focusNode = _focusNodes[field.id]!;
    final error = _formState.errors[field.id];

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helpText,
        errorText: error,
        prefixIcon: field.prefixIcon,
        suffixIcon: field.suffixIcon,
        border: const OutlineInputBorder(),
      ),
      keyboardType: field.getKeyboardType(),
      inputFormatters: field.getFormatters(),
      onChanged: (value) => _onFieldChanged(field, value),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (widget.onCancel != null)
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
          if (widget.onCancel != null) const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              onPressed: _isSaving ? null : _onSubmit,
              child: _isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastSavedIndicator() {
    final lastSaved = _formState.lastSaved!;
    final now = DateTime.now();
    final diff = now.difference(lastSaved);

    String timeAgo;
    if (diff.inSeconds < 60) {
      timeAgo = 'just now';
    } else if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else {
      timeAgo = '${diff.inHours}h ago';
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Last saved: $timeAgo',
        style: Theme.of(context).textTheme.bodySmall,
        textAlign: TextAlign.center,
      ),
    );
  }

  void _onFieldChanged(SmartFormField field, String value) {
    // Update form state
    final updatedValues = Map<String, String>.from(_formState.values);
    updatedValues[field.id] = value;

    final updatedTouched = Set<String>.from(_formState.touchedFields)..add(field.id);

    setState(() {
      _formState = _formState.copyWith(
        values: updatedValues,
        touchedFields: updatedTouched,
        isDirty: true,
      );
    });

    // Validate on change if configured
    if (field.validationTrigger == ValidationTrigger.onChange) {
      _validateField(field);
    }

    // Trigger autosave
    _scheduleAutosave();

    // TODO(Phase 3): Track field changes in UX telemetry
  }

  void _onFieldBlur(SmartFormField field) {
    // Validate on blur if configured
    if (field.validationTrigger == ValidationTrigger.onBlur) {
      _validateField(field);
    }
  }

  void _validateField(SmartFormField field) {
    final value = _formState.values[field.id];

    // Run validators
    String? error;
    for (final validator in field.validators) {
      error = validator(value);
      if (error != null) break;
    }

    // Update errors
    final updatedErrors = Map<String, String?>.from(_formState.errors);
    updatedErrors[field.id] = error;

    setState(() {
      _formState = _formState.copyWith(errors: updatedErrors);
    });
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(widget.autosaveDelay, _performAutosave);
  }

  Future<void> _performAutosave() async {
    if (!_formState.isDirty) return;

    // TODO(Phase 3): Save draft to local storage
    // TODO(Phase 3): Call onSave callback
    try {
      await widget.onSave(_formState.values);

      setState(() {
        _formState = _formState.copyWith(
          lastSaved: DateTime.now(),
          isDirty: false,
        );
      });
    } catch (e) {
      // TODO(Phase 3): Show error snackbar
      debugPrint('Autosave failed: $e');
    }
  }

  Future<void> _onSubmit() async {
    // Validate all fields
    for (final field in widget.fields) {
      _validateField(field);
    }

    // Check if form is valid
    final hasErrors = _formState.errors.values.any((error) => error != null);
    if (hasErrors) {
      // TODO(Phase 3): Show error message
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSave(_formState.values);

      // TODO(Phase 3): Show success message
      // TODO(Phase 3): Navigate back or clear form
    } catch (e) {
      // TODO(Phase 3): Show error message
      debugPrint('Form submission failed: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
}

// ============================================================================
// INPUT FORMATTERS
// ============================================================================

class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // TODO(Phase 3): Implement E.164 phone formatting
    // Example: +1 (555) 123-4567
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');

    if (digitsOnly.length <= 10) {
      return newValue;
    }

    return oldValue;
  }
}

class CurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // TODO(Phase 3): Implement currency formatting
    // Example: $1,234.56
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');

    // Only allow one decimal point
    final parts = digitsOnly.split('.');
    if (parts.length > 2) {
      return oldValue;
    }

    return newValue;
  }
}

class PercentageFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // TODO(Phase 3): Implement percentage formatting
    // Example: 12.5%
    final numericValue = double.tryParse(newValue.text.replaceAll('%', ''));

    if (numericValue != null && (numericValue < 0 || numericValue > 100)) {
      return oldValue;
    }

    return newValue;
  }
}

// ============================================================================
// COMMON VALIDATORS
// ============================================================================

class Validators {
  Validators._();

  static String? Function(String?) required(String message) {
    return (value) {
      if (value == null || value.isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? Function(String?) email(String message) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(value)) {
        return message;
      }
      return null;
    };
  }

  static String? Function(String?) minLength(int length, String message) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (value.length < length) {
        return message;
      }
      return null;
    };
  }

  static String? Function(String?) maxLength(int length, String message) {
    return (value) {
      if (value == null || value.isEmpty) return null;

      if (value.length > length) {
        return message;
      }
      return null;
    };
  }
}
