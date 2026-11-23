# Google Calendar and Gmail connection (v0.5)

This is a **manual, one-way sync**: HQ jobs with a scheduled date are pushed as **all-day events** to the connected Google account's **primary calendar**. Repeated syncs update prior synced events. HQ does not currently import Google events, remove deleted/unscheduled jobs from Google, or sync automatically. Do not assume it is a two-way calendar.

## Setup

1. In Supabase SQL Editor run `supabase/google-calendar-v0.4.sql` once **after** the main database schema.
2. In [Google Cloud Console](https://console.cloud.google.com/), create/select a project. Enable **Google Calendar API** and **Gmail API**. Configure **Google Auth platform / OAuth consent screen** with the requested scopes `openid`, `email`, `https://www.googleapis.com/auth/calendar.events`, and `https://www.googleapis.com/auth/gmail.send`. Add `justtheguyguttersandexterior@gmail.com` as a test user while the app is in testing mode. Publishing or verification may be necessary for wider use.
3. Create an **OAuth client ID** of type **Web application**. Add exactly `https://YOUR-HOST/api/google/callback` under **Authorized redirect URIs**. Use your actual deployment HTTPS address.
4. In your server host's environment variables, set:
   - `APP_BASE_URL` = `https://YOUR-HOST` (no trailing path)
   - `GOOGLE_CLIENT_ID` = Google OAuth client ID
   - `GOOGLE_CLIENT_SECRET` = Google OAuth client secret
   - `GOOGLE_TOKEN_ENCRYPTION_KEY` = a randomly generated long secret (at least 32 bytes; do not commit)
   - `SUPABASE_SERVICE_ROLE_KEY` = Supabase **server-only** service-role key (never prefix with NEXT_PUBLIC_)
   - `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_ANON_KEY` as configured for HQ
5. Redeploy. Sign in to HQ, open **Calendar**, select **Connect Google Calendar**, and authorize access with `justtheguyguttersandexterior@gmail.com`. Reconnect Google after enabling Gmail API so the saved token also receives Gmail sending permission. Then use **Sync jobs to Google** for calendar sync. In Google Cloud testing mode, refresh tokens may expire after 7 days; reconnect when needed.

## Direct estimate and invoice email

HQ can send a document directly from **Send to customer** without opening Gmail or Outlook. The message includes the branded email layout, a PDF attachment, and a secure PDF view link. It can send only through the authorized `justtheguyguttersandexterior@gmail.com` account. The app requests Gmail's send-only scope and does not read the inbox. If sending says Gmail access is missing, reconnect Google Calendar in HQ and approve the added Gmail permission.

**Security:** Never share secrets in chat, GitHub, or client-side variables. Keep your GitHub repository private; never commit `.env.local`. The OAuth refresh token is encrypted server-side with AES-256-GCM. Tokens are stored in private Supabase tables with RLS enabled and no client policies. Replacing the encryption key makes old tokens unreadable and requires reconnection. The PDF view link is a bearer link that expires after 90 days; anyone with that link can view the addressed estimate or invoice until expiry.

**Caution:** The Sync action writes or updates events on the user's primary Google Calendar. Check the entries there before relying on them. If a job gets deleted in HQ, its old Google event is NOT automatically removed. All jobs in HQ are currently dates without times, so exported events are all-day. The connection is intended for an authenticated single-owner MVP, and should be reviewed for multi-user access before adding employees.

