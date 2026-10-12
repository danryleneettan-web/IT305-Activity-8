<?php

require 'config.php';
require_login('staff');

$id = trim($_GET['id'] ?? '');
$m = $id !== '' ? member_by_id($id) : false;

if (!$m) {
    redirect('members.php');
}

$children = member_children($m['id']);
?>
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <title><?= e($m['account_number']) ?> | Member profile</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="print-page">
    <main class="container card">
        <h1>Cooperative Member Information</h1>
        <p><strong>Account number:</strong> <?= e($m['account_number']) ?></p>
        <h2><?= e($m['first_name'] . ' ' . $m['middle_name'] . ' ' . $m['last_name']) ?></h2>
        <p>
            <strong>Address:</strong> <?= e($m['address']) ?><br>
            <strong>Contact:</strong> <?= e($m['contact_number']) ?><br>
            <strong>Birthday:</strong> <?= e($m['birthday']) ?><br>
            <strong>Occupation:</strong> <?= e($m['occupation']) ?>
        </p>
        <h3>Family information</h3>
        <p>
            <strong>Spouse:</strong> <?= e($m['spouse_name']) ?><br>
            <strong>Father:</strong> <?= e($m['father_name']) ?><br>
            <strong>Mother:</strong> <?= e($m['mother_name']) ?>
        </p>
        <h3>Children</h3>
        <ul>
            <?php foreach ($children as $c): ?>
                <li><?= e($c['child_name']) ?>, <?= e((string)$c['age']) ?></li>
            <?php endforeach; ?>
        </ul>
        <button onclick="window.print()">Print</button>
    </main>
</body>
</html>