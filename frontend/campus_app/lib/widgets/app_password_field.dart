import 'package:flutter/material.dart';

class AppPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? Function(String?)? validator;
  final bool lightStyle;
  final TextInputAction? textInputAction;
  final void Function(String)? onSubmitted;

  const AppPasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.lightStyle = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<AppPasswordField> createState() => _AppPasswordFieldState();
}

class _AppPasswordFieldState extends State<AppPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final labelStyle = widget.lightStyle
        ? const TextStyle(color: Colors.white70)
        : null;
    final textStyle =
        widget.lightStyle ? const TextStyle(color: Colors.white) : null;

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      style: textStyle,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        labelStyle: labelStyle,
        hintStyle: labelStyle,
        prefixIcon: Icon(
          Icons.lock_outline,
          color: widget.lightStyle ? Colors.white70 : null,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: widget.lightStyle ? Colors.white70 : null,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        enabledBorder: widget.lightStyle
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white54),
              )
            : null,
        focusedBorder: widget.lightStyle
            ? OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.white),
              )
            : null,
        filled: widget.lightStyle,
        fillColor: widget.lightStyle
            ? Colors.white.withValues(alpha: 0.12)
            : null,
      ),
    );
  }
}
