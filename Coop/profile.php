<?php

require 'config.php';
require_login('member');

$user = $_SESSION['user'];
$member = member_by_id($user['id']);
if (!$member && !empty($user['uid'])) {
    $member = member_by_id($user['uid']);
}
if (!$member) {
    redirect('logout.php');
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        if (isset($_POST['new_password'])) {
            $newPassword = $_POST['new_password'];
            $confirmPassword = $_POST['confirm_password'] ?? '';

            if (strlen($newPassword) < 8) {
                throw new RuntimeException('New password must have at least 8 characters.');
            }

            if ($newPassword !== $confirmPassword) {
                throw new RuntimeException('Passwords do not match.');
            }

            // Update password in Firebase Auth
            $updatedAuth = firebase_auth('accounts:update', [
                'idToken' => firebase_token(),
                'password' => $newPassword,
                'returnSecureToken' => true,
            ]);

            if (!empty($updatedAuth['idToken'])) {
                $_SESSION['user']['idToken'] = $updatedAuth['idToken'];
                $_SESSION['user']['refreshToken'] = $updatedAuth['refreshToken'] ?? $_SESSION['user']['refreshToken'];
            }

            // Update force_password_change in Firebase RTDB
            $accNum = $member['account_number'];
            firebase_db_update("members/$accNum", [
                'forcePasswordChange' => false,
                'force_password_change' => false,
                'updatedAt' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s'),
            ]);

            $_SESSION['user']['force_change'] = false;
            flash('success', 'Password changed successfully in Firebase.');
            redirect('profile.php');
        }

        $required = [
            'last_name' => 'Last name',
            'first_name' => 'First name',
            'civil_status' => 'Civil status',
            'address' => 'Address',
            'contact_number' => 'Contact number',
            'birthday' => 'Birthday',
        ];

        foreach ($required as $field => $label) {
            if (trim($_POST[$field] ?? '') === '') {
                throw new RuntimeException("$label is required.");
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

        $photo = save_photo($_FILES['photo'] ?? null, $member['photo'] ?? null);

        // Build children map
        $childrenMap = [];
        $childIndex = 1;
        foreach ($_POST['child_name'] ?? [] as $i => $name) {
            if (trim($name) !== '') {
                $childrenMap['child_' . $childIndex] = [
                    'name' => trim($name),
                    'child_name' => trim($name),
                    'age' => max(0, (int)($_POST['child_age'][$i] ?? 0)),
                ];
                $childIndex++;
            }
        }

        $accNum = $member['account_number'];
        $now = date('Y-m-d H:i:s');

        $updatedRecord = [
            'id' => $accNum,
            'accountNumber' => $accNum,
            'account_number' => $accNum,
            'authUid' => $member['authUid'] ?? ($user['uid'] ?? ''),
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
            'photo' => $photo ?: ($member['photo'] ?? ''),
            'force_password_change' => false,
            'forcePasswordChange' => false,
            'children' => !empty($childrenMap) ? $childrenMap : new stdClass(),
            'created_at' => $member['created_at'] ?? $now,
            'createdAt' => $member['created_at'] ?? $now,
            'updated_at' => $now,
            'updatedAt' => $now,
        ];

        firebase_db_set("members/$accNum", $updatedRecord);

        $_SESSION['user']['name'] = trim($_POST['first_name'] . ' ' . $_POST['last_name']);
        flash('success', 'Your member information was updated in Firebase in real time.');
        redirect('profile.php');
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}

$children = member_children($member['id']);
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>My profile | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
    <header>
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="dashboard.php">Dashboard</a>
            <a href="member_surveys.php">Surveys</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container form-wrap">
        <h1>My member profile &middot; Firebase Connected</h1>

        <?php if ($msg = flash('success')): ?>
            <p class="alert success"><?= e($msg) ?></p>
        <?php endif; ?>
        <?php if ($error): ?>
            <p class="alert error"><?= e($error) ?></p>
        <?php endif; ?>

        <?php if (isset($_GET['password'])): ?>
            <section class="card">
                <h2>Change your default password</h2>
                <form method="post" class="two-col">
                    <label>New password
                        <input type="password" name="new_password" required minlength="8">
                    </label>
                    <label>Confirm password
                        <input type="password" name="confirm_password" required minlength="8">
                    </label>
                    <button>Save new password</button>
                </form>
            </section>
        <?php endif; ?>

        <form method="post" enctype="multipart/form-data" class="card">
            <section class="form-section">
                <h2>Personal information</h2>
                <div class="two-col">
                    <label>Account number
                        <input value="<?= e($member['account_number']) ?>" disabled>
                    </label>
                    <label>Photo
                        <input type="file" name="photo" accept="image/png,image/jpeg,image/webp">
                    </label>
                    <label>Last name
                        <input name="last_name" required value="<?= e($member['last_name']) ?>">
                    </label>
                    <label>First name
                        <input name="first_name" required value="<?= e($member['first_name']) ?>">
                    </label>
                    <label>Middle name
                        <input name="middle_name" value="<?= e($member['middle_name']) ?>">
                    </label>
                    <label>Extension name
                        <input name="extension_name" value="<?= e($member['extension_name']) ?>">
                    </label>
                    <label>Civil status
                        <select name="civil_status" data-civil-status required>
                            <?php foreach (['Single', 'Married', 'Widowed', 'Separated'] as $s): ?>
                                <option <?= ($member['civil_status'] ?? '') === $s ? 'selected' : '' ?>><?= $s ?></option>
                            <?php endforeach; ?>
                        </select>
                    </label>
                    <label>Birthday
                        <input type="date" name="birthday" required value="<?= e($member['birthday']) ?>">
                    </label>
                    <label>Contact number
                        <input name="contact_number" type="tel" inputmode="numeric" pattern="[0-9]{11}" maxlength="11" data-contact-number required value="<?= e($member['contact_number']) ?>" placeholder="09XXXXXXXXX">
                    </label>
                    <label>Occupation
                        <input name="occupation" value="<?= e($member['occupation']) ?>">
                    </label>
                    <label>Employer
                        <input name="employer" value="<?= e($member['employer']) ?>">
                    </label>
                    <label>Employer address
                        <input name="employer_address" value="<?= e($member['employer_address']) ?>">
                    </label>
                </div>
                <label>Home address
                    <textarea name="address" required><?= e($member['address']) ?></textarea>
                </label>
            </section>

            <section class="form-section">
                <h2>Spouse &amp; parents</h2>
                <div class="two-col">
                    <label data-family-field>Spouse name
                        <input name="spouse_name" value="<?= e($member['spouse_name']) ?>">
                    </label>
                    <label data-family-field>Spouse occupation
                        <input name="spouse_occupation" value="<?= e($member['spouse_occupation']) ?>">
                    </label>
                    <label data-family-field>Spouse employer
                        <input name="spouse_employer" value="<?= e($member['spouse_employer']) ?>">
                    </label>
                    <label>Father's name
                        <input name="father_name" value="<?= e($member['father_name']) ?>">
                    </label>
                    <label>Mother's name
                        <input name="mother_name" value="<?= e($member['mother_name']) ?>">
                    </label>
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
                <h2>Cooperative references</h2>
                <div class="two-col">
                    <label>Reference 1
                        <input name="reference_one" value="<?= e($member['reference_one']) ?>">
                    </label>
                    <label>Reference 2
                        <input name="reference_two" value="<?= e($member['reference_two']) ?>">
                    </label>
                </div>
            </section>

            <button>Save changes</button>
            <button type="button" class="button secondary" onclick="window.print()">Print profile</button>
        </form>
    </main>
    <script src="assets/app.js"></script>
</body>
</html>
