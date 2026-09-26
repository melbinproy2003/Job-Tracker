import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/companies_providers.dart';

class AddEditCompanyScreen extends ConsumerStatefulWidget {
  const AddEditCompanyScreen({super.key, this.companyId});

  final String? companyId;

  bool get isEditing => companyId != null;

  @override
  ConsumerState<AddEditCompanyScreen> createState() =>
      _AddEditCompanyScreenState();
}

class _AddEditCompanyScreenState extends ConsumerState<AddEditCompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _industryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _loading = false;
  bool _bootstrapped = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _websiteCtrl.dispose();
    _locationCtrl.dispose();
    _industryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (!widget.isEditing || _bootstrapped) return;
    _bootstrapped = true;
    final company = await ref
        .read(companyRepositoryProvider)
        .getById(widget.companyId!);
    if (!mounted) return;
    setState(() {
      _nameCtrl.text = company.name;
      _websiteCtrl.text = company.website ?? '';
      _locationCtrl.text = company.location ?? '';
      _industryCtrl.text = company.industry ?? '';
      _notesCtrl.text = company.notes ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      _bootstrap();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Company' : 'Add Company'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Company name *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _websiteCtrl,
              decoration: const InputDecoration(labelText: 'Website'),
            ),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            TextFormField(
              controller: _industryCtrl,
              decoration: const InputDecoration(labelText: 'Industry'),
            ),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isEditing ? 'Save changes' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final body = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'website': _websiteCtrl.text.trim().isEmpty
          ? null
          : _websiteCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      'industry': _industryCtrl.text.trim().isEmpty
          ? null
          : _industryCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final repo = ref.read(companyRepositoryProvider);
      if (widget.isEditing) {
        await repo.update(widget.companyId!, body);
      } else {
        await repo.create(body);
      }
      ref.invalidate(companiesListProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        final message =
            e.toString().contains('DUPLICATE') ||
                e.toString().toLowerCase().contains('already exists')
            ? 'A company with this name already exists.'
            : 'Failed to save company.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
