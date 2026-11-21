import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Patient-side client for the shared Alapot AI PHP proxy.
/// Configure with --dart-define=ALAPOT_AI_API_URL=https://your-host/shared_backend/alapot-ai.php
class AlapotAiReply {
  const AlapotAiReply({required this.answer, required this.createTicket});
  final String answer;
  final bool createTicket;
}

class AlapotAiService {
  AlapotAiService({FirebaseAuth? auth, http.Client? client})
      : _auth = auth ?? FirebaseAuth.instance,
        _client = client ?? http.Client();

  final FirebaseAuth _auth;
  final http.Client _client;

  void dispose() => _client.close();

  static const String _endpoint = String.fromEnvironment('ALAPOT_AI_API_URL');

  Future<AlapotAiReply> ask(List<Map<String, String>> messages) async {
    if (_endpoint.trim().isEmpty) {
      throw StateError(
        'Alapot AI has not been connected to the clinic server yet. Set ALAPOT_AI_API_URL when building the app.',
      );
    }
    final user = _auth.currentUser;
    if (user == null) throw StateError('Please sign in again to use Alapot AI.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Your secure login token is unavailable. Please sign in again.');
    }
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'messages': messages}),
        )
        .timeout(const Duration(seconds: 55));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw StateError('The Alapot AI server returned an unreadable response.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] != true) {
      throw StateError((body['error'] ?? 'Alapot AI could not answer right now.').toString());
    }
    final answer = (body['answer'] ?? '').toString().trim();
    if (answer.isEmpty) throw StateError('Alapot AI returned an empty answer. Please try again.');
    return AlapotAiReply(answer: answer, createTicket: body['create_ticket'] == true);
  }
}
