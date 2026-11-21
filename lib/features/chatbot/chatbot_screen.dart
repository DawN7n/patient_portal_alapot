import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../data/repositories/patient_portal_repository.dart';
import '../../services/alapot_ai_service.dart';
import '../../shared/widgets/ui.dart';

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({
    super.key,
    this.initialTicketId,
    this.initialMessages = const [],
  });

  final String? initialTicketId;
  final List<Map<String, dynamic>> initialMessages;

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final _repository = PatientPortalRepository();
  final _ai = AlapotAiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <Map<String, String>>[];
  bool _sending = false;
  bool _savingTicket = false;
  String? _ticketId;

  @override
  void initState() {
    super.initState();
    _ticketId = widget.initialTicketId;
    for (final item in widget.initialMessages) {
      final sender = (item['sender_role'] ?? item['sender'] ?? '').toString().toLowerCase();
      final text = (item['text'] ?? '').toString().trim();
      if (text.isEmpty) continue;
      _messages.add({'role': sender == 'patient' || sender == 'user' ? 'user' : 'assistant', 'content': text});
    }
    if (_messages.isEmpty) {
      _messages.add({
        'role': 'assistant',
        'content': 'Hello! I’m Alapot AI, the Alapot Dental Clinic assistant. Ask me about using the portal, appointments, published clinic services, or general oral-health information. I cannot diagnose or prescribe treatment.',
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _ai.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggested]) async {
    final text = (suggested ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    if (text.length > 3000) {
      _showMessage('Please keep each message under 3,000 characters.');
      return;
    }
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _input.clear();
    });
    _scrollToEnd();
    try {
      if (_ticketId != null) {
        await _repository.appendSupportTicketMessage(ticketId: _ticketId!, text: text, senderName: 'Patient');
      }
      final history = _messages.length > 14 ? _messages.sublist(_messages.length - 14) : _messages;
      final reply = await _ai.ask(history);
      final answer = reply.answer;
      if (!mounted) return;
      setState(() => _messages.add({'role': 'assistant', 'content': answer}));
      if (_ticketId != null) {
        await _repository.appendSupportTicketMessage(
          ticketId: _ticketId!, text: answer, senderName: 'Alapot AI', fromAi: true,
        );
      } else if (reply.createTicket) {
        await _saveAsTicket(automatic: true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _messages.add({
        'role': 'assistant',
        'content': 'I could not connect just now. ${error.toString().replaceFirst('Bad state: ', '')}',
      }));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  Future<void> _saveAsTicket({bool automatic = false}) async {
    if (_savingTicket || _ticketId != null) return;
    final userMessages = _messages.where((m) => m['role'] == 'user').toList();
    if (userMessages.isEmpty) {
      _showMessage('Ask Alapot AI a question before saving a ticket.');
      return;
    }
    setState(() => _savingTicket = true);
    try {
      final profile = await _repository.getMyPatientProfile();
      final patientName = (profile?['name'] ?? 'Patient').toString();
      final firstQuestion = userMessages.first['content'] ?? 'Alapot AI conversation';
      final lastQuestion = userMessages.last['content'] ?? firstQuestion;
      final ticketId = await _repository.createSupportTicket(
        subject: firstQuestion.length > 70 ? '${firstQuestion.substring(0, 67)}…' : firstQuestion,
        category: 'Alapot AI',
        message: lastQuestion,
        patientName: patientName,
        conversation: _messages,
      );
      if (!mounted) return;
      setState(() => _ticketId = ticketId);
      _showMessage(automatic
          ? 'Alapot AI has saved this conversation as a ticket for clinic staff follow-up. You can review it in Settings → My Tickets and continue the conversation there.'
          : 'Conversation saved to Settings → My Tickets. You can reopen it and continue with Alapot AI.');
    } catch (error) {
      if (mounted) _showMessage('Could not save this conversation: ${error.toString().replaceFirst('Bad state: ', '')}');
    } finally {
      if (mounted) setState(() => _savingTicket = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Close'))],
      ),
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      PageHeading(
        'Alapot AI',
        subtitle: _ticketId == null
            ? 'Ask portal and general dental questions. Save a conversation to My Tickets to continue it later.'
            : 'Continuing your saved My Tickets conversation.',
        trailing: _ticketId == null
            ? OutlinedButton.icon(
                onPressed: _savingTicket ? null : _saveAsTicket,
                icon: _savingTicket
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.bookmark_add_outlined, size: 17),
                label: const Text('Save to My Tickets'),
              )
            : const Chip(avatar: Icon(Icons.confirmation_number_outlined, size: 16), label: Text('Saved ticket')),
      ),
      Expanded(
        child: SurfaceCard(
          child: ListView.builder(
            controller: _scroll,
            itemCount: _messages.length + (_sending ? 1 : 0),
            itemBuilder: (context, index) {
              if (_sending && index == _messages.length) {
                return const Align(alignment: Alignment.centerLeft, child: Padding(
                  padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                ));
              }
              final item = _messages[index];
              final mine = item['role'] == 'user';
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.sky : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(item['content'] ?? '', style: const TextStyle(fontSize: 12, height: 1.5)),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ActionChip(label: const Text('Appointments'), onPressed: _sending ? null : () => _send('How do I manage my appointments in the patient portal?')),
        ActionChip(label: const Text('My records'), onPressed: _sending ? null : () => _send('Where can I view my dental records?')),
        ActionChip(label: const Text('Oral health'), onPressed: _sending ? null : () => _send('What are the basics of daily oral hygiene?')),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: TextField(
          controller: _input,
          minLines: 1,
          maxLines: 4,
          enabled: !_sending,
          onSubmitted: (_) => _send(),
          decoration: const InputDecoration(hintText: 'Ask Alapot AI a question…', border: OutlineInputBorder(), isDense: true),
        )),
        const SizedBox(width: 8),
        IconButton.filled(onPressed: _sending ? null : () => _send(), icon: const Icon(Icons.send_rounded), tooltip: 'Send'),
      ]),
    ]);
  }
}
