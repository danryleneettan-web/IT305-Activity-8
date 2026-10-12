<?php

require 'config.php';
require_login('member');

$id = trim($_GET['id'] ?? '');
$survey = $id !== '' ? survey_by_id($id) : false;

if (!$survey || !survey_is_active($survey)) {
    redirect('member_surveys.php');
}

$user = $_SESSION['user'];
$memberId = (string)$user['id'];
$memberUid = (string)($user['uid'] ?? '');

// Check if already submitted
$submissionsData = firebase_db_get('survey_submissions') ?: [];
$subKey = "{$id}_{$memberId}";
$hasSubmitted = !empty($submissionsData[$subKey]);

if (!$hasSubmitted) {
    foreach ($submissionsData as $sub) {
        if (!is_array($sub)) continue;
        $matchSurvey = ($sub['surveyId'] ?? $sub['survey_id'] ?? '') === $id;
        $matchMember = ($sub['memberId'] ?? $sub['member_id'] ?? '') === $memberId ||
                       ($sub['memberUid'] ?? '') === $memberUid;
        if ($matchSurvey && $matchMember) {
            $hasSubmitted = true;
            break;
        }
    }
}

if ($hasSubmitted) {
    flash('error', 'You have already submitted a response for this survey.');
    redirect('member_surveys.php');
}

$questions = $survey['questions'] ?? [];
$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    try {
        $answers = [];
        foreach ($questions as $q) {
            $qId = (string)$q['id'];
            $val = trim($_POST['answer'][$qId] ?? '');
            if (!empty($q['is_required']) && $val === '') {
                throw new RuntimeException('Please answer every required question.');
            }
            $answers[$qId] = $val;
        }

        $now = date('Y-m-d H:i:s');
        $submissionRecord = [
            'id' => $subKey,
            'surveyId' => $id,
            'survey_id' => $id,
            'memberId' => $memberId,
            'member_id' => $memberId,
            'memberUid' => $memberUid,
            'memberName' => $user['name'] ?? 'Member',
            'submittedAt' => $now,
            'submitted_at' => $now,
            'answers' => $answers,
        ];

        firebase_db_set("survey_submissions/$subKey", $submissionRecord);

        flash('success', 'Thank you! Your survey response has been saved to Firebase in real time.');
        redirect('member_surveys.php');
    } catch (Throwable $e) {
        $error = $e->getMessage();
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title><?= e($survey['title']) ?> | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body>
    <header>
        <a class="brand-mini" href="dashboard.php">CC <span>CoopConnect</span></a>
        <nav>
            <a href="member_surveys.php">Surveys</a>
            <a href="logout.php">Logout</a>
        </nav>
    </header>
    <main class="container form-wrap">
        <p class="eyebrow">Member survey &middot; Firebase Connected</p>
        <h1><?= e($survey['title']) ?></h1>
        <p><?= e($survey['description']) ?></p>

        <?php if ($error): ?>
            <p class="alert error"><?= e($error) ?></p>
        <?php endif; ?>

        <form method="post" class="card">
            <?php foreach ($questions as $number => $question): ?>
                <section class="form-section">
                    <h2><?= ($number + 1) . '. ' . e($question['question_text']) ?></h2>
                    <?php if ($question['question_type'] === 'multiple_choice' || $question['question_type'] === 'yes_no'):
                        $choices = $question['question_type'] === 'yes_no' ? ['Yes', 'No'] : $question['choices'];
                        foreach ($choices as $choice):
                            $cText = is_array($choice) ? ($choice['choice_text'] ?? '') : (string)$choice;
                        ?>
                            <label class="choice">
                                <input type="radio" name="answer[<?= e($question['id']) ?>]" value="<?= e($cText) ?>" <?= !empty($question['is_required']) ? 'required' : '' ?>>
                                <?= e($cText) ?>
                            </label>
                        <?php endforeach;
                    elseif ($question['question_type'] === 'rating'): ?>
                        <div class="rating">
                            <?php for ($n = 1; $n <= 5; $n++): ?>
                                <label>
                                    <input type="radio" name="answer[<?= e($question['id']) ?>]" value="<?= $n ?>" <?= !empty($question['is_required']) ? 'required' : '' ?>>
                                    <?= $n ?>
                                </label>
                            <?php endfor; ?>
                        </div>
                    <?php else: ?>
                        <textarea name="answer[<?= e($question['id']) ?>]" <?= !empty($question['is_required']) ? 'required' : '' ?>></textarea>
                    <?php endif; ?>
                </section>
            <?php endforeach; ?>
            <button>Submit survey</button>
        </form>
    </main>
</body>
</html>
