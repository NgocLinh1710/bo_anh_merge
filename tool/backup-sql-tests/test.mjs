import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const database = new PGlite();
try {
  await database.exec('create role anon; create role authenticated;');
  const migration = await readFile(new URL('../../supabase/migrations/202611080001_game_backups.sql', import.meta.url), 'utf8');
  const tests = await readFile(new URL('../../supabase/tests/game_backups.sql', import.meta.url), 'utf8');
  await database.exec(migration);
  await database.exec(migration); // Re-running setup must preserve existing schema.
  await database.exec(tests);
  console.log('PASS: PostgreSQL backup migration, anon permissions, wrong keys, revisions, retries and deletion');
} finally {
  await database.close();
}
