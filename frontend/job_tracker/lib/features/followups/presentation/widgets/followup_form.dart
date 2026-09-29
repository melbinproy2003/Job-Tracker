import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../applications/domain/entities/application.dart';

class FollowUpFormData {
  FollowUpFormData({
    this.applicationId,
    this.title = '',
    this.date,
    this.time,
    this.notes = '',
  });

  String? applicationId;
  String title;
  DateTime? date;
  TimeOfDay? time;
  String notes;

  DateTime? get scheduledAt {
    if (date == null || time == null) return null;
    return DateTime(
      date!.year,
      date!.month,
      date!.day,
      time!.hour,
      time!.minute,
    );
  }

  Map<String, dynamic> toBody({bool force = false}) {
    return {
      'application_id': applicationId,
      'title': title.trim(),
      'scheduled_at': toApiDateTime(scheduledAt!),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'force': force,
    };
  }

  Map<String, dynamic> toUpdateBody({bool force = false}) {
    return {
      'title': title.trim(),
      'scheduled_at': toApiDateTime(scheduledAt!),
      if (notes.trim().isNotEmpty) 'notes': notes.trim() else 'notes': null,
      'force': force,
    };
  }
}

class FollowUpForm extends StatefulWidget {
  const FollowUpForm({
    super.key,
    required this.initial,
    required this.applications,
    required this.onSubmit,
    this.lockApplication = false,
    this.submitLabel = 'Save',
  });

  final FollowUpFormData initial;
  final List<Application> applications;
  final Future<void> Function(FollowUpFormData data) onSubmit;
  final bool lockApplication;
  final String submitLabel;

  @override
  State<FollowUpForm> createState() => _FollowUpFormState();
}

class _FollowUpFormState extends State<FollowUpForm> {
  late FollowUpFormData _data;
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _data.date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (picked != null) setState(() => _data.date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _data.time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _data.time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_data.applicationId == null || _data.applicationId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an application')));
      return;
    }
    if (_data.date == null || _data.time == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Date and time are required')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_data);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _data.applicationId,
            decoration: const InputDecoration(labelText: 'Application *'),
            items: [
              for (final a in widget.applications)
                DropdownMenuItem(
                  value: a.id,
                  child: Text(
                    '${a.company.name} — ${a.jobTitle}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: widget.lockApplication
                ? null
                : (v) => setState(() => _data.applicationId = v),
            validator: (v) =>
                v == null || v.isEmpty ? 'Application is required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.title,
            decoration: const InputDecoration(labelText: 'Title *'),
            onChanged: (v) => _data.title = v,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Title is required' : null,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _data.date == null
                  ? 'Date *'
                  : 'Date: ${_data.date!.toString().split(' ').first}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickDate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _data.time == null
                  ? 'Time *'
                  : 'Time: ${_data.time!.format(context)}',
            ),
            trailing: const Icon(Icons.access_time),
            onTap: _pickTime,
          ),
          TextFormField(
            initialValue: _data.notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
            onChanged: (v) => _data.notes = v,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Saving…' : widget.submitLabel),
          ),
        ],
      ),
    );
  }
}
