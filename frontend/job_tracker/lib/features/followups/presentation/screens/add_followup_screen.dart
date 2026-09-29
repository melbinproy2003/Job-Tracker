import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/api_exception.dart';
import '../../../../shared/error/error_view.dart';
import '../../../../shared/loading/loading_view.dart';
import '../../../applications/data/datasources/application_api_datasource.dart';
import '../../../applications/providers/applications_providers.dart';
import '../../../dashboard/providers/dashboard_providers.dart';
import '../../domain/entities/follow_up.dart';
import '../../providers/followups_providers.dart';
import '../widgets/followup_form.dart';

class AddEditFollowUpScreen extends ConsumerStatefulWidget {
  const AddEditFollowUpScreen({super.key, this.followupId, this.applicationId});

  final String? followupId;
  final String? applicationId;

  bool get isEditing => followupId != null;

  @override
  ConsumerState<AddEditFollowUpScreen> createState() =>
      _AddEditFollowUpScreenState();
}

class _AddEditFollowUpScreenState extends ConsumerState<AddEditFollowUpScreen> {
  List? _apps;
  FollowUp? _existing;
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
      FollowUp? existing;
      if (widget.followupId != null) {
        existing = await ref
            .read(followUpRepositoryProvider)
            .getById(widget.followupId!);
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

  FollowUpFormData _initial() {
    final existing = _existing;
    if (existing != null) {
      return FollowUpFormData(
        applicationId: existing.applicationId,
        title: existing.title,
        date: existing.scheduledAt,
        time: TimeOfDay.fromDateTime(existing.scheduledAt),
        notes: existing.notes ?? '',
      );
    }
    final now = DateTime.now().add(const Duration(days: 1));
    return FollowUpFormData(
      applicationId: widget.applicationId,
      title: 'Follow up with recruiter',
      date: DateTime(now.year, now.month, now.day),
      time: const TimeOfDay(hour: 14, minute: 0),
    );
  }

  Future<bool> _confirmForce(String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Similar follow-up exists'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create anyway'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _submit(FollowUpFormData data) async {
    final repo = ref.read(followUpRepositoryProvider);
    Future<void> save({required bool force}) async {
      if (widget.isEditing) {
        await repo.update(widget.followupId!, data.toUpdateBody(force: force));
      } else {
        await repo.create(data.toBody(force: force));
      }
    }

    try {
      await save(force: false);
    } on ApiException catch (e) {
      if (e.isFollowupDuplicate) {
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
          const SnackBar(content: Text('Failed to save follow-up')),
        );
      }
      return;
    }

    ref.invalidate(followupsProvider);
    ref.invalidate(dashboardProvider);
    if (data.applicationId != null) {
      ref.invalidate(applicationFollowupsProvider(data.applicationId!));
    }
    if (mounted) context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Follow-up' : 'Add Follow-up'),
        ),
        body: const LoadingView(),
      );
    }
    if (_error != null || _apps == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.isEditing ? 'Edit Follow-up' : 'Add Follow-up'),
        ),
        body: ErrorView(message: 'Unable to load form.', onRetry: _load),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Follow-up' : 'Add Follow-up'),
      ),
      body: FollowUpForm(
        initial: _initial(),
        applications: List.from(_apps!),
        lockApplication: widget.applicationId != null || widget.isEditing,
        submitLabel: widget.isEditing ? 'Save changes' : 'Create follow-up',
        onSubmit: _submit,
      ),
    );
  }
}
