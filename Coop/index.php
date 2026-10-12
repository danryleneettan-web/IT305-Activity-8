<?php

require 'config.php';

if (isset($_SESSION['user'])) {
    redirect('dashboard.php');
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $action = $_POST['action'] ?? 'login';

        if ($action === 'register') {
            $firstName = trim($_POST['first_name'] ?? '');
            $lastName = trim($_POST['last_name'] ?? '');
            $email = trim($_POST['email'] ?? '');
            $password = $_POST['password'] ?? '';
            $confirmPassword = $_POST['confirm_password'] ?? '';

            if ($firstName === '' || $lastName === '' || $email === '' || $password === '') {
                throw new RuntimeException('All registration fields are required.');
            }

            if (strlen($password) < 8) {
                throw new RuntimeException('Password must be at least 8 characters long.');
            }

            if ($password !== $confirmPassword) {
                throw new RuntimeException('Passwords do not match.');
            }

            $auth = firebase_auth('accounts:signUp', [
                'email' => $email,
                'password' => $password,
                'returnSecureToken' => true,
            ]);

            $uid = $auth['localId'];
            $accountNumber = 'PUBLIC-' . strtoupper(substr($uid, 0, 8));
            $now = date('Y-m-d H:i:s');

            $memberData = [
                'id' => $uid,
                'accountNumber' => $accountNumber,
                'account_number' => $accountNumber,
                'authUid' => $uid,
                'email' => $email,
                'first_name' => $firstName,
                'firstName' => $firstName,
                'last_name' => $lastName,
                'lastName' => $lastName,
                'middle_name' => '',
                'middleName' => '',
                'extension_name' => '',
                'civil_status' => 'Single',
                'civilStatus' => 'Single',
                'address' => '',
                'contact_number' => '',
                'contactNumber' => '',
                'birthday' => '',
                'occupation' => '',
                'employer' => '',
                'employer_address' => '',
                'force_password_change' => false,
                'forcePasswordChange' => false,
                'children' => new stdClass(),
                'created_at' => $now,
                'updated_at' => $now,
            ];

            // Store in Firebase with member's auth token
            $_SESSION['user'] = [
                'role' => 'member',
                'id' => $accountNumber,
                'uid' => $uid,
                'idToken' => $auth['idToken'],
                'refreshToken' => $auth['refreshToken'],
                'expiresAt' => time() + (int)($auth['expiresIn'] ?? 3600),
                'name' => "$firstName $lastName",
                'force_change' => false,
            ];

            firebase_db_set("members/$uid", $memberData);

            flash('success', "Account created successfully! Your account number is $accountNumber.");
            redirect('dashboard.php');
        }

        $role = $_POST['role'] ?? 'member';

        if ($role === 'member') {
            $account = trim($_POST['account_number'] ?? '');
            $password = $_POST['password'] ?? '';

            if ($account === '' || $password === '') {
                throw new RuntimeException('Please enter your account number and password.');
            }

            $email = str_contains($account, '@') ? $account : $account . '@members.' . FIREBASE_AUTH_DOMAIN;
            $auth = firebase_auth('accounts:signInWithPassword', [
                'email' => $email,
                'password' => $password,
                'returnSecureToken' => true,
            ]);

            $_SESSION['user'] = [
                'role' => 'member',
                'id' => $account,
                'uid' => $auth['localId'],
                'idToken' => $auth['idToken'],
                'refreshToken' => $auth['refreshToken'],
                'expiresAt' => time() + (int)($auth['expiresIn'] ?? 3600),
                'name' => 'Cooperative Member',
                'force_change' => false,
            ];

            $member = member_by_id($account);
            if (!$member) {
                $member = member_by_id($auth['localId']);
            }

            if ($member) {
                $_SESSION['user']['id'] = $member['account_number'];
                $_SESSION['user']['name'] = trim($member['first_name'] . ' ' . $member['last_name']);
                $_SESSION['user']['force_change'] = (bool)($member['force_password_change'] ?? false);
            }
        } else {
            $username = trim($_POST['username'] ?? '');
            $password = $_POST['password'] ?? '';

            if ($username === '' || $password === '') {
                throw new RuntimeException('Please enter your staff username and password.');
            }

            $email = $username . '@staff.' . FIREBASE_AUTH_DOMAIN;
            $auth = firebase_auth('accounts:signInWithPassword', [
                'email' => $email,
                'password' => $password,
                'returnSecureToken' => true,
            ]);

            $claims = firebase_jwt_decode($auth['idToken']);
            if (($claims['role'] ?? '') !== 'staff') {
                throw new RuntimeException('This account does not have cooperative staff privileges.');
            }

            $_SESSION['user'] = [
                'role' => 'staff',
                'id' => $username,
                'uid' => $auth['localId'],
                'idToken' => $auth['idToken'],
                'refreshToken' => $auth['refreshToken'],
                'expiresAt' => time() + (int)($auth['expiresIn'] ?? 3600),
                'name' => 'Cooperative Administrator',
            ];
        }

        redirect('dashboard.php');
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

$showLogin = isset($_GET['login']) || $_SERVER['REQUEST_METHOD'] === 'POST';

if (!$showLogin):
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CoopConnect | Cooperative member portal</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="home-body">
    <header class="home-nav">
        <a class="brand-mini" href="index.php"><span class="nav-mark">CC</span><span>CoopConnect</span></a>
        <div style="display:inline-flex; align-items:center; gap:6px; font-size:12px; font-weight:600; color:#b55d82; background:#fff0f5; padding:4px 12px; border-radius:20px;">
            <span style="width:8px; height:8px; border-radius:50%; background:#22c55e; display:inline-block;"></span> Firebase RTDB Live
        </div>
        <nav class="home-links">
            <a href="index.php?login=1">Member Login</a>
            <a class="portal-link" href="index.php?login=1#staff">Staff Portal</a>
        </nav>
    </header>
    <main class="home-main">
        <section class="home-hero">
            <p class="eyebrow">Multipurpose cooperative</p>
            <h1>Your cooperative information,<br><em>clear and connected.</em></h1>
            <p class="hero-copy">CoopConnect makes it simple for members to keep their personal information current while giving staff a secure, organized records portal powered by Firebase.</p>
            <div class="hero-actions">
                <a class="button" href="index.php?login=1">Access your account</a>
                <a class="text-link" href="#features">Learn more &darr;</a>
            </div>
            <div class="home-stats">
                <div><strong>Cloud Realtime</strong><span>Firebase DB</span></div>
                <div><strong>Multiplatform</strong><span>Web &amp; Mobile</span></div>
                <div><strong>Organized</strong><span>Staff records</span></div>
            </div>
        </section>
        <aside class="hero-card">
            <div class="mini-logo">CC</div>
            <p class="eyebrow">Member portal</p>
            <h2>Keep your records up to date.</h2>
            <ul>
                <li>Update personal &amp; contact details</li>
                <li>Manage family information</li>
                <li>Answer cooperative surveys</li>
            </ul>
            <a class="button" href="index.php?login=1">Sign in to continue</a>
        </aside>
    </main>
    <section class="feature-row" id="features">
        <article><span>01</span><h3>For members</h3><p>Review and update your information anytime.</p></article>
        <article><span>02</span><h3>For staff</h3><p>Create accounts and manage cooperative records.</p></article>
        <article><span>03</span><h3>For everyone</h3><p>Realtime synchronization between Web and Mobile.</p></article>
    </section>
</body>
</html>
<?php
    exit;
endif;
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CoopConnect | Sign in</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="login-body">
    <main class="auth-card">
        <div class="brand">
            <a class="brand-mark" href="index.php" aria-label="Return to homepage">CC</a>
            <div>
                <h1>CoopConnect</h1>
                <p>Firebase-connected member portal</p>
            </div>
        </div>
        <?php if ($error): ?>
            <p class="alert error"><?= e($error) ?></p>
        <?php endif; ?>
        <?php if ($message = flash('success')): ?>
            <p class="alert success"><?= e($message) ?></p>
        <?php endif; ?>
        <div class="tabs">
            <button class="tab active" data-tab="member">Member</button>
            <button class="tab" data-tab="staff">Staff</button>
            <button class="tab" data-tab="register">Register</button>
        </div>
        <form method="post" id="member" class="login-form active">
            <input type="hidden" name="role" value="member">
            <label>Account number or Email
                <input name="account_number" required placeholder="Enter account number or email">
            </label>
            <label>Password
                <span class="password-input">
                    <input type="password" name="password" required placeholder="Enter password">
                    <button class="password-toggle" type="button" data-password-toggle="member" aria-label="Show password" title="Show password">
                        <svg viewBox="0 0 24 24" aria-hidden="true">
                            <path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6Z"/>
                            <circle cx="12" cy="12" r="2.8"/>
                        </svg>
                    </button>
                </span>
            </label>
            <button>Sign in as member</button>
            <p class="hint">Demo account: <strong>2026-0002</strong> / password: <strong>2026-0002</strong></p>
        </form>
        <form method="post" id="staff" class="login-form">
            <input type="hidden" name="role" value="staff">
            <label>Username
                <input name="username" required placeholder="Enter username">
            </label>
            <label>Password
                <span class="password-input">
                    <input type="password" name="password" required placeholder="Enter password">
                    <button class="password-toggle" type="button" data-password-toggle="staff" aria-label="Show password" title="Show password">
                        <svg viewBox="0 0 24 24" aria-hidden="true">
                            <path d="M2.5 12s3.5-6 9.5-6 9.5 6 9.5 6-3.5 6-9.5 6-9.5-6Z"/>
                            <circle cx="12" cy="12" r="2.8"/>
                        </svg>
                    </button>
                </span>
            </label>
            <button>Sign in as staff</button>
            <p class="hint">Staff login: <strong>admin</strong> / password: <strong>password</strong></p>
        </form>
        <form method="post" id="register" class="login-form">
            <input type="hidden" name="action" value="register">
            <div class="two-col">
                <label>First name
                    <input name="first_name" required placeholder="First name">
                </label>
                <label>Last name
                    <input name="last_name" required placeholder="Last name">
                </label>
            </div>
            <label>Email address
                <input type="email" name="email" required placeholder="you@example.com">
            </label>
            <div class="two-col">
                <label>Password
                    <input type="password" name="password" required minlength="8" placeholder="At least 8 chars">
                </label>
                <label>Confirm password
                    <input type="password" name="confirm_password" required minlength="8" placeholder="Repeat password">
                </label>
            </div>
            <button>Create member account</button>
            <p class="hint">Registers directly into Firebase Authentication and Realtime Database.</p>
        </form>
    </main>
    <script src="assets/app.js"></script>
</body>
</html>