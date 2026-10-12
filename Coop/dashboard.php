<?php

require 'config.php';
require_login();

$user = $_SESSION['user'];

if ($user['role'] === 'member') {
    $member = member_by_id($user['id']);
    if (!$member && !empty($user['uid'])) {
        $member = member_by_id($user['uid']);
    }
    if (!$member) {
        $member = normalize_member([
            'account_number' => $user['id'],
            'first_name' => 'Cooperative',
            'last_name' => 'Member',
        ]);
    }

    $user['name'] = trim($member['first_name'] . ' ' . $member['last_name']) ?: 'Cooperative Member';
    $_SESSION['user']['name'] = $user['name'];

    if (!empty($user['force_change'])) {
        redirect('profile.php?password=1');
    }
} else {
    $allMembers = members_all();
    $now = time();
    $sevenDaysAgo = $now - (7 * 86400);

    $recentCount = 0;
    $photoCount = 0;

    foreach ($allMembers as $m) {
        $updatedTime = strtotime($m['updated_at'] ?? '0');
        if ($updatedTime >= $sevenDaysAgo) {
            $recentCount++;
        }
        if (!empty($m['photo'])) {
            $photoCount++;
        }
    }

    $counts = [
        'total' => count($allMembers),
        'recent' => $recentCount,
        'with_photo' => $photoCount,
    ];

    $recentMembers = array_slice($allMembers, 0, 5);
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>CoopConnect | Dashboard</title>
    <link rel="stylesheet" href="assets/styles.css?v=20260821-unified-background">
</head>
<body>
    <?php if ($user['role'] === 'staff'): ?>
        <div class="staff-shell">
            <?php require 'staff_sidebar.php'; ?>
            <main class="staff-dashboard">
                <div class="staff-heading">
                    <div>
                        <p class="eyebrow">Cooperative management &middot; Firebase Connected</p>
                        <h1>Admin dashboard</h1>
                        <p>Manage member records and keep information up to date in real time.</p>
                    </div>
                    <div class="welcome-chip">Welcome back, <?= e($user['name']) ?></div>
                </div>
                <section class="staff-metrics">
                    <article><span class="metric-icon">◎</span><div><small>Total members</small><strong><?= e((string)$counts['total']) ?></strong><p>Registered accounts</p></div></article>
                    <article><span class="metric-icon">↻</span><div><small>Updated this week</small><strong><?= e((string)($counts['recent'] ?? 0)) ?></strong><p>Recent profile changes</p></div></article>
                    <article><span class="metric-icon">◉</span><div><small>Profile photos</small><strong><?= e((string)($counts['with_photo'] ?? 0)) ?></strong><p>Member photos uploaded</p></div></article>
                </section>
                <section class="staff-content-grid">
                    <article class="activity-panel">
                        <div class="panel-title">
                            <h2>Recent member activity</h2>
                            <a href="members.php?recent=1">View all</a>
                        </div>
                        <?php foreach ($recentMembers as $recent): ?>
                            <div class="activity-row">
                                <span class="activity-dot"></span>
                                <div>
                                    <strong><?= e($recent['first_name'] . ' ' . $recent['last_name']) ?></strong>
                                    <p>Member profile updated &middot; <?= e($recent['account_number']) ?></p>
                                </div>
                                <time><?= e(date('M j, g:i A', strtotime($recent['updated_at']))) ?></time>
                            </div>
                        <?php endforeach; ?>
                        <?php if (!$recentMembers): ?>
                            <p class="empty-state">No member activity yet.</p>
                        <?php endif; ?>
                    </article>
                    <aside class="quick-panel">
                        <h2>Quick actions</h2>
                        <p>Common tasks for staff.</p>
                        <a class="button" href="member_form.php">Add new member</a>
                        <a class="quick-link" href="surveys.php">Manage surveys <span>&rarr;</span></a>
                        <a class="quick-link" href="members.php">Manage members <span>&rarr;</span></a>
                        <a class="quick-link" href="members.php?recent=1">View updates <span>&rarr;</span></a>
                    </aside>
                </section>
            </main>
        </div>
    <?php else: ?>
    <header>
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="profile.php">My profile</a>
            <a href="member_surveys.php">Surveys</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container">
        <p class="eyebrow"><?= e(ucfirst($user['role'])) ?> portal</p>
        <h1>Welcome back, <?= e($user['name']) ?>.</h1>

        <section class="profile-summary">
            <div class="avatar">
                <?php if (!empty($member['photo'])): ?>
                    <img src="uploads/<?= e($member['photo']) ?>" alt="Profile photo">
                <?php else: ?>
                    <?= e(strtoupper(($member['first_name'][0] ?? 'C') . ($member['last_name'][0] ?? 'M'))) ?>
                <?php endif; ?>
            </div>
            <div>
                <h2><?= e($member['first_name'] . ' ' . $member['last_name']) ?></h2>
                <p><?= e($member['account_number']) ?> &middot; <?= e($member['occupation'] ?: 'No occupation recorded') ?></p>
                <a class="button" href="profile.php">View or update profile</a>
                <button class="button secondary" onclick="window.print()">Print profile</button>
            </div>
        </section>
        <section class="grid member-details">
            <article>
                <h3>Contact</h3>
                <p><?= e($member['contact_number'] ?: 'Not provided') ?><br><?= e($member['address'] ?: 'Not provided') ?></p>
            </article>
            <article>
                <h3>Last update</h3>
                <p><?= e(date('F j, Y', strtotime($member['updated_at']))) ?></p>
            </article>
        </section>
    </main>
    <?php endif; ?>
</body>
</html>
