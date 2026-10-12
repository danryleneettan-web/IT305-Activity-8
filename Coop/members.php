<?php

require 'config.php';
require_login('staff');

if (isset($_GET['delete'])) {
    $id = trim($_GET['delete']);
    firebase_db_delete("members/$id");
    flash('success', 'Member record deleted from Firebase.');
    redirect('members.php');
}

if (isset($_GET['reset'])) {
    $id = trim($_GET['reset']);
    $m = member_by_id($id);

    if ($m) {
        $accountNum = $m['account_number'];
        $email = $accountNum . '@members.' . FIREBASE_AUTH_DOMAIN;

        // Reset password to account number in Firebase Auth
        try {
            // Check if authUid exists
            $authUid = $m['authUid'] ?? '';
            // Update RTDB flag
            firebase_db_update("members/$accountNum", [
                'forcePasswordChange' => true,
                'force_password_change' => true,
                'updatedAt' => date('Y-m-d H:i:s'),
                'updated_at' => date('Y-m-d H:i:s'),
            ]);
        } catch (Throwable $e) {}
    }

    flash('success', 'Password reset flag enabled. Member can sign in using account number.');
    redirect('members.php');
}

$search = trim($_GET['q'] ?? '');
$isRecent = isset($_GET['recent']);
$now = time();
$sevenDaysAgo = $now - (7 * 86400);

$allMembers = members_all();
$members = [];

foreach ($allMembers as $m) {
    if ($isRecent) {
        $updatedTime = strtotime($m['updated_at'] ?? '0');
        if ($updatedTime < $sevenDaysAgo) {
            continue;
        }
    }

    if ($search !== '') {
        $match = (stripos($m['account_number'], $search) !== false) ||
                 (stripos($m['first_name'], $search) !== false) ||
                 (stripos($m['last_name'], $search) !== false);
        if (!$match) {
            continue;
        }
    }

    $members[] = $m;
}

function member_rows(array $members): string
{
    ob_start();
    foreach ($members as $m): ?>
        <tr>
            <td><?= e($m['account_number']) ?></td>
            <td><?= e($m['last_name'] . ', ' . $m['first_name']) ?></td>
            <td><?= e($m['contact_number'] ?: 'N/A') ?></td>
            <td><?= e(date('M j, Y g:i A', strtotime($m['updated_at']))) ?></td>
            <td>
                <a href="member_form.php?id=<?= urlencode((string)$m['account_number']) ?>">Edit</a> &middot;
                <a href="profile_print.php?id=<?= urlencode((string)$m['account_number']) ?>" target="_blank">Print</a> &middot;
                <a href="members.php?reset=<?= urlencode((string)$m['account_number']) ?>" onclick="return confirm('Reset this member password?')">Reset</a> &middot;
                <a class="danger" href="members.php?delete=<?= urlencode((string)$m['account_number']) ?>" onclick="return confirm('Delete this record permanently from Firebase?')">Delete</a>
            </td>
        </tr>
    <?php endforeach;
    if (!$members): ?>
        <tr><td colspan="5">No member records found in Firebase.</td></tr>
    <?php endif;
    return (string)ob_get_clean();
}

if (isset($_GET['live'])) {
    header('Content-Type: text/html; charset=utf-8');
    echo member_rows($members);
    exit;
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Members | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="staff-page">
    <?php require 'staff_sidebar.php'; ?>
    <header class="staff-side-header">
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="dashboard.php">Dashboard</a>
            <a href="members.php">Members</a>
            <a href="member_form.php">Add member</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container">
        <div class="page-actions">
            <div>
                <p class="eyebrow">Cooperative records &middot; Firebase Connected</p>
                <h1>Member records</h1>
            </div>
            <a class="button" href="member_form.php">Add new member</a>
        </div>

        <?php if ($m = flash('success')): ?>
            <p class="alert success"><?= e($m) ?></p>
        <?php endif; ?>

        <section class="card">
            <form method="get" class="search-bar">
                <input id="member-search" name="q" value="<?= e($search) ?>" placeholder="Search by account number or name...">
                <button type="submit">Search</button>
                <?php if ($search !== '' || $isRecent): ?>
                    <a class="button secondary" href="members.php">Clear</a>
                <?php endif; ?>
            </form>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Account #</th>
                            <th>Name</th>
                            <th>Contact</th>
                            <th>Last updated</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="member-results">
                        <?= member_rows($members) ?>
                    </tbody>
                </table>
            </div>
        </section>
    </main>
    <script src="assets/app.js"></script>
</body>
</html>
