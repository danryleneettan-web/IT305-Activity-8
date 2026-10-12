import { randomBytes } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import mysql from 'mysql2/promise';

const APPLY = process.argv.includes('--apply');
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'coop-692bf';
const DATABASE_URL = process.env.FIREBASE_DATABASE_URL || `https://${PROJECT_ID}-default-rtdb.firebaseio.com`;
const ACCOUNT_DOMAIN = process.env.COOPCONNECT_AUTH_DOMAIN || `${PROJECT_ID}.firebaseapp.com`;

if (APPLY && !process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS to a Firebase service-account JSON path before applying.');
}
if (!process.env.MYSQL_DATABASE || !process.env.MYSQL_USER) {
  throw new Error('Set MYSQL_DATABASE and MYSQL_USER (and MYSQL_HOST/MYSQL_PASSWORD if needed) for the existing MySQL installation.');
}

const db = await mysql.createConnection({
  host: process.env.MYSQL_HOST || '127.0.0.1',
  port: Number(process.env.MYSQL_PORT || 3306),
  user: process.env.MYSQL_USER,
  password: process.env.MYSQL_PASSWORD || '',
  database: process.env.MYSQL_DATABASE,
  charset: 'utf8mb4',
  timezone: '+08:00',
});

async function rows(sql) {
  try { const [result] = await db.query(sql); return result; }
  catch (error) { if (error.code === 'ER_NO_SUCH_TABLE') return []; throw error; }
}

const [staffRows, memberRows, childRows, surveyRows, questionRows, choiceRows, submissionRows, answerRows] = await Promise.all([
  rows('SELECT * FROM staff ORDER BY id'),
  rows('SELECT * FROM members ORDER BY id'),
  rows('SELECT * FROM children ORDER BY id'),
  rows('SELECT * FROM surveys ORDER BY id'),
  rows('SELECT * FROM survey_questions ORDER BY sort_order, id'),
  rows('SELECT * FROM survey_choices ORDER BY sort_order, id'),
  rows('SELECT * FROM survey_submissions ORDER BY id'),
  rows('SELECT * FROM survey_answers ORDER BY id'),
]);

const authEmailForMember = account => `${account}@members.${ACCOUNT_DOMAIN}`;
const authEmailForStaff = username => `${username}@staff.${ACCOUNT_DOMAIN}`;
const tempPassword = () => randomBytes(24).toString('base64url');
const credentials = [];
let adminApp;
let adminAuth;
let adminDb;
let existing = {};

if (APPLY) {
  const [{ initializeApp, applicationDefault }, { getAuth }, { getDatabase }] = await Promise.all([
    import('firebase-admin/app'), import('firebase-admin/auth'), import('firebase-admin/database'),
  ]);
  adminApp = initializeApp({ credential: applicationDefault(), projectId: PROJECT_ID, databaseURL: DATABASE_URL });
  adminAuth = getAuth(adminApp);
  adminDb = getDatabase(adminApp);
  existing = (await adminDb.ref('cooperative_portal').get()).val() || {};
}

async function ensureAccount(email, role, label) {
  if (!APPLY) return `DRY_RUN_${role}_${label}`;
  let record;
  let createdPassword = '';
  try { record = await adminAuth.getUserByEmail(email); }
  catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    createdPassword = tempPassword();
    record = await adminAuth.createUser({ email, password: createdPassword, emailVerified: true, disabled: false });
    credentials.push({ role, label, email, password: createdPassword });
  }
  if (role === 'staff') await adminAuth.setCustomUserClaims(record.uid, { ...(record.customClaims || {}), role: 'staff' });
  return record.uid;
}

const memberByDbId = new Map(memberRows.map(member => [String(member.id), member]));
const staffByDbId = new Map(staffRows.map(staff => [String(staff.id), staff]));
const memberAuthUids = new Map();
const staffAuthUids = new Map();
for (const staff of staffRows) staffAuthUids.set(String(staff.id), await ensureAccount(authEmailForStaff(staff.username), 'staff', staff.username));
for (const member of memberRows) memberAuthUids.set(String(member.id), await ensureAccount(authEmailForMember(member.account_number), 'member', member.account_number));

const childrenByMember = new Map();
for (const child of childRows) {
  const key = String(child.member_id);
  if (!childrenByMember.has(key)) childrenByMember.set(key, {});
  childrenByMember.get(key)[`child_${child.id}`] = { name: child.child_name, age: Number(child.age) };
}

const migratedMembers = {};
for (const member of memberRows) {
  const record = {
    id: String(member.account_number),
    accountNumber: member.account_number,
    authUid: memberAuthUids.get(String(member.id)),
    forcePasswordChange: true,
    firstName: member.first_name,
    lastName: member.last_name,
    middleName: member.middle_name || '',
    extensionName: member.extension_name || '',
    civilStatus: member.civil_status,
    address: member.address,
    contactNumber: member.contact_number,
    birthday: String(member.birthday || ''),
    occupation: member.occupation || '',
    employer: member.employer || '',
    employerAddress: member.employer_address || '',
    spouseName: member.spouse_name || '',
    spouseOccupation: member.spouse_occupation || '',
    spouseEmployer: member.spouse_employer || '',
    fatherName: member.father_name || '',
    motherName: member.mother_name || '',
    referenceOne: member.reference_one || '',
    referenceTwo: member.reference_two || '',
    photo: member.photo || '',
    children: childrenByMember.get(String(member.id)) || {},
    createdAt: member.created_at ? new Date(member.created_at).toISOString() : new Date().toISOString(),
    updatedAt: member.updated_at ? new Date(member.updated_at).toISOString() : new Date().toISOString(),
  };
  migratedMembers[member.account_number] = record;
}

const questionsBySurvey = new Map();
const questionIdMap = new Map();
for (const question of questionRows) {
  const surveyKey = `survey_${question.survey_id}`;
  const questionKey = `q_${question.id}`;
  questionIdMap.set(String(question.id), questionKey);
  if (!questionsBySurvey.has(surveyKey)) questionsBySurvey.set(surveyKey, {});
  questionsBySurvey.get(surveyKey)[questionKey] = {
    id: questionKey,
    order: Number(question.sort_order || 0),
    text: question.question_text,
    type: question.question_type,
    isRequired: Boolean(question.is_required),
    choices: [],
  };
}
for (const choice of choiceRows) {
  const questionKey = questionIdMap.get(String(choice.question_id));
  const question = [...questionsBySurvey.values()].map(survey => survey[questionKey]).find(Boolean);
  if (question) question.choices.push(choice.choice_text);
}

const migratedSurveys = {};
for (const survey of surveyRows) {
  const key = `survey_${survey.id}`;
  const creator = staffByDbId.get(String(survey.created_by));
  migratedSurveys[key] = {
    id: key,
    title: survey.title,
    description: survey.description || '',
    status: survey.status,
    opensAt: String(survey.opens_at || ''),
    closesAt: String(survey.closes_at || ''),
    createdBy: creator?.username || '',
    createdAt: survey.created_at ? new Date(survey.created_at).toISOString() : new Date().toISOString(),
    updatedAt: survey.updated_at ? new Date(survey.updated_at).toISOString() : new Date().toISOString(),
    questions: questionsBySurvey.get(key) || {},
  };
}

const answersBySubmission = new Map();
for (const answer of answerRows) {
  if (!answersBySubmission.has(String(answer.submission_id))) answersBySubmission.set(String(answer.submission_id), {});
  answersBySubmission.get(String(answer.submission_id))[questionIdMap.get(String(answer.question_id)) || `q_${answer.question_id}`] = String(answer.answer_text || '');
}

const migratedSubmissions = {};
for (const submission of submissionRows) {
  const member = memberByDbId.get(String(submission.member_id));
  const surveyId = `survey_${submission.survey_id}`;
  if (!member) continue;
  const key = `${surveyId}_${memberAuthUids.get(String(member.id))}`;
  migratedSubmissions[key] = {
    id: key,
    surveyId,
    memberId: member.account_number,
    memberUid: memberAuthUids.get(String(member.id)),
    memberName: `${member.first_name} ${member.last_name}`.trim(),
    submittedAt: submission.submitted_at ? new Date(submission.submitted_at).toISOString() : new Date().toISOString(),
    answers: answersBySubmission.get(String(submission.id)) || {},
  };
}

console.log(`MySQL source: ${staffRows.length} staff, ${memberRows.length} members, ${childRows.length} children, ${surveyRows.length} surveys, ${questionRows.length} questions, ${submissionRows.length} submissions.`);
console.log(APPLY ? 'Apply mode: Firebase Auth users and Realtime Database will be updated.' : 'Dry run only. No Firebase records or accounts were changed. Use --apply to migrate.');

if (APPLY) {
  const safeExistingMembers = Object.fromEntries(Object.entries(existing.members || {}).map(([key, value]) => {
    const safe = value && typeof value === 'object' ? { ...value } : {};
    delete safe.password; delete safe.password_hash;
    return [key, safe];
  }));
  const safeExistingStaff = Object.fromEntries(Object.entries(existing.staff || {}).map(([key, value]) => {
    const safe = value && typeof value === 'object' ? { ...value } : {};
    delete safe.password; delete safe.password_hash;
    return [key, safe];
  }));
  const staff = { ...safeExistingStaff };
  for (const row of staffRows) {
    staff[row.username] = { username: row.username, fullName: row.full_name, authUid: staffAuthUids.get(String(row.id)), role: 'staff' };
  }
  const surveys = { ...(existing.surveys || {}), ...migratedSurveys };
  const submissions = { ...(existing.survey_submissions || {}), ...migratedSubmissions };
  for (const [key, value] of Object.entries(submissions)) {
    if (value && typeof value === 'object') { delete value.password; delete value.password_hash; }
  }
  const payload = { ...existing, members: { ...safeExistingMembers, ...migratedMembers }, staff, surveys, survey_submissions: submissions };
  await adminDb.ref('cooperative_portal').set(payload);
  if (credentials.length) {
    const quote = value => `"${String(value).replaceAll('"', '""')}"`;
    const csv = ['role,account,email,temporary_password', ...credentials.map(row => [row.role,row.label,row.email,row.password].map(quote).join(','))].join('\r\n');
    await writeFile(new URL('./migration-credentials.csv', import.meta.url), csv, { mode: 0o600 });
  }
  console.log(`Imported ${Object.keys(migratedMembers).length} profiles and ${Object.keys(migratedSurveys).length} surveys. New account credentials are in firebase_admin/migration-credentials.csv; deliver them privately and delete that file when done.`);
}

await db.end();
