import 'package:flutter/material.dart';
import '../../features/journey/ask_titodex_sessions.dart';
import '../../l10n/app_zh.dart';
import '../../theme/secondary_typography.dart';

class AskSessionAction {
  const AskSessionAction(this.kind, [this.id]);
  final String kind;
  final String? id;
}

Future<AskSessionAction?> showAskSessions(
  BuildContext context,
  AskTitoDexSessions snapshot, {
  bool chooseDeletion = false,
}) {
  final sessions = [...snapshot.sessions]
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  return showModalBottomSheet<AskSessionAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (sheetContext) => SizedBox(
      height: MediaQuery.sizeOf(sheetContext).height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    chooseDeletion
                        ? AppZh.askTitoDexChooseSessionDelete
                        : AppZh.askTitoDexSessionsCount(sessions.length),
                    style: SecondaryTypography.onCard.h15,
                  ),
                ),
                IconButton(
                  tooltip: AppZh.cancel,
                  onPressed: () => Navigator.pop(sheetContext),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (!chooseDeletion)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('ask-titodex-session-create'),
                  onPressed: () => Navigator.pop(
                    sheetContext,
                    const AskSessionAction('create'),
                  ),
                  icon: const Icon(Icons.add_comment_outlined),
                  label: Text(AppZh.askTitoDexNewTopic),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final title = session.title.isEmpty
                    ? AppZh.askTitoDexNewTopic
                    : session.title;
                return ListTile(
                  key: ValueKey('ask-session-${session.id}'),
                  title: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(askSessionSummary(session)),
                  leading: Icon(
                    chooseDeletion
                        ? Icons.delete_outline
                        : session.id == snapshot.activeId
                        ? Icons.chat_bubble
                        : Icons.chat_bubble_outline,
                  ),
                  onTap: () => Navigator.pop(
                    sheetContext,
                    AskSessionAction(
                      chooseDeletion ? 'delete' : 'select',
                      session.id,
                    ),
                  ),
                  trailing: chooseDeletion
                      ? null
                      : IconButton(
                          key: ValueKey('ask-session-delete-${session.id}'),
                          tooltip: AppZh.askTitoDexDeleteSession,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => Navigator.pop(
                            sheetContext,
                            AskSessionAction('delete', session.id),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

String askSessionSummary(AskTitoDexSession session) {
  final date = session.updatedAt.toLocal();
  final time =
      '${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  return AppZh.askTitoDexSessionSummary(session.entries.length, time);
}
