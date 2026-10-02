import 'priority.dart';

/// An email (triaged by Claude) or something you added to your inbox yourself.
class InboxItem {
  InboxItem({
    required this.id,
    required this.title,
    required this.receivedAt,
    this.accountId,
    this.fromName,
    this.fromAddress,
    this.summary,
    this.priority,
    this.priorityReason,
    this.deadline,
    this.url,
    this.dismissed = false,
  });

  factory InboxItem.fromRow(Map<String, dynamic> row) => InboxItem(
        id: row['id'] as String,
        accountId: row['account_id'] as String?,
        title: row['title'] as String? ?? '(no subject)',
        receivedAt: DateTime.parse(row['received_at'] as String).toLocal(),
        fromName: row['from_name'] as String?,
        fromAddress: row['from_address'] as String?,
        summary: row['summary'] as String?,
        priority: Priority.parse(row['priority']),
        priorityReason: row['priority_reason'] as String?,
        deadline: row['deadline'] == null ? null : DateTime.parse(row['deadline'] as String).toLocal(),
        url: row['url'] as String?,
        dismissed: row['dismissed'] as bool? ?? false,
      );

  final String id;
  final String? accountId; // null = added in Docket
  final String title;
  final DateTime receivedAt;
  final String? fromName;
  final String? fromAddress;
  final String? summary; // Claude's summary for emails, your notes for your own items
  final Priority? priority; // null = email not triaged yet
  final String? priorityReason;
  final DateTime? deadline;
  final String? url;
  final bool dismissed; // marked done

  bool get isManual => accountId == null;
  Priority get effectivePriority => priority ?? Priority.medium;
  String? get sender => fromName ?? fromAddress;
}
