<style>
@media (min-width: 921px) {
    body.staff-page { padding-left: 255px !important; }
    body.staff-page > header { display: none !important; }
    .staff-shared-sidebar {
        position: fixed !important;
        top: 0; left: 0; bottom: 0; z-index: 999;
        width: 255px; padding: 28px 18px;
        overflow-y: auto; box-sizing: border-box;
        display: flex !important; flex-direction: column;
        color: #fff; background: linear-gradient(180deg, #56233f, #743650);
        border-right: 1px solid #8c4b68;
    }
    .staff-shared-sidebar .staff-brand { display: flex; align-items: center; gap: 10px; color: #fff; font-size: 21px; font-weight: 800; }
    .staff-shared-sidebar .staff-brand span, .staff-shared-sidebar .staff-profile > span { display: grid; place-items: center; width: 38px; height: 38px; border-radius: 12px; background: linear-gradient(135deg, #d77ca3, #b45680); color: #fff; font-weight: 850; }
    .staff-shared-sidebar .sidebar-label { margin: 7px 8px 30px; color: #f1c8d8; font-size: 13px; }
    .staff-shared-sidebar .staff-menu { display: grid; gap: 8px; }
    .staff-shared-sidebar .staff-menu a, .staff-shared-sidebar .staff-logout { padding: 11px 13px; border-radius: 10px; color: #fff1f6; text-decoration: none; }
    .staff-shared-sidebar .staff-menu a:hover { background: rgba(255, 255, 255, .16); color: #fff; }
    .staff-shared-sidebar .staff-profile { display: flex; align-items: center; gap: 10px; margin-top: auto; padding: 13px; border-radius: 13px; background: rgba(255, 255, 255, .15); border: 1px solid rgba(255, 255, 255, .12); }
    .staff-shared-sidebar .staff-profile > span { width: 36px; height: 36px; }
    .staff-shared-sidebar .staff-profile strong, .staff-shared-sidebar .staff-profile small { display: block; }
    .staff-shared-sidebar .staff-profile small { color: #f1c8d8; font-size: 12px; }
    .staff-shared-sidebar .staff-logout { margin-top: 12px; text-align: center; border: 1px solid #e6b7ca; }
}
</style>
<aside class="staff-shared-sidebar">
    <a class="staff-brand" href="dashboard.php"><span>CC</span> CoopConnect</a>
    <p class="sidebar-label">Cooperative admin</p>
    <nav class="staff-menu">
        <a href="dashboard.php">Overview</a>
        <a href="members.php">Member records</a>
        <a href="member_form.php">Add new member</a>
        <a href="surveys.php">Survey management</a>
        <a href="surveys.php#existing-surveys">Reports</a>
        <a href="members.php?recent=1">Recent updates</a>
    </nav>
    <div class="staff-profile">
        <span><?= e(strtoupper($_SESSION['user']['name'][0] ?? 'A')) ?></span>
        <div><strong><?= e($_SESSION['user']['name']) ?></strong><small>Cooperative staff</small></div>
    </div>
    <a class="staff-logout" href="logout.php">Sign out</a>
</aside>
