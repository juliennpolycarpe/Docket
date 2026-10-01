# Docket
<<<<<<< HEAD

One list for everything you need to get done, pulled from the apps you already use.

| Tab | Sources |
|---|---|
| **Upcoming Events** | Outlook Calendar, Google Calendar |
| **To Do** | Canvas assignments + your own tasks |
| **Inbox** | Gmail + Outlook, summarized and sorted into High / Medium / Low priority by Claude |

## Layout

```
app/        Flutter app (Windows, macOS, iOS, Android) - not created yet
server/     TypeScript server: connected accounts, syncing, email triage
supabase/   Database schema (Postgres + login, hosted by Supabase)
```

The app logs in with Supabase and reads its tasks/events/emails straight from
the database (row-level security keeps each user to their own rows). The server
does everything that needs a secret: storing connected-account tokens
(encrypted), syncing Canvas/Google/Microsoft, and calling Claude.

## Setup

### 1. Supabase

1. Create a project at [supabase.com](https://supabase.com).
2. Open **SQL Editor**, paste in `supabase/migrations/0001_init.sql`, and run it.
3. **Authentication > Sign In / Providers**: Email is on by default. Google sign-in can be added later.

### 2. Server

```bash
cd server
npm install
cp .env.example .env
npm run gen-key        # paste the output into TOKEN_ENCRYPTION_KEY in .env
npm run dev
```

Fill in `SUPABASE_URL` and `SUPABASE_SECRET_KEY` from **Project Settings > API Keys**.

Other commands: `npm test`, `npm run typecheck`, `npm run build && npm start`.

## Server API

Every request except `/health` needs `Authorization: Bearer <Supabase access token>`.

| Method | Path | Body | What it does |
|---|---|---|---|
| GET | `/health` | | Liveness check |
| POST | `/accounts/canvas` | `{ "baseUrl": "canvas.school.edu", "token": "..." }` | Verify a Canvas token, save it, run the first sync |
| DELETE | `/accounts/:id` | | Disconnect an account and remove its synced data |
| POST | `/sync` | | Sync all of the current user's accounts now |

The server also syncs every account in the background every `SYNC_INTERVAL_MINUTES`.
=======
Organization + To Do List App 
>>>>>>> d458c7300a0e015dec214cf35f1a6031cb2956a6
