import 'package:flutter/material.dart';

/// A text field with the app's decoration already applied.
///
/// Every property it does not name comes from `InputDecorationTheme`, so a
/// field cannot drift from the rest of the app by forgetting one. The old
/// input widget restated fill, radius, border and focus colour at the widget
/// level, which is why a theme change used to leave fields behind.
class LockoutField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;

  /// The unit shown inside the field — `kg`, `cm`, `reps`.
  final String? suffix;

  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const LockoutField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.suffix,
    this.maxLines = 1,
    this.onChanged,
    this.validator,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      autofocus: autofocus,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
      ),
    );
  }
}
