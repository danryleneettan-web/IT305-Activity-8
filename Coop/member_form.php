<?php

require 'config.php';
require_login('staff');

$id = trim($_GET['id'] ?? '');
$member = $id !== '' ? member_by_id($id) : false;
$error = '';

function next_account_number(): string {
    $members = members_all();
    $maxNum = 20260000;
    foreach ($members as $m) {
        $acc = preg_replace('/[^0-9]/', '', $m['account_number'] ?? '');
        if (str_starts_with($acc, '2026') && strlen($acc) === 8) {
            $num = (int)$acc;
            if ($num > $maxNum) {
                $maxNum = $num;
            }
        }
    }
    $next = $maxNum + 1;
    return substr((string)$next, 0, 4) . '-' . substr((string)$next, 4);
}

$fields = [
    'account_number', 'last_name', 'first_name', 'middle_name', 'extension_name',
    'civil_status', 'address', 'contact_number', 'birthday', 'occupation', 'employer',
    'employer_address', 'spouse_name', 'spouse_occupation', 'spouse_employer',
    'father_name', 'mother_name', 'reference_one', 'reference_two',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $id = trim($_POST['id'] ?? '');

        if ($id === '') {
            $_POST['account_number'] = next_account_number();
        }

        $required = ['account_number', 'last_name', 'first_name', 'civil_status', 'address', 'contact_number', 'birthday'];

        foreach ($required as $f) {
            if (trim($_POST[$f] ?? '') === '') {
                throw new RuntimeException('Please complete all required fields.');
            }
        }

        if (!valid_contact_number(trim($_POST['contact_number'] ?? ''))) {
            throw new RuntimeException('Contact number must contain exactly 11 digits.');
        }

        $hasFamilyDetails = ($_POST['civil_status'] ?? '') !== 'Single';
        if (!$hasFamilyDetails) {
            $_POST['spouse_name'] = '';
            $_POST['spouse_occupation'] = '';
            $_POST['spouse_employer'] = '';
            $_POST['child_name'] = [];
            $_POST['child_age'] = [];
        }

        $accountNumber = trim($_POST['account_number']);
        $now = date('Y-m-d H:i:s');

        // Build children map
        $childrenMap = [];
        $childIndex = 1;
        foreach ($_POST['child_name'] ?? [] as $index => $name) {
            if (trim($name) !== '') {
                $childrenMap['child_' . $childIndex] = [
                    'name' => trim($name),
                    'child_name' => trim($name),
                    'age' => max(0, (int)($_POST['child_age'][$index] ?? 0)),
                ];
                $childIndex++;
            }
        }

        // If new member, provision Auth account
        $authUid = '';
        if ($id === '') {
            $email = $accountNumber . '@members.' . FIREBASE_AUTH_DOMAIN;
            try {
                $auth = firebase_auth('accounts:signUp', [
                    'email' => $email,
                    'password' => $accountNumber,
                    'returnSecureToken' => true,
                ]);
                $authUid = $auth['localId'] ?? '';
            } catch (Throwable $e) {
                // If account exists already, keep going
                $authUid = 'member_' . str_replace('-', '_', $accountNumber);
            }
        } else {
            $authUid = $member['authUid'] ?? ('member_' . str_replace('-', '_', $accountNumber));
        }

        $memberRecord = [
            'id' => $accountNumber,
            'accountNumber' => $accountNumber,
            'account_number' => $accountNumber,
            'authUid' => $authUid,
            'last_name' => trim($_POST['last_name']),
            'lastName' => trim($_POST['last_name']),
            'first_name' => trim($_POST['first_name']),
            'firstName' => trim($_POST['first_name']),
            'middle_name' => trim($_POST['middle_name'] ?? ''),
            'middleName' => trim($_POST['middle_name'] ?? ''),
            'extension_name' => trim($_POST['extension_name'] ?? ''),
            'extensionName' => trim($_POST['extension_name'] ?? ''),
            'civil_status' => trim($_POST['civil_status']),
            'civilStatus' => trim($_POST['civil_status']),
            'address' => trim($_POST['address']),
            'contact_number' => trim($_POST['contact_number']),
            'contactNumber' => trim($_POST['contact_number']),
            'birthday' => trim($_POST['birthday']),
            'occupation' => trim($_POST['occupation'] ?? ''),
            'employer' => trim($_POST['employer'] ?? ''),
            'employer_address' => trim($_POST['employer_address'] ?? ''),
            'employerAddress' => trim($_POST['employer_address'] ?? ''),
            'spouse_name' => trim($_POST['spouse_name'] ?? ''),
            'spouseName' => trim($_POST['spouse_name'] ?? ''),
            'spouse_occupation' => trim($_POST['spouse_occupation'] ?? ''),
            'spouseOccupation' => trim($_POST['spouse_occupation'] ?? ''),
            'spouse_employer' => trim($_POST['spouse_employer'] ?? ''),
            'spouseEmployer' => trim($_POST['spouse_employer'] ?? ''),
            'father_name' => trim($_POST['father_name'] ?? ''),
            'fatherName' => trim($_POST['father_name'] ?? ''),
            'mother_name' => trim($_POST['mother_name'] ?? ''),
            'motherName' => trim($_POST['mother_name'] ?? ''),
            'reference_one' => trim($_POST['reference_one'] ?? ''),
            'referenceOne' => trim($_POST['reference_one'] ?? ''),
            'reference_two' => trim($_POST['reference_two'] ?? ''),
            'referenceTwo' => trim($_POST['reference_two'] ?? ''),
            'photo' => $member['photo'] ?? '',
            'force_password_change' => ($id === ''),
            'forcePasswordChange' => ($id === ''),
            'children' => !empty($childrenMap) ? $childrenMap : new stdClass(),
            'created_at' => $member['created_at'] ?? $now,
            'createdAt' => $member['created_at'] ?? $now,
            'updated_at' => $now,
            'updatedAt' => $now,
        ];

        firebase_db_set("members/$accountNumber", $memberRecord);

        $success = $id !== '' ? 'Member updated in Firebase.' : 'Member added to Firebase; default password is the account number.';
        flash('success', $success);
        redirect('members.php');
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

$m = $member ?: array_fill_keys(['id', ...$fields], '');
if (!$member) {
    $m['account_number'] = next_account_number();
}
$children = $member ? member_children($member['id']) : [];

$requiredFields = ['account_number', 'last_name', 'first_name', 'civil_status', 'contact_number', 'birthday'];
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title><?= $id ? 'Edit' : 'Add' ?> member | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="staff-page">
    <?php require 'staff_sidebar.php'; ?>
    <header class="staff-side-header">
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="members.php">Members</a>
            <a href="surveys.php">Surveys</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container form-wrap">
        <h1><?= $id ? 'Edit' : 'Add new' ?> member</h1>

        <?php if ($error): ?>
            <p class="alert error"><?= e($error) ?></p>
        <?php endif; ?>

        <form method="post" class="card">
            <input type="hidden" name="id" value="<?= e((string)$m['id']) ?>">
            <section class="form-section">
                <h2>Member information &middot; Firebase Connected</h2>
                <div class="two-col">
                    <label>Account number
                        <input name="account_number" value="<?= e($m['account_number']) ?>" <?= $id !== '' ? 'readonly' : '' ?> required>
                    </label>
                    <label>Civil status
                        <select name="civil_status" data-civil-status required>
                            <?php foreach (['Single', 'Married', 'Widowed', 'Separated'] as $status): ?>
                                <option value="<?= $status ?>" <?= ($m['civil_status'] ?? '') === $status ? 'selected' : '' ?>><?= $status ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label>Last name<input name="last_name" value="<?= e($m['last_name']) ?>" required></label>
                    <label>First name<input name="first_name" value="<?= e($m['first_name']) ?>" required></label>
                    <label>Middle name<input name="middle_name" value="<?= e($m['middle_name']) ?>"></label>
                    <label>Extension name<input name="extension_name" value="<?= e($m['extension_name']) ?>"></label>
                    <label>Birthday<input name="birthday" type="date" value="<?= e($m['birthday']) ?>" required></label>
                    <label>Contact number
                        <input name="contact_number" type="tel" inputmode="numeric" pattern="[0-9]{11}" maxlength="11" data-contact-number value="<?= e($m['contact_number']) ?>" placeholder="09XXXXXXXXX" required>
                    </label>
                    <label>Occupation<input name="occupation" value="<?= e($m['occupation']) ?>"></label>
                    <label>Employer<input name="employer" value="<?= e($m['employer']) ?>"></label>
                    <label>Employer address<input name="employer_address" value="<?= e($m['employer_address']) ?>"></label>
                </div>
                <label>Home address
                    <textarea name="address" required><?= e($m['address'] ?? '') ?></textarea>
                </label>
            </section>
            <section class="form-section" data-family-section>
                <h2>Spouse information</h2>
                <div class="two-col">
                    <label>Spouse name<input name="spouse_name" value="<?= e($m['spouse_name']) ?>"></label>
                    <label>Spouse occupation<input name="spouse_occupation" value="<?= e($m['spouse_occupation']) ?>"></label>
                    <label>Spouse employer<input name="spouse_employer" value="<?= e($m['spouse_employer']) ?>"></label>
                </div>
            </section>
            <section class="form-section" data-family-section>
                <h2>Children</h2>
                <div id="children">
                    <?php foreach ($children as $child): ?>
                        <div class="child-row">
                            <input name="child_name[]" placeholder="Child name" value="<?= e($child['child_name']) ?>">
                            <input name="child_age[]" type="number" min="0" placeholder="Age" value="<?= e((string)$child['age']) ?>">
                            <button type="button" class="remove">Remove</button>
                        </div>
                    <?php endforeach; ?>
                </div>
                <button type="button" class="button secondary" id="add-child">Add child</button>
            </section>
            <section class="form-section">
                <h2>Parents &amp; cooperative references</h2>
                <div class="two-col">
                    <label>Father's name<input name="father_name" value="<?= e($m['father_name']) ?>"></label>
                    <label>Mother's name<input name="mother_name" value="<?= e($m['mother_name']) ?>"></label>
                    <label>Reference 1<input name="reference_one" value="<?= e($m['reference_one']) ?>"></label>
                    <label>Reference 2<input name="reference_two" value="<?= e($m['reference_two']) ?>"></label>
                </div>
            </section>
            <button>Save member</button>
            <a class="button secondary" href="members.php">Cancel</a>
        </form>
    </main>
    <script src="assets/app.js?v=20260822-family-fields"></script>
</body>
</html>
