-- Docket: initial schema
--
-- The Flutter app talks to these tables directly (row-level security limits
-- each user to their own rows). The TypeScript server uses the secret key,
-- which bypasses RLS, to write synced data and to manage connected accounts.

create type public.provider as enum ('canvas', 'google', 'microsoft');
create type public.task_source as enum ('manual', 'canvas');
create type public.email_priority as enum ('high', 'medium', 'low');

create function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Connected accounts (Canvas, Google, Microsoft). No secrets in this table.
-- ---------------------------------------------------------------------------
create table public.connected_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  provider public.provider not null,
  display_name text not null,        -- shown in the app, e.g. "jdoe@wpi.edu"
  external_user_id text not null,    -- the user's id at the provider
  base_url text,                     -- Canvas only, e.g. https://canvas.wpi.edu
  last_synced_at timestamptz,
  last_sync_error text,
  created_at timestamptz not null default now(),
  unique nulls not distinct (user_id, provider, external_user_id, base_url)
);

-- Encrypted tokens for each connected account (see server/src/crypto.ts).
-- RLS is enabled with no policies, so only the server can read or write it.
create table public.account_credentials (
  account_id uuid primary key references public.connected_accounts (id) on delete cascade,
  access_token text not null,
  refresh_token text,
  expires_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- To Do: Canvas assignments plus tasks the user adds themselves.
-- ---------------------------------------------------------------------------
create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  source public.task_source not null default 'manual',
  account_id uuid references public.connected_accounts (id) on delete cascade,
  external_id text,                  -- e.g. "assignment:12345"
  title text not null,
  notes text,
  course_name text,
  due_at timestamptz,
  url text,
  submitted boolean not null default false,  -- submitted (or marked done) in Canvas; set by sync
  completed boolean not null default false,  -- checked off in Docket; set by the user
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, external_id)
);
create index tasks_user_due_idx on public.tasks (user_id, due_at);
create trigger tasks_touch_updated_at before update on public.tasks
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Upcoming Events: Outlook and Google Calendar.
-- ---------------------------------------------------------------------------
create table public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.connected_accounts (id) on delete cascade,
  external_id text not null,
  title text not null,
  location text,
  starts_at timestamptz not null,
  ends_at timestamptz,
  all_day boolean not null default false,
  url text,
  updated_at timestamptz not null default now(),
  unique (account_id, external_id)
);
create index events_user_start_idx on public.events (user_id, starts_at);

-- ---------------------------------------------------------------------------
-- Inbox: emails from Gmail and Outlook, triaged by Claude.
-- priority is null until the email has been triaged.
-- ---------------------------------------------------------------------------
create table public.emails (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  account_id uuid not null references public.connected_accounts (id) on delete cascade,
  external_id text not null,
  from_name text,
  from_address text,
  subject text,
  received_at timestamptz not null,
  url text,
  summary text,
  priority public.email_priority,
  priority_reason text,
  deadline timestamptz,
  triaged_at timestamptz,
  dismissed boolean not null default false,
  unique (account_id, external_id)
);
create index emails_user_received_idx on public.emails (user_id, received_at desc);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
alter table public.connected_accounts enable row level security;
alter table public.account_credentials enable row level security;
alter table public.tasks enable row level security;
alter table public.events enable row level security;
alter table public.emails enable row level security;

-- Connecting and disconnecting accounts goes through the server.
create policy "read own accounts" on public.connected_accounts
  for select to authenticated using (user_id = (select auth.uid()));

create policy "read own tasks" on public.tasks
  for select to authenticated using (user_id = (select auth.uid()));
create policy "add own manual tasks" on public.tasks
  for insert to authenticated with check (
    user_id = (select auth.uid()) and source = 'manual'
    and account_id is null and external_id is null
  );
create policy "update own tasks" on public.tasks
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "delete own manual tasks" on public.tasks
  for delete to authenticated using (user_id = (select auth.uid()) and source = 'manual');

create policy "read own events" on public.events
  for select to authenticated using (user_id = (select auth.uid()));

create policy "read own emails" on public.emails
  for select to authenticated using (user_id = (select auth.uid()));
create policy "update own emails" on public.emails
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

-- Limit which columns the app may change. Everything else is written by the server.
revoke update on public.tasks from authenticated;
grant update (title, notes, due_at, completed) on public.tasks to authenticated;
revoke update on public.emails from authenticated;
grant update (dismissed) on public.emails to authenticated;

-- Push changes to the app live when the server syncs new data.
alter publication supabase_realtime add table public.tasks, public.events, public.emails;
