# Google Calendar connection (v0.4)

This is a **manual, one-way sync**: HQ jobs with a scheduled date are pushed as **all-day events** to the connected Google account's **primary calendar**. Repeated syncs update prior synced events. HQ does not currently import Google events, remove deleted/unscheduled jobs from Google, or sync automatically. Do not assume it is a two-way calendar.

## Setup

1. In Supabase SQL Editor run `supabase/google-calendar-v0.4.sql` once **after** the main database schema.
2. In [Google Cloud Console](https://console.cloud.google.com/), create/select a project. Enable **Google Calendar API**. Configure **Google Auth platform / OAuth consent screen** for the application and add appropriate test users while in testing mode. Publishing/verifying an app may be necessary for wider use.
3. Create an **OAuth client ID** of type **Web application**. Add exactly `https://YOUR-HOST/api/google/callback` under **Authorized redirect URIs**. Use your actual deployment HTTPS address.
4. In your server host's environment variables, set:
   - `APP_BASE_URL` = `https://YOUR-HOST` (no trailing path)
   - `GOOGLE_CLIENT_ID` = Google OAuth client ID
   - `GOOGLE_CLIENT_SECRET` = Google OAuth client secret
   - `GOOGLE_TOKEN_ENCRYPTION_KEY` = a randomly generated long secret (at least 32 bytes; do not commit)
   - `SUPABASE_SERVICE_ROLE_KEY` = Supabase **server-only** service-role key (never prefix with NEXT_PUBLIC_)
   - `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` as configured for HQ
5. Redeploy. Sign in to HQ, open **Calendar**, select **Connect Google Calendar** and authorize access. Then use **Sync jobs to Google**. In Google Cloud testing mode, refresh tokens may expire after 7 days for this calendar scope; reconnect when needed.

**Security:** Never share secrets in chat, GitHub, or client-side variables. Keep your GitHub repository private; never commit `.env.local`. The OAuth refresh token is encrypted server-side with AES-256-GCM. Tokens are stored in private Supabase tables with RLS enabled and no client policies. Replacing the encryption key makes old tokens unreadable and requires reconnection.

**Caution:** The Sync action writes or updates events on the user's primary Google Calendar. Check the entries there before relying on them. If a job gets deleted in HQ, its old Google event is NOT automatically removed. All jobs in HQ are currently dates without times, so exported events are all-day. The connection is intended for an authenticated single-owner MVP, and should be reviewed for multi-user access before adding employees.
