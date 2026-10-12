// Login tabs: switch between the member and staff login forms.
document.querySelectorAll('.tab').forEach((button) => {
    button.addEventListener('click', () => {
        document.querySelectorAll('.tab, .login-form').forEach((el) => el.classList.remove('active'));
        button.classList.add('active');
        document.getElementById(button.dataset.tab).classList.add('active');
    });
});

if (location.hash === '#staff') {
    document.querySelector('.tab[data-tab="staff"]')?.click();
}

// Password visibility toggle for the login forms.
document.querySelectorAll('[data-password-toggle]').forEach((toggle) => {
    toggle.addEventListener('click', () => {
        const form = document.getElementById(toggle.dataset.passwordToggle);
        const password = form.querySelector('input[name="password"]');
        const visible = password.type === 'text';

        password.type = visible ? 'password' : 'text';
        toggle.setAttribute('aria-label', visible ? 'Show password' : 'Hide password');
        toggle.setAttribute('title', visible ? 'Show password' : 'Hide password');
        toggle.classList.toggle('is-visible', !visible);
    });
});

// Add/remove child rows on the member profile form.
const container = document.getElementById('children');

document.getElementById('add-child')?.addEventListener('click', () => {
    const row = document.createElement('div');
    row.className = 'child-row';
    row.innerHTML = `
        <input name="child_name[]" placeholder="Child name">
        <input name="child_age[]" type="number" min="0" placeholder="Age">
        <button type="button" class="remove">Remove</button>
    `;
    container.append(row);
});

container?.addEventListener('click', (event) => {
    if (event.target.classList.contains('remove')) {
        event.target.closest('.child-row').remove();
    }
});

// Contact numbers are limited to the Philippine 11-digit mobile number format.
document.querySelectorAll('[data-contact-number]').forEach((input) => {
    input.addEventListener('input', () => {
        input.value = input.value.replace(/\D/g, '').slice(0, 11);
    });
});

// Family fields only apply when the member is not single.
const civilStatus = document.querySelector('[data-civil-status]');
const familySections = document.querySelectorAll('[data-family-section], [data-family-field]');

function updateFamilyFields() {
    if (!civilStatus) return;

    const isSingle = civilStatus.value === 'Single';
    const isStaffMemberForm = document.body.classList.contains('staff-page') && document.getElementById('children') !== null;
    familySections.forEach((section) => {
        // On the staff Add/Edit Member screen, non-applicable family sections are hidden.
        section.hidden = isStaffMemberForm && isSingle;
        section.classList.toggle('is-disabled', isSingle);
        section.querySelectorAll('input, select, textarea, button').forEach((field) => {
            field.disabled = isSingle;
        });
    });
}

civilStatus?.addEventListener('change', updateFamilyFields);
updateFamilyFields();

// Staff records update as each search character is typed; normal form submit remains available.
const searchInput = document.getElementById('member-search');
const searchResults = document.getElementById('member-results');
let searchDelay;

searchInput?.addEventListener('input', () => {
    clearTimeout(searchDelay);
    searchDelay = setTimeout(async () => {
        const query = new URLSearchParams({ live: '1', q: searchInput.value });
        const response = await fetch(`members.php?${query.toString()}`);
        if (response.ok && searchResults) searchResults.innerHTML = await response.text();
    }, 220);
});

// Build survey questions without leaving the survey editor page.
const questions = document.getElementById('questions');
document.getElementById('add-question')?.addEventListener('click', () => {
    const item = document.createElement('div');
    item.className = 'question-editor';
    item.innerHTML = `
        <label>Question text<textarea name="question_text[]" required></textarea></label>
        <div class="two-col">
            <label>Question type
                <select name="question_type[]" class="question-type">
                    <option value="multiple_choice">Multiple choice</option>
                    <option value="yes_no">Yes / No</option>
                    <option value="rating">Rating scale (1-5)</option>
                    <option value="short_answer">Short answer</option>
                </select>
            </label>
            <label class="choices-field">Choices (one per line)<textarea name="choices[]" placeholder="Option 1&#10;Option 2"></textarea></label>
        </div>
        <button type="button" class="remove">Remove question</button>`;
    questions.append(item);
});

questions?.addEventListener('change', (event) => {
    if (!event.target.classList.contains('question-type')) return;
    const choices = event.target.closest('.question-editor').querySelector('.choices-field');
    choices.hidden = event.target.value !== 'multiple_choice';
});

questions?.addEventListener('click', (event) => {
    if (event.target.classList.contains('remove')) event.target.closest('.question-editor').remove();
});
