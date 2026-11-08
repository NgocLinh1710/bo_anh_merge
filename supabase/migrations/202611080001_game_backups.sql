-- Run once in Supabase SQL Editor as the project owner. No Google Auth needed.
begin;
create schema if not exists game_backup_private;
revoke all on schema game_backup_private from public, anon, authenticated;

create table if not exists game_backup_private.backups (
  id uuid primary key,
  key_hash bytea not null,
  payload jsonb not null check (octet_length(payload::text) <= 16384),
  revision bigint not null check (revision > 0),
  last_operation uuid not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table game_backup_private.backups enable row level security;
revoke all on game_backup_private.backups from public, anon, authenticated;
create index if not exists backups_created_at on game_backup_private.backups(created_at);

create or replace function public.game_backup_save(
  p_id uuid, p_key text, p_payload jsonb, p_expected_revision bigint, p_operation uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  b game_backup_private.backups%rowtype;
  h bytea;
begin
  if p_id is null or p_operation is null or p_key is null or p_key !~ '^[A-Za-z0-9_-]{43}$'
     or p_expected_revision is null or p_expected_revision < 0 then
    raise exception 'BACKUP_NOT_FOUND';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) is distinct from 'object'
     or octet_length(p_payload::text) > 16384
     or (p_payload->>'version') is distinct from '1'
     or not (p_payload ?& array['coins','coinProgress','totalPairs','unlocked','games','highScores'])
     or coalesce(p_payload->>'coins','') !~ '^[0-9]{1,15}$'
     or coalesce(p_payload->>'totalPairs','') !~ '^[0-9]{1,15}$'
     or coalesce(p_payload->>'coinProgress','') !~ '^([0-9]|1[0-3])$'
     or jsonb_typeof(p_payload->'unlocked') is distinct from 'array'
     or jsonb_typeof(p_payload->'games') is distinct from 'object'
     or jsonb_typeof(p_payload->'highScores') is distinct from 'object'
     or p_payload ? 'backupLink' then
    raise exception 'BACKUP_INVALID';
  end if;
  h := pg_catalog.sha256(pg_catalog.convert_to(p_id::text || ':' || p_key, 'UTF8'));
  -- Serialize new registrations to enforce a bounded free-tier storage budget.
  if p_expected_revision = 0 then perform pg_catalog.pg_advisory_xact_lock(14021402); end if;
  select * into b from game_backup_private.backups where id = p_id for update;
  if not found then
    if p_expected_revision <> 0 then raise exception 'BACKUP_NOT_FOUND'; end if;
    if (select count(*) from game_backup_private.backups) >= 15000
       or (select count(*) from game_backup_private.backups where created_at >= date_trunc('day', now())) >= 1000 then
      raise exception 'BACKUP_LIMIT';
    end if;
    insert into game_backup_private.backups(id,key_hash,payload,revision,last_operation)
      values(p_id,h,p_payload,1,p_operation) returning * into b;
  else
    if b.key_hash <> h then raise exception 'BACKUP_NOT_FOUND'; end if;
    if b.last_operation = p_operation then
      return jsonb_build_object('revision', b.revision, 'savedAt', b.updated_at);
    end if;
    if b.revision <> p_expected_revision then raise exception 'BACKUP_CONFLICT'; end if;
    update game_backup_private.backups set payload = p_payload, revision = revision + 1,
      last_operation = p_operation, updated_at = now() where id = p_id returning * into b;
  end if;
  return jsonb_build_object('revision', b.revision, 'savedAt', b.updated_at);
end;
$$;

create or replace function public.game_backup_read(p_id uuid, p_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b game_backup_private.backups%rowtype;
begin
  if p_key is null or p_key !~ '^[A-Za-z0-9_-]{43}$' then raise exception 'BACKUP_NOT_FOUND'; end if;
  select * into b from game_backup_private.backups
    where id = p_id and key_hash = pg_catalog.sha256(pg_catalog.convert_to(p_id::text || ':' || p_key, 'UTF8'));
  if not found then raise exception 'BACKUP_NOT_FOUND'; end if;
  return jsonb_build_object('data', b.payload, 'revision', b.revision, 'savedAt', b.updated_at);
end;
$$;

create or replace function public.game_backup_delete(p_id uuid, p_key text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare b game_backup_private.backups%rowtype;
begin
  if p_id is null or p_key is null or p_key !~ '^[A-Za-z0-9_-]{43}$' then raise exception 'BACKUP_NOT_FOUND'; end if;
  select * into b from game_backup_private.backups where id = p_id for update;
  if found then
    if b.key_hash <> pg_catalog.sha256(pg_catalog.convert_to(p_id::text || ':' || p_key, 'UTF8')) then raise exception 'BACKUP_NOT_FOUND'; end if;
    delete from game_backup_private.backups where id = p_id;
  end if;
  -- Safe to retry when a previous delete succeeded but its response was lost.
  return jsonb_build_object('deleted', true);
end;
$$;

revoke all on function public.game_backup_save(uuid,text,jsonb,bigint,uuid) from public, anon, authenticated;
revoke all on function public.game_backup_read(uuid,text) from public, anon, authenticated;
revoke all on function public.game_backup_delete(uuid,text) from public, anon, authenticated;
grant execute on function public.game_backup_save(uuid,text,jsonb,bigint,uuid) to anon;
grant execute on function public.game_backup_read(uuid,text) to anon;
grant execute on function public.game_backup_delete(uuid,text) to anon;
notify pgrst, 'reload schema';
commit;
