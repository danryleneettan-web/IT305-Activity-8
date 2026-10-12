<?php

require 'config.php';
require_login('staff');

if (isset($_GET['deactivate'])) {
    $id = trim($_GET['deactivate']);
    firebase_db_update("surveys/$id", [
        'status' => 'inactive',
        'updatedAt' => date('Y-m-d H:i:s'),
        'updated_at' => date('Y-m-d H:i:s'),
    ]);
    flash('success', 'Survey deactivated in Firebase.');
    redirect('surveys.php');
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $id = trim($_POST['id'] ?? '');
    $title = trim($_POST['title'] ?? '');

    if ($title === '' || empty($_POST['opens_at']) || empty($_POST['closes_at'])) {
        flash('error', 'Title, opening date, and closing date are required.');
        redirect('surveys.php');
    }

    if ($id === '') {
        $id = 'survey_' . round(microtime(true) * 1000);
    }

    $opensAt = str_replace('T', ' ', $_POST['opens_at']) . ':00';
    $closesAt = str_replace('T', ' ', $_POST['closes_at']) . ':00';
    $now = date('Y-m-d H:i:s');

    $questionsMap = [];
    foreach ($_POST['question_text'] ?? [] as $index => $text) {
        if (trim($text) === '') continue;
        $qId = 'q' . ($index + 1);
        $qType = $_POST['question_type'][$index] ?? 'short_answer';
        $choices = [];
        if ($qType === 'multiple_choice') {
            $rawChoices = explode("\n", $_POST['choices'][$index] ?? '');
            foreach ($rawChoices as $rc) {
                $trimmed = trim($rc);
                if ($trimmed !== '') {
                    $choices[] = $trimmed;
                }
            }
        }
        $questionsMap[$qId] = [
            'id' => $qId,
            'order' => $index + 1,
            'text' => trim($text),
            'question_text' => trim($text),
            'type' => $qType,
            'question_type' => $qType,
            'isRequired' => true,
            'is_required' => true,
            'choices' => $choices,
        ];
    }

    $surveyRecord = [
        'id' => $id,
        'title' => $title,
        'description' => trim($_POST['description'] ?? ''),
        'status' => $_POST['status'] ?? 'draft',
        'opens_at' => $opensAt,
        'opensAt' => $opensAt,
        'closes_at' => $closesAt,
        'closesAt' => $closesAt,
        'created_by' => $_SESSION['user']['id'] ?? 'admin',
        'createdBy' => $_SESSION['user']['id'] ?? 'admin',
        'created_at' => $now,
        'createdAt' => $now,
        'updated_at' => $now,
        'updatedAt' => $now,
        'questions' => !empty($questionsMap) ? $questionsMap : new stdClass(),
    ];

    firebase_db_set("surveys/$id", $surveyRecord);

    flash('success', 'Survey saved successfully to Firebase.');
    redirect('surveys.php');
}

$surveys = surveys_all();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Survey management | CoopConnect</title>
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
    <main class="container form-wrap">
        <div class="page-actions">
            <div>
                <p class="eyebrow">Survey Module &middot; Firebase Connected</p>
                <h1>Survey management</h1>
            </div>
        </div>
        <?php if ($m = flash('success')): ?>
            <p class="alert success"><?= e($m) ?></p>
        <?php endif; ?>
        <?php if ($m = flash('error')): ?>
            <p class="alert error"><?= e($m) ?></p>
        <?php endif; ?>

        <form method="post" class="card" id="survey-editor">
            <h2>Create survey</h2>
            <div class="two-col">
                <label>Survey title<input name="title" required></label>
                <label>Status
                    <select name="status">
                        <option value="draft">Draft</option>
                        <option value="active" selected>Active</option>
                    </select>
                </label>
                <label>Opening date<input type="datetime-local" name="opens_at" required></label>
                <label>Closing date<input type="datetime-local" name="closes_at" required></label>
            </div>
            <label>Description<textarea name="description"></textarea></label>
            <section class="form-section">
                <div class="panel-title">
                    <h2>Questions</h2>
                    <button type="button" class="button secondary" id="add-question">Add question</button>
                </div>
                <div id="questions"></div>
            </section>
            <button>Save survey</button>
        </form>

        <section class="card" id="existing-surveys">
            <h2>Existing surveys and reports</h2>
            <div class="table-wrap">
                <table>
                    <thead>
                        <tr>
                            <th>Survey</th>
                            <th>Status</th>
                            <th>Schedule</th>
                            <th>Respondents</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($surveys as $s): ?>
                            <tr>
                                <td><strong><?= e($s['title']) ?></strong></td>
                                <td><?= e(ucfirst($s['status'])) ?></td>
                                <td><?= e(date('M j, Y g:i A', strtotime($s['opens_at']))) ?></td>
                                <td><?= e((string)$s['respondents']) ?></td>
                                <td>
                                    <a href="survey_results.php?id=<?= urlencode((string)$s['id']) ?>">Results</a> &middot;
                                    <a class="danger" href="surveys.php?deactivate=<?= urlencode((string)$s['id']) ?>">Deactivate</a>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        <?php if (!$surveys): ?>
                            <tr><td colspan="5">No surveys found in Firebase.</td></tr>
                        <?php endif; ?>
                    </tbody>
                </table>
            </div>
        </section>
    </main>
    <script src="assets/app.js"></script>
</body>
</html>
