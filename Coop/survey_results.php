<?php

require 'config.php';
require_login('staff');

$id = trim($_GET['id'] ?? '');
$survey = $id !== '' ? survey_by_id($id) : false;

if (!$survey) {
    redirect('surveys.php');
}

$submissionsData = firebase_db_get('survey_submissions') ?: [];
$responses = [];

foreach ($submissionsData as $sub) {
    if (!is_array($sub)) continue;
    $sId = (string)($sub['surveyId'] ?? $sub['survey_id'] ?? '');
    if ($sId === (string)$survey['id']) {
        $responses[] = $sub;
    }
}

$total = count($responses);
$questions = $survey['questions'] ?? [];

$processedQuestions = [];
foreach ($questions as $q) {
    $qId = (string)$q['id'];
    $counts = [];

    // Tally answers
    foreach ($responses as $sub) {
        $ans = $sub['answers'][$qId] ?? $sub['answers'][$q['question_text']] ?? '';
        if ($ans !== '' && $ans !== null) {
            $ansStr = (string)$ans;
            $counts[$ansStr] = ($counts[$ansStr] ?? 0) + 1;
        }
    }

    // Default choices for rating and yes_no so 0% shows cleanly
    if ($q['question_type'] === 'yes_no') {
        foreach (['Yes', 'No'] as $opt) {
            if (!isset($counts[$opt])) $counts[$opt] = 0;
        }
    } elseif ($q['question_type'] === 'rating') {
        foreach (['5', '4', '3', '2', '1'] as $opt) {
            if (!isset($counts[$opt])) $counts[$opt] = 0;
        }
    } elseif (!empty($q['choices'])) {
        foreach ($q['choices'] as $opt) {
            $optStr = is_array($opt) ? ($opt['choice_text'] ?? '') : (string)$opt;
            if ($optStr !== '' && !isset($counts[$optStr])) $counts[$optStr] = 0;
        }
    }

    $results = [];
    foreach ($counts as $answerText => $cnt) {
        $results[] = [
            'answer_text' => $answerText,
            'total' => $cnt,
        ];
    }

    usort($results, fn($a, $b) => $b['total'] <=> $a['total']);
    $q['results'] = $results;
    $processedQuestions[] = $q;
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Survey results | CoopConnect</title>
    <link rel="stylesheet" href="assets/styles.css">
</head>
<body class="staff-page">
    <?php require 'staff_sidebar.php'; ?>
    <main class="container form-wrap">
        <p class="eyebrow">Survey results &middot; Firebase Connected</p>
        <h1><?= e($survey['title']) ?></h1>
        <p><?= e((string)$total) ?> submitted response<?= $total === 1 ? '' : 's' ?></p>

        <?php foreach ($processedQuestions as $number => $question): ?>
            <section class="card result-card">
                <h2><?= ($number + 1) . '. ' . e($question['question_text']) ?></h2>
                <?php foreach ($question['results'] as $result):
                    $percent = $total > 0 ? (int)round($result['total'] / $total * 100) : 0;
                ?>
                    <div class="result-line">
                        <div>
                            <strong><?= e($result['answer_text']) ?></strong>
                            <span><?= e((string)$result['total']) ?> response<?= $result['total'] == 1 ? '' : 's' ?></span>
                        </div>
                        <div class="result-bar">
                            <i style="width:<?= $percent ?>%"></i>
                        </div>
                        <b><?= $percent ?>%</b>
                    </div>
                <?php endforeach; ?>
                <?php if (empty($question['results'])): ?>
                    <p>No answers recorded yet for this question.</p>
                <?php endif; ?>
            </section>
        <?php endforeach; ?>

        <button onclick="window.print()">Print report</button>
    </main>
</body>
</html>
