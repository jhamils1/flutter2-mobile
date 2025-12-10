import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final IconData? prefixIcon;
  final bool filled;
  final Color? fillColor;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.label,
    this.isPassword = false,
    this.prefixIcon,
    this.filled = false,
    this.fillColor,
    this.keyboardType,
    this.validator,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(fontWeight: isDark ? FontWeight.w700 : FontWeight.normal, color: isDark ? Colors.white70 : null);
    final inputStyle = TextStyle(fontWeight: isDark ? FontWeight.w700 : FontWeight.normal, color: isDark ? Colors.white : null);

    return TextFormField(
      controller: widget.controller,
      style: inputStyle,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: labelStyle,
        prefixIcon: widget.prefixIcon != null ? Icon(widget.prefixIcon, color: isDark ? Colors.white70 : Colors.deepPurple) : null,
        filled: widget.filled,
        fillColor: widget.fillColor ?? (widget.filled ? (isDark ? Colors.grey.shade800 : Colors.deepPurple.shade50) : null),
        border: widget.filled
            ? OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)
            : const OutlineInputBorder(),
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () {
                  setState(() {
                    _obscure = !_obscure;
                  });
                },
              )
            : null,
      ),
      obscureText: widget.isPassword ? _obscure : false,
      validator: widget.validator,
    );
  }
}
