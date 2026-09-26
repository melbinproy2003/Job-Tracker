import 'package:flutter/material.dart';

class ApplicationSearchBar extends StatelessWidget {
  const ApplicationSearchBar({
    super.key,
    required this.onChanged,
    this.initialValue = '',
  });

  final ValueChanged<String> onChanged;
  final String initialValue;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: initialValue)
        ..selection = TextSelection.collapsed(offset: initialValue.length),
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search company, role, location',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
