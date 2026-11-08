-- Run after the migration in Supabase SQL Editor. Always rolls back test data.
begin;
do $$ begin
  if has_schema_privilege('anon', 'game_backup_private', 'USAGE')
     or has_table_privilege('anon', 'game_backup_private.backups', 'SELECT')
     or has_table_privilege('anon', 'game_backup_private.backups', 'INSERT') then
    raise exception 'FAIL: anonymous direct table access is enabled';
  end if;
end $$;
set local role anon;
do $$
declare
  id uuid := gen_random_uuid();
  op uuid := gen_random_uuid();
  key text := repeat('a',43);
  payload jsonb := '{"version":1,"coins":123,"coinProgress":3,"totalPairs":17,"unlocked":[],"games":{},"highScores":{}}';
  result jsonb;
begin
  result := public.game_backup_save(id,key,payload,0,op);
  if (result->>'revision')::int <> 1 then raise exception 'FAIL: create'; end if;
  result := public.game_backup_save(id,key,payload,0,op);
  if (result->>'revision')::int <> 1 then raise exception 'FAIL: duplicate operation'; end if;
  result := public.game_backup_read(id,key);
  if result->'data' <> payload then raise exception 'FAIL: read'; end if;

  begin
    perform public.game_backup_read(id,repeat('b',43));
    raise exception 'FAIL: wrong key read succeeded';
  exception when others then
    if sqlerrm <> 'BACKUP_NOT_FOUND' then raise; end if;
  end;
  begin
    perform public.game_backup_delete(id,repeat('b',43));
    raise exception 'FAIL: wrong key deletion succeeded';
  exception when others then
    if sqlerrm <> 'BACKUP_NOT_FOUND' then raise; end if;
  end;
  begin
    perform public.game_backup_save(id,key,payload,0,gen_random_uuid());
    raise exception 'FAIL: stale revision accepted';
  exception when others then
    if sqlerrm <> 'BACKUP_CONFLICT' then raise; end if;
  end;
  begin
    perform public.game_backup_save(gen_random_uuid(),key,jsonb_set(payload,'{coins}','-1'),0,gen_random_uuid());
    raise exception 'FAIL: negative coins accepted';
  exception when others then
    if sqlerrm <> 'BACKUP_INVALID' then raise; end if;
  end;
  result := public.game_backup_save(id,key,jsonb_set(payload,'{coins}','222'),1,gen_random_uuid());
  if (result->>'revision')::int <> 2 then raise exception 'FAIL: update'; end if;
  perform public.game_backup_delete(id,key);
  perform public.game_backup_delete(id,key);
  begin
    perform public.game_backup_read(id,key);
    raise exception 'FAIL: deleted progress is readable';
  exception when others then
    if sqlerrm <> 'BACKUP_NOT_FOUND' then raise; end if;
  end;
  raise notice 'PASS: backup permissions, keys, revisions, idempotency and deletion';
end $$;
rollback;
