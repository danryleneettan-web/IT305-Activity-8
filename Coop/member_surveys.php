<?php

require 'config.php';
require_login('member');

$user = $_SESSION['user'];
$memberId = (string)$user['id'];
$memberUid = (string)($user['uid'] ?? '');

$surveysData = surveys_all();
$submissionsData = firebase_db_get('survey_submissions') ?: [];

$surveys = [];
foreach ($surveysData as $s) {
    if (!survey_is_active($s)) {
        continue;
    }

    $sId = (string)$s['id'];
    $submitted = false;

    // Check direct key or match surveyId + memberId/memberUid
    $subKey = "{$sId}_{$memberId}";
    if (!empty($submissionsData[$subKey])) {
        $submitted = true;
    } else {
        foreach ($submissionsData as $sub) {
            if (!is_array($sub)) continue;
            $matchSurvey = ($sub['surveyId'] ?? $sub['survey_id'] ?? '') === $sId;
            $matchMember = ($sub['memberId'] ?? $sub['member_id'] ?? '') === $memberId ||
                           ($sub['memberUid'] ?? '') === $memberUid;
            if ($matchSurvey && $matchMember) {
                $submitted = true;
                break;
            }
        }
    }

    $s['submitted'] = $submitted;
    $surveys[] = $s;
}

usort($surveys, function ($a, $b) {
    return strtotime($a['closes_at'] ?? '0') <=> strtotime($b['closes_at'] ?? '0');
});
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Available surveys | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
    <header>
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="dashboard.php">Dashboard</a>
            <a href="profile.php">My profile</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container">
        <p class="eyebrow">Member surveys &middot; Firebase Connected</p>
        <h1>Available surveys</h1>

        <?php if ($m = flash('success')): ?>
            <p class="alert success"><?= e($m) ?></p>
        <?php endif; ?>
        <?php if ($m = flash('error')): ?>
            <p class="alert error"><?= e($m) ?></p>
        <?php endif; ?>

        <section class="survey-list">
            <?php foreach ($surveys as $s): ?>
                <article class="card">
                    <p class="eyebrow">Closes <?= e(date('M j, g:i A', strtotime($s['closes_at']))) ?></p>
                    <h2><?= e($s['title']) ?></h2>
                    <p><?= e($s['description']) ?></p>
                    <?php if ($s['submitted']): ?>
                        <span class="survey-done">Submitted</span>
                    <?php else: ?>
                        <a class="button" href="take_survey.php?id=<?= urlencode((string)$s['id']) ?>">Answer survey</a>
                    <?php endif; ?>
                </article>
            <?php endforeach; ?>
            <?php if (!$surveys): ?>
                <p>No active surveys are available right now.</p>
            <?php endif; ?>
        </section>
    </main>
</body>
</html>
