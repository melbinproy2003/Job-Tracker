import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/interview_enums.dart';
import '../../../../core/errors/api_exception.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../applications/data/datasources/application_api_datasource.dart';
import '../../../applications/providers/applications_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../domain/entities/interview.dart';
import '../../providers/interviews_providers.dart';
import '../widgets/interview_form.dart';

class AddEditInterviewScreen extends ConsumerStatefulWidget {
  const AddEditInterviewScreen({
    super.key,
    this.interviewId,
    this.applicationId,
  });

  final String? interviewId;
  final String? applicationId;

  bool get isEditing => interviewId != null;

  @override
  ConsumerState<AddEditInterviewScreen> createState() =>
      _AddEditInterviewScreenState();
}

class _AddEditInterviewScreenState
    extends ConsumerState<AddEditInterviewScreen> {
  List? _apps;
  Interview? _existing;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final apps = await ref
          .read(applicationRepositoryProvider)
          .getApplications(const ApplicationListQuery(pageSize: 100));
      Interview? existing;
      if (widget.interviewId != null) {
        existing = await ref
            .read(interviewRepositoryProvider)
            .getById(widget.interviewId!);
      }
      if (!mounted) return;
      setState(() {
        _apps = apps.items;
        _existing = existing;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  InterviewFormData _initial() {
    final existing = _existing;
    if (existing != null) {
      return InterviewFormData(
        applicationId: existing.applicationId,
        type: existing.type,
        title: existing.title ?? '',
        date: existing.scheduledAt,
        time: TimeOfDay.fromDateTime(existing.scheduledAt),
        durationMinutes: existing.durationMinutes ?? 60,
        meetingUrl: existing.meetingUrl ?? '',
        location: existing.location ?? '',
        interviewerName: existing.interviewerName ?? '',
        interviewerEmail: existing.interviewerEmail ?? '',
        notes: existing.notes ?? '',
        status: existing.status,
      );
    }
    final now = DateTime.now().add(const Duration(days: 1));
    return InterviewFormData(
      applicationId: widget.applicationId,
      type: InterviewType.technicalInterview,
      date: DateTime(now.year, now.month, now.day),
      time: const TimeOfDay(hour: 10, minute: 0),
    );
  }

  Future<bool> _confirmForce(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule conflict'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Schedule anyway'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit(InterviewFormData data) async {
    final repo = ref.read(interviewRepositoryProvider);
    Future<void> save({required bool force}) async {
      final body = data.toBody(force: force);
      if (widget.isEditing) {
        await repo.update(widget.interviewId!, body);
      } else {
        await repo.create(data.applicationId!, body);
      }
    }

    try {
      await save(force: false);
    } on ApiException catch (e) {
      if (e.isInterviewConflict) {
        final force = await _confirmForce(e.message);
        if (!force) return;
        await save(force: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save interview')),
        );
      }
      return;
    }

    ref.invalidate(interviewsProvider);
    ref.invalidate(dashboardProvider);
    if (data.applicationId != null) {
      ref.invalidate(applicationInterviewsProvider(data.applicationId!));
    }
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Interview' : 'Add Interview'),
        ),
        body: const LoadingView(),
      );
    }
    if (_error != null || _apps == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Interview' : 'Add Interview'),
        ),
        body: ErrorView(message: 'Unable to load form.', onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Interview' : 'Add Interview'),
      ),
      body: InterviewForm(
        initial: _initial(),
        applications: List.from(_apps!),
        lockApplication: widget.applicationId != null || widget.isEditing,
        showStatus: widget.isEditing,
        submitLabel: widget.isEditing ? 'Save changes' : 'Create interview',
        onSubmit: _submit,
      ),
    );
  }
}
