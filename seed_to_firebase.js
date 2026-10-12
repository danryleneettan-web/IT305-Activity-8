// Retired: the former version used an unauthenticated PUT and could overwrite
// the entire production database. Use firebase_admin/migrate-mysql.mjs, which
// authenticates with a private service account and supports a dry-run first.
console.error('This public-write seeder is retired. See FIREBASE_COOP_SETUP_GUIDE.md for the authenticated migration workflow.');
process.exitCode = 1;
