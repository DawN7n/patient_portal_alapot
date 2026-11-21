import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../shared/widgets/ui.dart';

/// Patient <-> Dentist real-time inbox. Replaces the old in-memory MessagesScreen.
/// The optional [initialDentist] keeps compatibility with PatientShell's existing
/// `MessagesScreen(initialDentist: selectedDentist)` navigation call.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, this.initialDentist});

  final dynamic initialDentist;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final PatientPortalRepository _repository = PatientPortalRepository();
  final TextEditingController _messageController = TextEditingController();
  String? _selectedConversationId;
  String? _lastMarkedReadConversationId;
  bool _sending = false;
  bool _openingInitial = false;
  bool _mobileChatOpen = false;
  String _pageError = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialDentist != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialDentist());
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _readDynamic(dynamic value, String key) {
    if (value == null) return '';
    if (value is Map) return (value[key] ?? '').toString();
    try {
      switch (key) {
        case 'id': return (value.id ?? '').toString();
        case 'name': return (value.name ?? '').toString();
        case 'uid': return (value.uid ?? '').toString();
        case 'auth_uid': return (value.authUid ?? '').toString();
        default: return '';
      }
    } catch (_) {
      return '';
    }
  }

  Future<void> _openInitialDentist() async {
    if (_openingInitial || !mounted) return;
    _openingInitial = true;
    try {
      final source = widget.initialDentist;
      final id = _readDynamic(source, 'id');
      final name = _readDynamic(source, 'name');
      if (id.isEmpty && name.isEmpty) return;
      final conversationId = await _repository.startConversation(
        dentist: {
          'id': id,
          'name': name.isEmpty ? 'Dentist' : name,
          'uid': _readDynamic(source, 'uid'),
          'auth_uid': _readDynamic(source, 'auth_uid'),
        },
        patientName: await _patientName(),
      );
      if (!mounted) return;
      setState(() {
        _selectedConversationId = conversationId;
        _mobileChatOpen = true;
      });
    } catch (error) {
      if (mounted) setState(() => _pageError = error.toString());
    } finally {
      _openingInitial = false;
    }
  }

  Future<String> _patientName() async {
    final profile = await _repository.getMyPatientProfile();
    return (profile?['name'] ?? 'Patient').toString();
  }

  Future<void> _chooseDentist() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .70,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Start a conversation', style: Theme.of(sheetContext).textTheme.titleLarge),
                const SizedBox(height: 5),
                const Text('Choose a dentist from the clinic directory.'),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _repository.watchDentists(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Could not load dentists: ${snapshot.error}'));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final dentists = snapshot.data!.where((dentist) {
                        final status = (dentist['status'] ?? dentist['account_status'] ?? 'active').toString().toLowerCase();
                        return status != 'inactive' && status != 'disabled';
                      }).toList();
                      if (dentists.isEmpty) return const Center(child: Text('No dentist profiles are available yet.'));
                      return ListView.separated(
                        itemCount: dentists.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final dentist = dentists[index];
                          final name = (dentist['name'] ?? 'Dentist').toString();
                          final detail = (dentist['specialization'] ?? dentist['specialty'] ?? 'Dental care').toString();
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Avatar(initials: _initials(name)),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(detail),
                            trailing: const Icon(Icons.chat_bubble_outline, color: AppColors.teal),
                            onTap: () async {
                              Navigator.pop(sheetContext);
                              await _startConversation(dentist);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _startConversation(Map<String, dynamic> dentist) async {
    try {
      final id = await _repository.startConversation(
        dentist: dentist,
        patientName: await _patientName(),
      );
      if (!mounted) return;
      setState(() {
        _selectedConversationId = id;
        _mobileChatOpen = true;
        _pageError = '';
      });
      await _repository.markConversationRead(id);
      _lastMarkedReadConversationId = id;
    } catch (error) {
      if (mounted) setState(() => _pageError = error.toString());
    }
  }

  Future<void> _selectConversation(String id, {bool openMobile = false}) async {
    if (!mounted) return;
    setState(() {
      _selectedConversationId = id;
      if (openMobile) _mobileChatOpen = true;
      _pageError = '';
    });
    if (_lastMarkedReadConversationId == id) return;
    try {
      await _repository.markConversationRead(id);
      _lastMarkedReadConversationId = id;
    } catch (error) {
      if (mounted) setState(() => _pageError = error.toString());
    }
  }

  Future<void> _sendMessage() async {
    final id = _selectedConversationId;
    final text = _messageController.text.trim();
    if (id == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repository.sendPatientMessage(
        conversationId: id,
        text: text,
        senderName: await _patientName(),
      );
      _messageController.clear();
      if (mounted) setState(() => _pageError = '');
    } catch (error) {
      if (mounted) setState(() => _pageError = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 720;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Messages',
            subtitle: 'Private conversations with your dental care team.',
            trailing: IconButton.filledTonal(
              tooltip: 'New conversation',
              onPressed: _chooseDentist,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ),
          if (_pageError.isNotEmpty) ...[
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
              child: Text(_pageError, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
            ),
          ],
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _repository.watchMyConversations(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Could not load messages. ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final conversations = [...snapshot.data!]
                  ..sort((a, b) => (b['updated_at'] ?? '').toString().compareTo((a['updated_at'] ?? '').toString()));
                Map<String, dynamic>? selected;
                for (final item in conversations) {
                  if (item['_docId'] == _selectedConversationId || item['id'] == _selectedConversationId) {
                    selected = item;
                    break;
                  }
                }
                selected ??= (conversations.isNotEmpty && !isMobile) ? conversations.first : null;
                final selectedId = (selected?['_docId'] ?? selected?['id'] ?? '').toString();
                if (_selectedConversationId == null && selectedId.isNotEmpty && !isMobile) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _selectedConversationId == null) {
                      _selectConversation(selectedId);
                    }
                  });
                }

                if (isMobile) {
                  if (_mobileChatOpen && selected != null) {
                    return _buildChat(selected, selectedId, isMobile: true);
                  }
                  return _buildConversationList(conversations, selectedId, isMobile: true);
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 310, child: _buildConversationList(conversations, selectedId)),
                    const SizedBox(width: 14),
                    Expanded(child: selected == null ? _emptyChat() : _buildChat(selected, selectedId)),
                  ],
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Widget _buildConversationList(List<Map<String, dynamic>> conversations, String selectedId, {bool isMobile = false}) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(children: [
              Expanded(child: Text('Conversations', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              Text('${conversations.length}', style: const TextStyle(color: AppColors.muted)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: conversations.isEmpty
                ? _emptyList()
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      final id = (conversation['_docId'] ?? conversation['id'] ?? '').toString();
                      final name = (conversation['dentist_name'] ?? 'Dentist').toString();
                      final active = id == selectedId;
                      return ListTile(
                        selected: active,
                        selectedTileColor: AppColors.teal.withValues(alpha: .08),
                        leading: Avatar(initials: _initials(name), color: AppColors.mint),
                        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text((conversation['last_message'] ?? 'Start a conversation').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectConversation(id, openMobile: true),
                      );
                    },
                  ),
          ),
          if (isMobile)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _chooseDentist, icon: const Icon(Icons.add), label: const Text('New message'))),
            ),
        ],
      ),
    );
  }

  Widget _buildChat(Map<String, dynamic> conversation, String conversationId, {bool isMobile = false}) {
    final dentistName = (conversation['dentist_name'] ?? 'Dentist').toString();
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              if (isMobile) IconButton(onPressed: () => setState(() => _mobileChatOpen = false), icon: const Icon(Icons.arrow_back), tooltip: 'Back to conversations'),
              Avatar(initials: _initials(dentistName), color: AppColors.mint, size: 42),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dentistName, style: const TextStyle(fontWeight: FontWeight.w700)),
                const Text('Private clinic conversation', style: TextStyle(color: AppColors.muted, fontSize: 11)),
              ])),
              const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(conversationId),
              stream: _repository.watchMessages(conversationId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Could not load this conversation. ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = [...snapshot.data!]
                  ..sort((a, b) => (a['created_at'] ?? '').toString().compareTo((b['created_at'] ?? '').toString()));
                if (messages.isEmpty) return const Center(child: Text('Send a message to start the conversation.'));
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final mine = message['sender_uid'] == _repository.currentUid;
                    final time = _formatTime(message['created_at']);
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isMobile ? .78 : .55)),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                          decoration: BoxDecoration(
                            color: mine ? AppColors.teal : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15), topRight: const Radius.circular(15),
                              bottomLeft: Radius.circular(mine ? 15 : 4), bottomRight: Radius.circular(mine ? 4 : 15),
                            ),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text((message['text'] ?? '').toString(), style: TextStyle(color: mine ? Colors.white : Theme.of(context).colorScheme.onSurface)),
                            if (time.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(time, style: TextStyle(color: mine ? Colors.white70 : AppColors.muted, fontSize: 10)),
                            ],
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 4000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Write a message...', counterText: '', border: OutlineInputBorder()),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(height: 50, width: 50, child: IconButton.filled(onPressed: _sending ? null : _sendMessage, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send), tooltip: 'Send message')),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _emptyChat() => SurfaceCard(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.forum_outlined, size: 42, color: AppColors.muted),
            const SizedBox(height: 10),
            Text('Your messages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 5),
            const Text('Choose a conversation or start a new one.'),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: _chooseDentist, icon: const Icon(Icons.add), label: const Text('New message')),
          ]),
        ),
      );

  Widget _emptyList() => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chat_bubble_outline, size: 36, color: AppColors.muted),
            const SizedBox(height: 9),
            const Text('No messages yet', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Start a private conversation with your dentist.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _chooseDentist, icon: const Icon(Icons.add), label: const Text('New message')),
          ]),
        ),
      );

  static String _initials(String name) => name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2).map((part) => part[0].toUpperCase()).join();

  static String _formatTime(dynamic value) {
    final date = DateTime.tryParse((value ?? '').toString());
    if (date == null) return '';
    return DateFormat.jm().format(date.toLocal());
  }
}
