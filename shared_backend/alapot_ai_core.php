<?php
declare(strict_types=1);

require_once __DIR__ . '/../admin_portal/config/firebase.php';

function alapotAiRespond(array $payload, int $status = 200): never
{
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store, max-age=0');
    echo json_encode($payload, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
    exit;
}

function alapotAiDecodeFirestoreValue(array $value): mixed
{
    if (array_key_exists('stringValue', $value)) return $value['stringValue'];
    if (array_key_exists('booleanValue', $value)) return (bool)$value['booleanValue'];
    if (array_key_exists('integerValue', $value)) return (int)$value['integerValue'];
    if (array_key_exists('doubleValue', $value)) return (float)$value['doubleValue'];
    if (array_key_exists('timestampValue', $value)) return $value['timestampValue'];
    if (array_key_exists('mapValue', $value)) {
        $result = [];
        foreach (($value['mapValue']['fields'] ?? []) as $key => $item) $result[$key] = alapotAiDecodeFirestoreValue($item);
        return $result;
    }
    return null;
}

function alapotAiHttp(string $url, string $method, ?array $body = null, ?string $bearer = null, int $timeout = 30): array
{
    if (!function_exists('curl_init')) return ['ok' => false, 'status' => 0, 'data' => null, 'error' => 'PHP cURL is required for the Alapot AI service.'];
    $headers = ['Accept: application/json'];
    if ($body !== null) $headers[] = 'Content-Type: application/json';
    if ($bearer !== null && $bearer !== '') $headers[] = 'Authorization: Bearer ' . $bearer;
    $handle = curl_init($url);
    curl_setopt_array($handle, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_CUSTOMREQUEST => $method,
        CURLOPT_HTTPHEADER => $headers,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => $timeout,
    ]);
    if ($body !== null) curl_setopt($handle, CURLOPT_POSTFIELDS, json_encode($body, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE));
    $raw = curl_exec($handle);
    $status = (int)curl_getinfo($handle, CURLINFO_HTTP_CODE);
    $error = curl_error($handle);
    curl_close($handle);
    $decoded = is_string($raw) ? json_decode($raw, true) : null;
    return ['ok' => $status >= 200 && $status < 300, 'status' => $status, 'data' => is_array($decoded) ? $decoded : null, 'error' => $error];
}

/**
 * Shared Groq proxy. The Firebase identity and role are always resolved
 * server-side; a role sent by a client is never trusted.
 *
 * @param string|null $trustedSessionToken Firebase ID token from an already-authenticated PHP portal session.
 * @param string|null $requiredRole When called by a PHP portal, require that exact role.
 * @param array|null $payload Parsed JSON input; null means decode php://input.
 */
function alapotAiHandle(?string $trustedSessionToken = null, ?string $requiredRole = null, ?array $payload = null): never
{
    if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== 'POST') alapotAiRespond(['ok' => false, 'error' => 'Use POST for Alapot AI.'], 405);

    if ($payload === null) {
        $raw = file_get_contents('php://input');
        $payload = is_string($raw) ? json_decode($raw, true) : null;
    }
    if (!is_array($payload)) alapotAiRespond(['ok' => false, 'error' => 'The request body must be valid JSON.'], 400);

    $token = $trustedSessionToken;
    if ($token === null || $token === '') {
        $header = (string)($_SERVER['HTTP_AUTHORIZATION'] ?? '');
        if ($header === '' && function_exists('getallheaders')) {
            $headers = getallheaders();
            $header = (string)($headers['Authorization'] ?? $headers['authorization'] ?? '');
        }
        if (preg_match('/^Bearer\s+(.+)$/i', $header, $matches)) $token = trim($matches[1]);
    }
    if (!$token) alapotAiRespond(['ok' => false, 'error' => 'Your login session is missing. Please sign in again.'], 401);

    $lookup = alapotAiHttp(
        'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . rawurlencode(ALAPOT_FIREBASE_API_KEY),
        'POST',
        ['idToken' => $token],
        null,
        15
    );
    $firebaseUser = $lookup['data']['users'][0] ?? null;
    if (!$lookup['ok'] || !is_array($firebaseUser) || empty($firebaseUser['localId'])) {
        alapotAiRespond(['ok' => false, 'error' => 'Your Firebase session is invalid or expired. Please sign in again.'], 401);
    }

    $uid = (string)$firebaseUser['localId'];
    $firestoreBase = 'https://firestore.googleapis.com/v1/projects/' . ALAPOT_FIREBASE_PROJECT_ID . '/databases/(default)/documents';
    $userResult = alapotAiHttp($firestoreBase . '/users/' . rawurlencode($uid), 'GET', null, $token, 15);
    $userFields = $userResult['data']['fields'] ?? null;
    if (!$userResult['ok'] || !is_array($userFields)) {
        alapotAiRespond(['ok' => false, 'error' => 'Your Alapot portal account could not be verified. Please contact the clinic.'], 403);
    }
    $user = [];
    foreach ($userFields as $key => $value) $user[$key] = alapotAiDecodeFirestoreValue($value);
    $role = strtolower(trim((string)($user['role'] ?? '')));
    $active = $user['active'] ?? true;
    if (!in_array($role, ['patient', 'dentist', 'admin'], true) || $active !== true) {
        alapotAiRespond(['ok' => false, 'error' => 'This account does not have active Alapot AI access.'], 403);
    }
    if ($requiredRole !== null && $role !== $requiredRole) {
        alapotAiRespond(['ok' => false, 'error' => 'This Alapot AI endpoint is not available to your account role.'], 403);
    }
    if ($role === 'patient') {
        if (($firebaseUser['emailVerified'] ?? false) !== true) {
            alapotAiRespond(['ok' => false, 'error' => 'Verify your Firebase email before using Alapot AI.'], 403);
        }
        $patientId = trim((string)($user['patient_id'] ?? $user['patient_doc_id'] ?? ''));
        if ($patientId === '') alapotAiRespond(['ok' => false, 'error' => 'Your clinic Patient ID is not linked yet. Wait for Admin approval.'], 403);
        $patientResult = alapotAiHttp($firestoreBase . '/patients/' . rawurlencode($patientId), 'GET', null, $token, 15);
        $patientFields = $patientResult['data']['fields'] ?? [];
        $linkedUid = '';
        if (isset($patientFields['auth_uid'])) $linkedUid = (string)alapotAiDecodeFirestoreValue($patientFields['auth_uid']);
        if (!$patientResult['ok'] || $linkedUid !== $uid) {
            alapotAiRespond(['ok' => false, 'error' => 'Your clinic patient record is not linked to this account.'], 403);
        }
    }

    $apiKey = '';
    $privateConfigPath = dirname(__DIR__, 2) . DIRECTORY_SEPARATOR . 'alapot_private' . DIRECTORY_SEPARATOR . 'groq-config.php';
    if (is_file($privateConfigPath)) {
        $privateConfig = @include $privateConfigPath;
        if (is_array($privateConfig)) $apiKey = trim((string)($privateConfig['api_key'] ?? ''));
    }
    if ($apiKey === '') $apiKey = trim((string)getenv('ALAPOT_GROQ_API_KEY'));
    if ($apiKey === '') {
        alapotAiRespond(['ok' => false, 'error' => 'Alapot AI is not configured on the clinic server yet. The Admin portal must save a Groq API key in Alapot AI settings, or the server administrator must set ALAPOT_GROQ_API_KEY.'], 503);
    }

    $rawMessages = $payload['messages'] ?? [];
    if (!is_array($rawMessages) || count($rawMessages) < 1 || count($rawMessages) > 14) {
        alapotAiRespond(['ok' => false, 'error' => 'Send between 1 and 14 recent chat messages.'], 422);
    }
    $messages = [];
    $totalLength = 0;
    foreach ($rawMessages as $item) {
        if (!is_array($item)) continue;
        $messageRole = ($item['role'] ?? '') === 'assistant' ? 'assistant' : (($item['role'] ?? '') === 'user' ? 'user' : '');
        $content = trim((string)($item['content'] ?? ''));
        if ($messageRole === '' || $content === '') continue;
        if ((function_exists('mb_strlen') ? mb_strlen($content, 'UTF-8') : strlen($content)) > 3000) alapotAiRespond(['ok' => false, 'error' => 'A chat message is too long. Please keep each message under 3,000 characters.'], 422);
        $totalLength += function_exists('mb_strlen') ? mb_strlen($content, 'UTF-8') : strlen($content);
        $messages[] = ['role' => $messageRole, 'content' => $content];
    }
    if (!$messages || end($messages)['role'] !== 'user' || $totalLength > 12000) {
        alapotAiRespond(['ok' => false, 'error' => 'The conversation is empty or too long. Start a new question or shorten the history.'], 422);
    }

    $roleInstructions = [
        'patient' => 'You are Alapot AI, the Alapot Dental Clinic patient-portal assistant. Help patients understand app navigation, appointments, published clinic services, payment records, and general oral-health education. Do not diagnose, prescribe, recommend medication changes, or claim to read or change a patient record. Never invent appointments, fees, clinic hours, clinical notes, or staff decisions. For symptoms that may be urgent (difficulty breathing or swallowing, facial swelling with fever, uncontrolled bleeding, injury, or severe worsening pain), advise urgent in-person care and local emergency services for immediate danger. Be warm, concise, and clear. Do not ask for passwords, full government ID numbers, or payment-card details. You cannot approve account links or modify clinic data. If the patient\'s question needs a human clinic staff member to investigate, correct an account/billing/record issue, or provide a personal follow-up, append the exact marker [CREATE_TICKET] on a separate final line after your response. Do not use this marker for general dental education or portal navigation, and do not mention the marker in the response text.',
        'dentist' => 'You are Alapot AI for verified Alapot Dental Clinic dentists. The dentist portal assistant is question-and-answer only: explain general dental concepts, patient communication, clinic workflow, and software navigation. You have no tools and must never claim to access, write, update, diagnose, prescribe, approve, or change any patient record, appointment, consultation, chart, or payment. For patient-specific clinical decisions, tell the dentist to use professional judgement and the clinic record, not treat you as the source of truth. Do not invent patient data or clinic policy.',
        'admin' => 'You are Alapot AI for Alapot Dental Clinic administrators. Help with general portal navigation, administrative workflow, data-quality checks, and explanations of the clinic system. You have no tools and cannot execute actions or change records. Never invent patient details, appointment data, payments, announcements, or clinic policies. Recommend verifying any sensitive decision in the authoritative clinic record.',
    ];
    array_unshift($messages, ['role' => 'system', 'content' => $roleInstructions[$role]]);

    $model = trim((string)getenv('ALAPOT_GROQ_MODEL'));
    if ($model === '') $model = 'openai/gpt-oss-20b';
    $groq = alapotAiHttp('https://api.groq.com/openai/v1/chat/completions', 'POST', [
        'model' => $model,
        'messages' => $messages,
        'temperature' => 0.4,
        'max_completion_tokens' => 900,
    ], $apiKey, 45);
    if (!$groq['ok']) {
        $status = $groq['status'] === 429 ? 429 : 502;
        $message = $groq['status'] === 429
            ? 'Alapot AI is receiving too many requests. Please wait a moment and try again.'
            : 'Alapot AI could not reach the Groq service. Check the server configuration and try again.';
        alapotAiRespond(['ok' => false, 'error' => $message], $status);
    }
    $answer = trim((string)($groq['data']['choices'][0]['message']['content'] ?? ''));
    if ($answer === '') alapotAiRespond(['ok' => false, 'error' => 'Alapot AI returned an empty answer. Please try a different question.'], 502);

    $createTicket = $role === 'patient' && str_contains($answer, '[CREATE_TICKET]');
    $answer = trim(str_replace('[CREATE_TICKET]', '', $answer));
    alapotAiRespond(['ok' => true, 'answer' => $answer, 'create_ticket' => $createTicket, 'model' => $groq['data']['model'] ?? $model]);
}
