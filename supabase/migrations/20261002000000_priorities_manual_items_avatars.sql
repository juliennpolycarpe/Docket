-- Priorities on every item, items you add yourself in every list, and profile pictures.

-- ---------------------------------------------------------------------------
-- One priority type for tasks, events and inbox items.
-- ---------------------------------------------------------------------------
alter type public.email_priority rename to priority;

-- null = automatic: worked out from the due date / start time in the app.
alter table public.tasks add column priority public.priority;
grant update (priority) on public.tasks to authenticated;

-- ---------------------------------------------------------------------------
-- Events: allow ones you add yourself (no connected account).
-- ---------------------------------------------------------------------------
alter table public.events
  alter column user_id set default auth.uid(),
  alter column account_id drop not null,
  alter column external_id drop not null,
  add column priority public.priority,
  add column notes text;

create trigger events_touch_updated_at before update on public.events
  for each row execute function public.touch_updated_at();

create policy "add own manual events" on public.events
  for insert to authenticated with check (
    user_id = (select auth.uid()) and account_id is null and external_id is null
  );
create policy "update own events" on public.events
  for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "delete own manual events" on public.events
  for delete to authenticated using (user_id = (select auth.uid()) and account_id is null);

revoke update on public.events from authenticated;
grant update (title, location, notes, starts_at, ends_at, all_day, priority) on public.events to authenticated;

-- ---------------------------------------------------------------------------
-- Inbox: emails plus items you add yourself, so the table is renamed.
-- For emails, summary is Claude's summary; for your own items it's your notes.
-- ---------------------------------------------------------------------------
alter table public.emails rename to inbox_items;
alter table public.inbox_items rename column subject to title;
alter table public.inbox_items
  alter column user_id set default auth.uid(),
  alter column account_id drop not null,
  alter column external_id drop not null,
  alter column received_at set default now();

alter policy "read own emails" on public.inbox_items rename to "read own inbox items";
alter policy "update own emails" on public.inbox_items rename to "update own inbox items";
create policy "add own manual inbox items" on public.inbox_items
  for insert to authenticated with check (
    user_id = (select auth.uid()) and account_id is null and external_id is null
  );
create policy "delete own manual inbox items" on public.inbox_items
  for delete to authenticated using (user_id = (select auth.uid()) and account_id is null);

grant update (title, summary, priority, deadline, dismissed) on public.inbox_items to authenticated;

-- ---------------------------------------------------------------------------
-- Profile pictures: public bucket, each user can only write their own folder.
-- Files live at avatars/<user id>/...
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/png', 'image/jpeg', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

create policy "read own avatar files" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "upload own avatar" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "replace own avatar" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "delete own avatar" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid())::text);
