import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/application_status.dart';
import '../../../applications/domain/entities/application.dart';
import '../../domain/entities/gmail_thread.dart';

/// The mandatory confirmation surface for a suggested Gmail match.
///
/// Nothing here mutates anything by itself: linking, applying a status and
/// creating an interview are each a separate, explicit, opt-in control. A
/// low-confidence match deliberately withholds the one-tap link.
class ApplicationMatchCard extends StatefulWidget {
  const ApplicationMatchCard({
    super.key,
    required this.thread,
    required this.candidates,
    required this.onConfirm,
    required this.onIgnore,
    this.busy = false,
  });

  final GmailThread thread;
  final List<Application> candidates;

  /// Awaited so the button can show a spinner for the whole server round-trip,
  /// which may include a status change and an interview creation.
  final Future<void> Function({
    required String applicationId,
    ApplicationStatus? status,
    required bool createInterview,
  })
  onConfirm;
  final VoidCallback onIgnore;
  final bool busy;

  @override
  State<ApplicationMatchCard> createState() => _ApplicationMatchCardState();
}

class _ApplicationMatchCardState extends State<ApplicationMatchCard> {
  String? _selectedId;
  bool _applyStatus = false;
  bool _createInterview = false;

  @override
  void initState() {
    super.initState();
    _selectedId = _initialSelection();
  }

  @override
  void didUpdateWidget(covariant ApplicationMatchCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The candidate list arrives asynchronously, so the first build can have
    // no candidates at all. Re-evaluate once they load, but never overwrite a
    // choice the user has already made.
    if (_selectedId == null &&
        oldWidget.candidates.isEmpty &&
        widget.candidates.isNotEmpty) {
      setState(() => _selectedId = _initialSelection());
    }
  }

  /// The matcher's best guess, offered as a pre-selection only when it is
  /// safe to do so: either the thread is already linked, or the suggestion is
  /// confident enough to trust. A low-confidence match starts unselected so
  /// the user has to make an explicit, deliberate choice. The mutating
  /// options are never pre-ticked regardless.
  String? _initialSelection() {
    final linkedId = widget.thread.applicationId;
    if (linkedId != null && linkedId.isNotEmpty) return linkedId;
    if (widget.candidates.isEmpty) return null;
    if (!MatchConfidence.fromScore(widget.thread.matchConfidence).isReliable) {
      return null;
    }
    return widget.candidates.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thread = widget.thread;
    final suggestion = thread.interviewSuggestion;
    final confidence = MatchConfidence.fromScore(thread.matchConfidence);
    final candidates = widget.candidates;

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.mail_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    thread.subject?.trim().isNotEmpty ?? false
                        ? thread.subject!.trim()
                        : 'Job-related email',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Possible application',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (candidates.isEmpty)
              Text(
                'No matching application found.',
                style: theme.textTheme.bodyMedium,
              )
            else
              Column(
                children: candidates.map((app) {
                  return RadioListTile<String>(
                    value: app.id,
                    // ignore: deprecated_member_use
                    groupValue: _selectedId,
                    // ignore: deprecated_member_use
                    onChanged: widget.busy
                        ? null
                        : (value) => setState(() => _selectedId = value),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      app.company.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(app.jobTitle),
                  );
                }).toList(),
              ),
            if (thread.matchConfidence != null) ...[
              const SizedBox(height: 8),
              Text(
                'Match confidence: ${confidence.label}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: confidence.isReliable
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.error,
                ),
              ),
              if (!confidence.isReliable)
                Text(
                  'Low confidence — review the choice before linking.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
            ],
            if (thread.suggestedStatus != null) ...[
              const Divider(height: 28),
              _ConfirmToggle(
                title: 'Update status',
                subtitle:
                    'Set this application to "${_statusLabel(thread.suggestedStatus!)}"',
                value: _applyStatus,
                enabled: !widget.busy,
                onChanged: (v) => setState(() => _applyStatus = v ?? false),
              ),
            ],
            if (suggestion != null && suggestion.isActionable) ...[
              _InterviewPreview(suggestion: suggestion),
              _ConfirmToggle(
                title: 'Add interview',
                subtitle: 'Create the detected interview on the application',
                value: _createInterview,
                enabled: !widget.busy,
                onChanged: (v) => setState(() => _createInterview = v ?? false),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.busy ? null : widget.onIgnore,
                    child: const Text('Ignore'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.busy || _selectedId == null
                        ? null
                        : () => widget.onConfirm(
                            applicationId: _selectedId!,
                            status: _applyStatus
                                ? _statusFrom(thread.suggestedStatus)
                                : null,
                            createInterview:
                                _createInterview && suggestion != null,
                          ),
                    child: widget.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Link to application'),
                  ),
                ),
              ],
            ),
            if (_selectedId == null) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: widget.busy
                    ? null
                    : () => _promptCreateApplication(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Create a new application'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _promptCreateApplication(BuildContext context) {
    // The user must create the application first; the new thread is resolved
    // from the applications list on the next refresh.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create the application first, then link this email.'),
      ),
    );
  }

  static ApplicationStatus? _statusFrom(String? apiValue) {
    if (apiValue == null) return null;
    for (final status in ApplicationStatus.values) {
      if (status.apiValue == apiValue) return status;
    }
    return null;
  }

  /// Renders a backend status value using the shared enum label, so the
  /// confirmation text cannot drift from the chip shown elsewhere.
  static String _statusLabel(String apiValue) {
    return _statusFrom(apiValue)?.label ?? apiValue;
  }
}

class _ConfirmToggle extends StatelessWidget {
  const _ConfirmToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: enabled ? onChanged : null,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
    );
  }
}

class _InterviewPreview extends StatelessWidget {
  const _InterviewPreview({required this.suggestion});
  final InterviewSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final at = suggestion.scheduledAt;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interview detected',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          if (suggestion.title != null) Text(suggestion.title!),
          if (at != null) Text(DateFormat.yMMMd().add_jm().format(at)),
          if (suggestion.durationMinutes != null)
            Text('${suggestion.durationMinutes} minutes'),
          if ((suggestion.meetingUrl ?? '').isNotEmpty)
            Text(
              suggestion.meetingUrl!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
