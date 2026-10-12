<?php

declare(strict_types=1);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
date_default_timezone_set('Asia/Manila');

// -------------------------------------------------------------
// Firebase Configuration
// Connects PHP directly to Firebase Realtime Database and Auth
// -------------------------------------------------------------
const USE_FIREBASE = true;
const FIREBASE_PROJECT_ID = 'coop-692bf';
const FIREBASE_API_KEY = 'AIzaSyB9fLFhHZT75mbuMu_RmX0PwmNjlyxoBKw';
const FIREBASE_DB_URL = 'https://coop-692bf-default-rtdb.firebaseio.com/cooperative_portal';
const FIREBASE_AUTH_DOMAIN = 'coop-692bf.firebaseapp.com';
const FIREBASE_IDENTITY_API = 'https://identitytoolkit.googleapis.com/v1';
const FIREBASE_TOKEN_API = 'https://securetoken.googleapis.com/v1/token';

// Optional legacy MySQL constants (for fallback if needed)
const DB_HOST = 'localhost';
const DB_NAME = 'cooperative_portal';
const DB_USER = 'root';
const DB_PASS = '';

function db(): PDO
{
    static $pdo = null;

    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            ]
        );
        $pdo->exec("SET time_zone = '+08:00'");
    }

    return $pdo;
}

// -------------------------------------------------------------
// Firebase HTTP & REST Helpers
// -------------------------------------------------------------
function firebase_request(string $url, string $method = 'GET', $data = null): array
{
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
    curl_setopt($ch, CURLOPT_TIMEOUT, 15);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);

    if ($data !== null) {
        $json = is_string($data) ? $data : json_encode($data);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $json);
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    }

    $response = curl_exec($ch);
    $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    curl_close($ch);

    if ($error) {
        throw new RuntimeException("Firebase network error: $error");
    }

    $decoded = json_decode((string)$response, true);
    return ['status' => $status, 'data' => $decoded, 'raw' => $response];
}

function firebase_jwt_decode(string $token): array
{
    $parts = explode('.', $token);
    if (count($parts) !== 3) {
        return [];
    }
    $payload = str_replace(['-', '_'], ['+', '/'], $parts[1]);
    $payload .= str_repeat('=', (4 - strlen($payload) % 4) % 4);
    return json_decode(base64_decode($payload), true) ?: [];
}

function firebase_auth(string $endpoint, array $payload): array
{
    $url = FIREBASE_IDENTITY_API . '/' . $endpoint . '?key=' . FIREBASE_API_KEY;
    $res = firebase_request($url, 'POST', $payload);

    if ($res['status'] !== 200) {
        $msg = $res['data']['error']['message'] ?? 'Authentication failed';
        if (in_array($msg, ['INVALID_LOGIN_CREDENTIALS', 'EMAIL_NOT_FOUND', 'INVALID_PASSWORD'], true)) {
            throw new RuntimeException('Invalid credentials. Check your account details and password.');
        }
        if ($msg === 'EMAIL_EXISTS') {
            throw new RuntimeException('An account with this email address already exists.');
        }
        if ($msg === 'OPERATION_NOT_ALLOWED') {
            throw new RuntimeException('Email/password sign-in is not enabled for this project.');
        }
        throw new RuntimeException('Firebase authentication error: ' . $msg);
    }

    return $res['data'] ?? [];
}

function firebase_token(): string
{
    if (empty($_SESSION['user']['idToken'])) {
        // Fallback: if session doesn't have an ID token, return empty string
        return '';
    }

    $expiresAt = (int)($_SESSION['user']['expiresAt'] ?? 0);
    // Refresh 2 minutes before expiry
    if (time() >= ($expiresAt - 120) && !empty($_SESSION['user']['refreshToken'])) {
        $url = FIREBASE_TOKEN_API . '?key=' . FIREBASE_API_KEY;
        $ch = curl_init($url);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
            'grant_type' => 'refresh_token',
            'refresh_token' => $_SESSION['user']['refreshToken'],
        ]));
        curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);
        $resp = curl_exec($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        if ($status === 200) {
            $data = json_decode((string)$resp, true);
            if (!empty($data['id_token'])) {
                $_SESSION['user']['idToken'] = $data['id_token'];
                $_SESSION['user']['refreshToken'] = $data['refresh_token'] ?? $_SESSION['user']['refreshToken'];
                $_SESSION['user']['expiresAt'] = time() + (int)($data['expires_in'] ?? 3600);
            }
        }
    }

    return (string)$_SESSION['user']['idToken'];
}

function firebase_db_url(string $path): string
{
    $clean = trim($path, '/');
    $url = FIREBASE_DB_URL . ($clean !== '' ? '/' . $clean : '') . '.json';
    $token = firebase_token();
    if ($token !== '') {
        $url .= '?auth=' . urlencode($token);
    }
    return $url;
}

function firebase_db_get(string $path)
{
    $res = firebase_request(firebase_db_url($path), 'GET');
    if ($res['status'] === 401 || $res['status'] === 403) {
        throw new RuntimeException('Firebase permission denied for path: ' . $path);
    }
    return $res['data'];
}

function firebase_db_set(string $path, $data)
{
    $res = firebase_request(firebase_db_url($path), 'PUT', $data);
    if ($res['status'] >= 400) {
        throw new RuntimeException('Firebase write failed (' . $res['status'] . ') for path: ' . $path);
    }
    return $res['data'];
}

function firebase_db_update(string $path, array $data)
{
    $res = firebase_request(firebase_db_url($path), 'PATCH', $data);
    if ($res['status'] >= 400) {
        throw new RuntimeException('Firebase update failed (' . $res['status'] . ') for path: ' . $path);
    }
    return $res['data'];
}

function firebase_db_delete(string $path)
{
    $res = firebase_request(firebase_db_url($path), 'DELETE');
    if ($res['status'] >= 400) {
        throw new RuntimeException('Firebase delete failed (' . $res['status'] . ') for path: ' . $path);
    }
    return true;
}

// -------------------------------------------------------------
// Data Normalization Helpers
// Ensures seamless compatibility with both MySQL legacy code
// and Firebase Realtime Database structures.
// -------------------------------------------------------------
function normalize_member(array $m, string $key = ''): array
{
    $accountNumber = $m['accountNumber'] ?? $m['account_number'] ?? $key;
    $id = $m['id'] ?? $accountNumber;
    $firstName = $m['firstName'] ?? $m['first_name'] ?? '';
    $lastName = $m['lastName'] ?? $m['last_name'] ?? '';
    $middleName = $m['middleName'] ?? $m['middle_name'] ?? '';
    $extensionName = $m['extensionName'] ?? $m['extension_name'] ?? '';
    $civilStatus = $m['civilStatus'] ?? $m['civil_status'] ?? 'Single';
    $address = $m['address'] ?? '';
    $contactNumber = $m['contactNumber'] ?? $m['contact_number'] ?? '';
    $birthday = $m['birthday'] ?? '';
    $occupation = $m['occupation'] ?? '';
    $employer = $m['employer'] ?? '';
    $employerAddress = $m['employerAddress'] ?? $m['employer_address'] ?? '';
    $spouseName = $m['spouseName'] ?? $m['spouse_name'] ?? '';
    $spouseOccupation = $m['spouseOccupation'] ?? $m['spouse_occupation'] ?? '';
    $spouseEmployer = $m['spouseEmployer'] ?? $m['spouse_employer'] ?? '';
    $fatherName = $m['fatherName'] ?? $m['father_name'] ?? '';
    $motherName = $m['motherName'] ?? $m['mother_name'] ?? '';
    $referenceOne = $m['referenceOne'] ?? $m['reference_one'] ?? '';
    $referenceTwo = $m['referenceTwo'] ?? $m['reference_two'] ?? '';
    $photo = $m['photo'] ?? '';
    $forceChange = (bool)($m['forcePasswordChange'] ?? $m['force_password_change'] ?? false);
    $authUid = $m['authUid'] ?? $m['auth_uid'] ?? '';
    $createdAt = $m['createdAt'] ?? $m['created_at'] ?? date('Y-m-d H:i:s');
    $updatedAt = $m['updatedAt'] ?? $m['updated_at'] ?? $createdAt;

    $children = [];
    if (!empty($m['children']) && is_array($m['children'])) {
        foreach ($m['children'] as $ck => $cv) {
            $children[] = [
                'id' => $ck,
                'child_name' => $cv['name'] ?? $cv['child_name'] ?? '',
                'age' => (int)($cv['age'] ?? 0),
            ];
        }
    }

    return [
        'id' => $id,
        'account_number' => $accountNumber,
        'accountNumber' => $accountNumber,
        'first_name' => $firstName,
        'firstName' => $firstName,
        'last_name' => $lastName,
        'lastName' => $lastName,
        'middle_name' => $middleName,
        'middleName' => $middleName,
        'extension_name' => $extensionName,
        'extensionName' => $extensionName,
        'civil_status' => $civilStatus,
        'civilStatus' => $civilStatus,
        'address' => $address,
        'contact_number' => $contactNumber,
        'contactNumber' => $contactNumber,
        'birthday' => $birthday,
        'occupation' => $occupation,
        'employer' => $employer,
        'employer_address' => $employerAddress,
        'employerAddress' => $employerAddress,
        'spouse_name' => $spouseName,
        'spouseName' => $spouseName,
        'spouse_occupation' => $spouseOccupation,
        'spouseOccupation' => $spouseOccupation,
        'spouse_employer' => $spouseEmployer,
        'spouseEmployer' => $spouseEmployer,
        'father_name' => $fatherName,
        'fatherName' => $fatherName,
        'mother_name' => $motherName,
        'motherName' => $motherName,
        'reference_one' => $referenceOne,
        'referenceOne' => $referenceOne,
        'reference_two' => $referenceTwo,
        'referenceTwo' => $referenceTwo,
        'photo' => $photo,
        'force_password_change' => $forceChange,
        'forcePasswordChange' => $forceChange,
        'authUid' => $authUid,
        'created_at' => $createdAt,
        'createdAt' => $createdAt,
        'updated_at' => $updatedAt,
        'updatedAt' => $updatedAt,
        'children' => $children,
    ];
}

function normalize_survey(array $s, string $key = ''): array
{
    $id = $s['id'] ?? $key;
    $title = $s['title'] ?? '';
    $description = $s['description'] ?? '';
    $status = $s['status'] ?? 'draft';
    $opensAt = $s['opensAt'] ?? $s['opens_at'] ?? '';
    $closesAt = $s['closesAt'] ?? $s['closes_at'] ?? '';
    $createdBy = $s['createdBy'] ?? $s['created_by'] ?? '';
    $createdAt = $s['createdAt'] ?? $s['created_at'] ?? date('Y-m-d H:i:s');
    $updatedAt = $s['updatedAt'] ?? $s['updated_at'] ?? $createdAt;

    $questions = [];
    if (!empty($s['questions']) && is_array($s['questions'])) {
        foreach ($s['questions'] as $qk => $qv) {
            $choices = [];
            if (!empty($qv['choices']) && is_array($qv['choices'])) {
                foreach ($qv['choices'] as $c) {
                    $choices[] = is_array($c) ? ($c['choice_text'] ?? $c['text'] ?? '') : (string)$c;
                }
            }
            $questions[] = [
                'id' => $qv['id'] ?? $qk,
                'survey_id' => $id,
                'question_text' => $qv['text'] ?? $qv['question_text'] ?? '',
                'question_type' => $qv['type'] ?? $qv['question_type'] ?? 'short_answer',
                'is_required' => (bool)($qv['isRequired'] ?? $qv['is_required'] ?? true),
                'sort_order' => (int)($qv['order'] ?? $qv['sort_order'] ?? 0),
                'choices' => $choices,
            ];
        }
    }

    return [
        'id' => $id,
        'title' => $title,
        'description' => $description,
        'status' => $status,
        'opens_at' => $opensAt,
        'closes_at' => $closesAt,
        'opensAt' => $opensAt,
        'closesAt' => $closesAt,
        'created_by' => $createdBy,
        'created_at' => $createdAt,
        'updated_at' => $updatedAt,
        'questions' => $questions,
    ];
}

// -------------------------------------------------------------
// Application Functions
// -------------------------------------------------------------
function member_by_id($id): array|false
{
    if (!USE_FIREBASE) {
        $stmt = db()->prepare('SELECT * FROM members WHERE id = ?');
        $stmt->execute([(int)$id]);
        return $stmt->fetch();
    }

    $idStr = (string)$id;
    try {
        $data = firebase_db_get('members/' . urlencode($idStr));
        if (is_array($data)) {
            return normalize_member($data, $idStr);
        }

        // If not directly found by key, search in all members
        $all = firebase_db_get('members');
        if (is_array($all)) {
            foreach ($all as $k => $item) {
                if (!is_array($item)) continue;
                if (
                    (string)($item['account_number'] ?? '') === $idStr ||
                    (string)($item['accountNumber'] ?? '') === $idStr ||
                    (string)($item['id'] ?? '') === $idStr ||
                    (string)($item['authUid'] ?? '') === $idStr
                ) {
                    return normalize_member($item, (string)$k);
                }
            }
        }
    } catch (Throwable $e) {
        // Fallback / log error
    }

    return false;
}

function member_children($id): array
{
    if (!USE_FIREBASE) {
        $stmt = db()->prepare('SELECT * FROM children WHERE member_id = ? ORDER BY id');
        $stmt->execute([(int)$id]);
        return $stmt->fetchAll();
    }

    $m = member_by_id($id);
    return $m['children'] ?? [];
}

function members_all(): array
{
    if (!USE_FIREBASE) {
        return db()->query('SELECT * FROM members ORDER BY updated_at DESC')->fetchAll();
    }

    $all = firebase_db_get('members') ?: [];
    $result = [];
    foreach ($all as $k => $m) {
        if (is_array($m)) {
            $result[] = normalize_member($m, (string)$k);
        }
    }

    usort($result, function ($a, $b) {
        return strtotime($b['updated_at'] ?? '0') <=> strtotime($a['updated_at'] ?? '0');
    });

    return $result;
}

function surveys_all(): array
{
    if (!USE_FIREBASE) {
        return db()->query('SELECT s.*, COUNT(DISTINCT ss.id) respondents FROM surveys s LEFT JOIN survey_submissions ss ON ss.survey_id=s.id GROUP BY s.id ORDER BY s.updated_at DESC')->fetchAll();
    }

    $surveysData = firebase_db_get('surveys') ?: [];
    $submissionsData = firebase_db_get('survey_submissions') ?: [];

    $counts = [];
    foreach ($submissionsData as $sub) {
        if (!is_array($sub)) continue;
        $sId = $sub['surveyId'] ?? $sub['survey_id'] ?? '';
        if ($sId !== '') {
            $counts[$sId] = ($counts[$sId] ?? 0) + 1;
        }
    }

    $result = [];
    foreach ($surveysData as $k => $s) {
        if (!is_array($s)) continue;
        $norm = normalize_survey($s, (string)$k);
        $norm['respondents'] = $counts[$norm['id']] ?? 0;
        $result[] = $norm;
    }

    usort($result, function ($a, $b) {
        return strtotime($b['updated_at'] ?? '0') <=> strtotime($a['updated_at'] ?? '0');
    });

    return $result;
}

function survey_by_id(string $id): array|false
{
    if (!USE_FIREBASE) {
        $stmt = db()->prepare('SELECT * FROM surveys WHERE id = ?');
        $stmt->execute([(int)$id]);
        return $stmt->fetch();
    }

    try {
        $s = firebase_db_get('surveys/' . urlencode($id));
        if (is_array($s)) {
            return normalize_survey($s, $id);
        }
        $all = surveys_all();
        foreach ($all as $item) {
            if ($item['id'] === $id) return $item;
        }
    } catch (Throwable $e) {}

    return false;
}

function valid_contact_number(string $number): bool
{
    return (bool)preg_match('/^\d{11}$/', $number);
}

function survey_is_active(array $survey): bool
{
    $now = date('Y-m-d H:i:s');
    return ($survey['status'] ?? '') === 'active' && ($survey['opens_at'] ?? '') <= $now && ($survey['closes_at'] ?? '') >= $now;
}

function e(?string $value): string
{
    return htmlspecialchars((string)$value, ENT_QUOTES, 'UTF-8');
}

function redirect(string $path): never
{
    header('Location: ' . $path);
    exit;
}

function flash(string $key, ?string $message = null): ?string
{
    if ($message !== null) {
        $_SESSION['flash'][$key] = $message;
        return null;
    }

    $value = $_SESSION['flash'][$key] ?? null;
    unset($_SESSION['flash'][$key]);

    return $value;
}

function require_login(?string $role = null): void
{
    if (!isset($_SESSION['user'])) {
        redirect('index.php');
    }

    if ($role !== null && $_SESSION['user']['role'] !== $role) {
        redirect('dashboard.php');
    }
}

function save_photo(?array $file, ?string $old = null): ?string
{
    if (!$file || $file['error'] === UPLOAD_ERR_NO_FILE) {
        return $old;
    }

    if ($file['error'] !== UPLOAD_ERR_OK || $file['size'] > 2 * 1024 * 1024) {
        throw new RuntimeException('Photo must be an image under 2 MB.');
    }

    $type = mime_content_type($file['tmp_name']);
    $extensions = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];

    if (!isset($extensions[$type])) {
        throw new RuntimeException('Use a JPG, PNG, or WebP image.');
    }

    $name = bin2hex(random_bytes(12)) . '.' . $extensions[$type];

    if (!is_dir(__DIR__ . '/uploads')) {
        mkdir(__DIR__ . '/uploads', 0777, true);
    }

    if (!move_uploaded_file($file['tmp_name'], __DIR__ . '/uploads/' . $name)) {
        throw new RuntimeException('Could not save the photo.');
    }

    if ($old && is_file(__DIR__ . '/uploads/' . $old)) {
        unlink(__DIR__ . '/uploads/' . $old);
    }

    return $name;
}
