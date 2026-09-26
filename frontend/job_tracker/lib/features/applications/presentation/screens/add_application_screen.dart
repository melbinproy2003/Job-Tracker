import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/enums/application_status.dart';
import '../../../companies/domain/entities/company.dart';
import '../../../companies/providers/companies_providers.dart';
import '../../providers/applications_providers.dart';
import '../controllers/applications_controller.dart';

class AddEditApplicationScreen extends ConsumerStatefulWidget {
  const AddEditApplicationScreen({super.key, this.applicationId});

  final String? applicationId;

  bool get isEditing => applicationId != null;

  @override
  ConsumerState<AddEditApplicationScreen> createState() =>
      _AddEditApplicationScreenState();
}

class _AddEditApplicationScreenState
    extends ConsumerState<AddEditApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  Company? _company;
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _recruiterNameCtrl = TextEditingController();
  final _recruiterEmailCtrl = TextEditingController();
  final _salaryMinCtrl = TextEditingController();
  final _salaryMaxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _source = 'LinkedIn';
  String? _employmentType = 'Full-time';
  ApplicationStatus _status = ApplicationStatus.applied;
  DateTime _appliedAt = DateTime.now();
  String _currency = 'INR';
  bool _loading = false;
  bool _bootstrapped = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _locationCtrl.dispose();
    _recruiterNameCtrl.dispose();
    _recruiterEmailCtrl.dispose();
    _salaryMinCtrl.dispose();
    _salaryMaxCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapEdit() async {
    if (!widget.isEditing || _bootstrapped) return;
    _bootstrapped = true;
    final app = await ref
        .read(applicationRepositoryProvider)
        .getApplication(widget.applicationId!);
    final companies = await ref.read(companyRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _company = companies.cast<Company?>().firstWhere(
        (c) => c?.id == app.company.id,
        orElse: () => Company(id: app.company.id, name: app.company.name),
      );
      _titleCtrl.text = app.jobTitle;
      _urlCtrl.text = app.jobUrl ?? '';
      _locationCtrl.text = app.location ?? '';
      _source = app.source ?? 'Other';
      _employmentType = app.employmentType ?? 'Other';
      _status = app.status;
      _appliedAt = app.appliedAt ?? DateTime.now();
      _recruiterNameCtrl.text = app.recruiterName ?? '';
      _recruiterEmailCtrl.text = app.recruiterEmail ?? '';
      _salaryMinCtrl.text = app.salaryMin?.toString() ?? '';
      _salaryMaxCtrl.text = app.salaryMax?.toString() ?? '';
      _currency = app.currency ?? 'INR';
      _notesCtrl.text = app.notes ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      _bootstrapEdit();
    }
    final companiesAsync = ref.watch(companiesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Application' : 'Add Application'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            companiesAsync.when(
              data: (companies) => DropdownButtonFormField<String>(
                value: _company?.id,
                decoration: const InputDecoration(labelText: 'Company *'),
                items: [
                  for (final c in companies)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (id) {
                  setState(() {
                    _company = companies.firstWhere((c) => c.id == id);
                  });
                },
                validator: (v) => v == null ? 'Company is required' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (error, stackTrace) =>
                  const Text('Unable to load companies'),
            ),
            TextButton(
              onPressed: () async {
                await context.push(RouteNames.addCompany);
                ref.invalidate(companiesListProvider);
              },
              child: const Text('+ Add Company'),
            ),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Job title *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            if (!widget.isEditing)
              DropdownButtonFormField<ApplicationStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: [
                  for (final s in ApplicationStatus.values)
                    DropdownMenuItem(value: s, child: Text(s.label)),
                ],
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'Job URL'),
            ),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            DropdownButtonFormField<String>(
              value: _source,
              decoration: const InputDecoration(labelText: 'Source'),
              items: const [
                'LinkedIn',
                'Indeed',
                'Naukri',
                'Company Website',
                'Glassdoor',
                'Referral',
                'Foundit',
                'Other',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _source = v),
            ),
            DropdownButtonFormField<String>(
              value: _employmentType,
              decoration: const InputDecoration(labelText: 'Employment type'),
              items: const [
                'Full-time',
                'Part-time',
                'Contract',
                'Internship',
                'Freelance',
                'Other',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _employmentType = v),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Applied date'),
              subtitle: Text(_appliedAt.toLocal().toString()),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _appliedAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (date != null) {
                  setState(() {
                    _appliedAt = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      _appliedAt.hour,
                      _appliedAt.minute,
                    );
                  });
                }
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salaryMinCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Salary min'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _salaryMaxCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Salary max'),
                  ),
                ),
              ],
            ),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Currency'),
              items: const [
                'INR',
                'USD',
                'EUR',
                'GBP',
              ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
              onChanged: (v) => setState(() => _currency = v ?? 'INR'),
            ),
            TextFormField(
              controller: _recruiterNameCtrl,
              decoration: const InputDecoration(labelText: 'Recruiter name'),
            ),
            TextFormField(
              controller: _recruiterEmailCtrl,
              decoration: const InputDecoration(labelText: 'Recruiter email'),
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
    if (!_formKey.currentState!.validate() || _company == null) return;
    setState(() => _loading = true);
    final body = <String, dynamic>{
      if (!widget.isEditing) 'company_id': _company!.id,
      if (widget.isEditing) 'company_id': _company!.id,
      'job_title': _titleCtrl.text.trim(),
      'job_url': _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      'source': _source,
      'employment_type': _employmentType,
      if (!widget.isEditing) 'status': _status.apiValue,
      'applied_at': _appliedAt.toUtc().toIso8601String(),
      'recruiter_name': _recruiterNameCtrl.text.trim().isEmpty
          ? null
          : _recruiterNameCtrl.text.trim(),
      'recruiter_email': _recruiterEmailCtrl.text.trim().isEmpty
          ? null
          : _recruiterEmailCtrl.text.trim(),
      'salary_min': double.tryParse(_salaryMinCtrl.text.trim()),
      'salary_max': double.tryParse(_salaryMaxCtrl.text.trim()),
      'currency': _currency,
      'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    };

    try {
      final repo = ref.read(applicationRepositoryProvider);
      if (widget.isEditing) {
        await repo.updateApplication(widget.applicationId!, body);
      } else {
        await repo.createApplication(body);
      }
      ref.invalidate(applicationsControllerProvider);
      ref.invalidate(companiesListProvider);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save application')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
