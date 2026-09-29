import 'package:flutter/material.dart';

import '../../../../core/enums/interview_enums.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../applications/domain/entities/application.dart';

class InterviewFormData {
  InterviewFormData({
    this.applicationId,
    this.type = InterviewType.technicalInterview,
    this.title = '',
    this.date,
    this.time,
    this.durationMinutes = 60,
    this.meetingUrl = '',
    this.location = '',
    this.interviewerName = '',
    this.interviewerEmail = '',
    this.notes = '',
    this.status = InterviewStatus.scheduled,
  });

  String? applicationId;
  InterviewType type;
  String title;
  DateTime? date;
  TimeOfDay? time;
  int durationMinutes;
  String meetingUrl;
  String location;
  String interviewerName;
  String interviewerEmail;
  String notes;
  InterviewStatus status;

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
    final at = scheduledAt;
    return {
      'type': type.apiValue,
      if (title.trim().isNotEmpty) 'title': title.trim(),
      'scheduled_at': toApiDateTime(at!),
      'duration_minutes': durationMinutes,
      if (meetingUrl.trim().isNotEmpty) 'meeting_url': meetingUrl.trim(),
      if (location.trim().isNotEmpty) 'location': location.trim(),
      if (interviewerName.trim().isNotEmpty)
        'interviewer_name': interviewerName.trim(),
      if (interviewerEmail.trim().isNotEmpty)
        'interviewer_email': interviewerEmail.trim(),
      if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      'status': status.apiValue,
      'force': force,
    };
  }
}

class InterviewForm extends StatefulWidget {
  const InterviewForm({
    super.key,
    required this.initial,
    required this.applications,
    required this.onSubmit,
    this.lockApplication = false,
    this.submitLabel = 'Save',
    this.showStatus = false,
  });

  final InterviewFormData initial;
  final List<Application> applications;
  final Future<void> Function(InterviewFormData data) onSubmit;
  final bool lockApplication;
  final String submitLabel;
  final bool showStatus;

  @override
  State<InterviewForm> createState() => _InterviewFormState();
}

class _InterviewFormState extends State<InterviewForm> {
  late InterviewFormData _data;
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
          DropdownButtonFormField<InterviewType>(
            value: _data.type,
            decoration: const InputDecoration(labelText: 'Interview Type *'),
            items: [
              for (final t in InterviewType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _data.type = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.title,
            decoration: const InputDecoration(labelText: 'Title'),
            onChanged: (v) => _data.title = v,
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _data.date == null
                  ? 'Date *'
                  : 'Date: ${_data.date!.year}-${_data.date!.month.toString().padLeft(2, '0')}-${_data.date!.day.toString().padLeft(2, '0')}',
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
            initialValue: '${_data.durationMinutes}',
            decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n > 0) _data.durationMinutes = n;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.meetingUrl,
            decoration: const InputDecoration(labelText: 'Meeting URL'),
            onChanged: (v) => _data.meetingUrl = v,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              if (!v.startsWith('http://') && !v.startsWith('https://')) {
                return 'Enter a valid URL';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.location,
            decoration: const InputDecoration(labelText: 'Location'),
            onChanged: (v) => _data.location = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.interviewerName,
            decoration: const InputDecoration(labelText: 'Interviewer Name'),
            onChanged: (v) => _data.interviewerName = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.interviewerEmail,
            decoration: const InputDecoration(labelText: 'Interviewer Email'),
            onChanged: (v) => _data.interviewerEmail = v,
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: _data.notes,
            decoration: const InputDecoration(labelText: 'Notes'),
            maxLines: 3,
            onChanged: (v) => _data.notes = v,
          ),
          if (widget.showStatus) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<InterviewStatus>(
              value: _data.status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [
                for (final s in InterviewStatus.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _data.status = v);
              },
            ),
          ],
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
