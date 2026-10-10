# Just The Guy HQ — MVP 0.1

A real starter web app for Just The Guy Gutters & Exteriors. Mobile-friendly dashboard; customers; each customer's contacts and properties; jobs; HOA estimate/billing contact distinction; client search. No invoices or outgoing messaging yet.

## Try it instantly (demo mode)

Requires Node.js 20.9+.

```bash
npm install
npm run dev
```

Open http://localhost:3000. Without Supabase environment variables, the app runs in **browser-only DEMO mode**. Demo records persist in the current browser's localStorage, **are not backed up**, and are not appropriate for real customer information. Clearing browser data removes them.

## Connect your own secure database

1. Create a Supabase project. Under **SQL Editor**, run `supabase/schema.sql`.
2. In Supabase **Authentication > Providers**, enable Email (default). Configure email verification; use a unique strong password and MFA where available.
3. Copy your project's URL and **publishable/anon key** into a new `.env.local` file based on `.env.example`. **Never put a service_role key in NEXT_PUBLIC variables.**
4. Restart `npm run dev`. You'll see sign-up/sign-in instead of demo mode.
5. After signing in, create the business account. Customers, contacts, properties, and jobs now save to Supabase under your authenticated account. Row-level security is enabled.

## What's in scope

* Real create/read/update/delete for customers, properties, contacts, and jobs (live Supabase mode or temporary demo mode).
* Search clients; view client details and relationships; dashboard with counts.
* Role-aware contact information: estimator/approvals and billing contact separately (data-model support only).
* Owner-only authenticated access with Supabase RLS. Staff access is **not** implemented yet.

## Not yet included

Estimates, invoices, payments, customer email/text sending, calendar drag/drop, scheduling reminders, staff permissions, imports, material costs, photo storage, audit history, or an authenticated server-side integration for payment processing. Do not retire Townsquare or Housecall Pro yet.

## Hosting

This is a standard Next.js application. It can be hosted on Vercel or another Next-compatible Node host. Configure the two environment variables on the hosting provider, set Supabase Auth allowed site/redirect URLs, and use HTTPS. Production hardening (audit logs, backups, invitation flow, data export, end-to-end tests) should be completed before migrating real company operations.

## Next build stages

1. Estimates with reusable line items, PDFs, approval status and estimate-specific recipients.
2. Invoices, invoice-specific recipients, deposit and payment records.
3. Calendar, crews, materials, photos, production measurements, checklists.
4. Email/SMS integrations, automations, customer portal, reports, staff permissions.

## Version 0.2 — nested properties and separate estimate/invoice recipients

- Open **Customers → select a customer → Properties → Open property** to see the jobs, estimates and invoices attached to that property. Every property belongs to a single customer; an HOA can have many properties.
- Open **Estimates** or **Invoices** in the sidebar. Documents can select their own customer, property, optional job, contact and **send-to email** independently. A draft estimate can go to the approval contact and an invoice to accounting while both remain under the same customer/property.
- **Email draft** opens your configured email client with the recipient, subject and basic summary populated. **It does NOT send an email, produce/attach a PDF, or change a status to sent.** A full branded document/line-item system, provider-backed sending, approval links and payment tracking are future work. Never use a draft email as proof of delivery.
- For a *fresh Supabase project*, execute `supabase/schema.sql` once (after reviewing it). If the earlier v0.1 schema was applied already, execute **only the new documents portion** at the bottom; see `supabase/upgrade-v0.2.sql`.
- Demo records are illustrative and remain in browser storage only. Real client details belong only in a secured, tested Supabase deployment with backups.

### GitHub upload (new repository)

1. On GitHub, create a **private**, empty repository named `just-the-guy-hq` (do not add a README in GitHub).
2. Extract this ZIP and open a terminal inside the `just-the-guy-hq` folder.
3. Run `git init`, `git add .`, `git commit -m "Start Just The Guy HQ"`, `git branch -M main`, `git remote add origin https://github.com/YOUR-USERNAME/just-the-guy-hq.git`, and `git push -u origin main`.
4. Keep `.env.local` private; never commit Supabase secret/service-role keys. Use **only** the public anon key in browser variables and enforce Supabase RLS.
5. Install Node.js 20+; run `npm install`, then `npm run dev`. Open `http://localhost:3000`.

**Testing note:** This environment has not run a successful Next.js dependency installation or production build. Verify locally before deployment or customer-data use.


## Version 0.3 — Minimal navigation + daily command center

- Main navigation: **Dashboard, Customers, Calendar, More**. Under **More**: existing Jobs, Estimates, and Invoices pages. None of the existing CRUD functionality was intentionally removed.
- Dashboard: Today's schedule, pending estimates (draft/sent), unpaid invoices (not paid/void), quick actions, new leads (jobs with Lead status), and sections reserved for materials and employee hours. Materials and hours are **not stored or totaled yet**; these sections explicitly say they're not set up.
- Calendar: monthly grid on desktop and job list on mobile; scheduled entries show **customer name, job title/service, and property street/city/state**, and can be clicked to edit the job. Appointment times are **not yet stored** in the `jobs` table; the calendar intentionally does not invent times. To show a location, attach a property to the job.
- No database migrations required for this UI-only release. Existing Supabase schema from v0.2 is sufficient.

### Updating an existing GitHub website

Your existing GitHub layout places all Next.js files under `just-the-guy-hq/`. **Keep that folder layout** and leave your Vercel Root Directory as `just-the-guy-hq`. The simplest update changes only two files: `just-the-guy-hq/app/page.tsx` and `just-the-guy-hq/app/globals.css`. For each file, open it in GitHub, choose the pencil (Edit), replace its contents with the new file's contents, and commit to your branch. Vercel should build automatically after both changes are committed if auto deployments are enabled. Alternatively use GitHub Desktop to copy both updated files into the matching locations, then commit and push. Do not upload the ZIP itself into GitHub.

### Validation

TypeScript/TSX syntax transcription check completed using TypeScript transpilation, no syntax diagnostics. **A full Next.js build could not be completed here** because dependency installation stalled. Verify the deployment build logs and test key pages before entering real customer data.


## Version 0.4 — Calendar redesign + Google Calendar connector

- **Dashboard:** Schedule stays in an easy-to-read **list**, with customer name, service name and address for every job that has a property selected.
- **Calendar:** Full month grid (including on phones), click/tap a day and read the complete jobs in the **day agenda** beside/below the month. Add a job directly on a selected day. No fictional appointment times: jobs currently store a date only.
- **Google Calendar:** Authenticated Google OAuth integration with a **manual, one-way** “Sync jobs to Google” action. HQ scheduled dates create/update all-day events in the connected Google primary calendar. **It does not read Google events back into HQ or remove deleted HQ jobs from Google.** The link requires Google Cloud OAuth configuration, server-side env secrets, and the one-time `supabase/google-calendar-v0.4.sql` migration. See `GOOGLE-CALENDAR-SETUP.md`.
- Deploying UI changes does not automatically connect Google; follow the setup checklist before clicking Connect.
- All secrets belong only in your hosting environment settings, never GitHub.
- Validation: TypeScript syntax/transpilation check passed for the project's TS/TSX files. Complete install/Next.js build was unavailable in the authoring environment; confirm Vercel's production build and test in your deployment.


## v0.5 — Materials and employee hours
Run `supabase/upgrade-v0.5.sql` **once** in your existing Supabase project's SQL Editor before using the new modules. It creates `material_items` and `time_entries` with owner-only RLS. **Do not rerun or drop your original schema.**

In the dashboard and **More** menu, use **Materials** to add needed supplies (optionally tied to a job) and mark them needed, ordered or received. Use **Employee hours** to record a worker's name, work date, number of hours, optional job and notes. These entries do not run payroll and are not employee self-service or automated clock-ins.

Demo mode uses separate browser local storage key `jtg-operations-v05`; don't enter real business data there. The web app must be tested with actual Supabase migrations, login, RLS and a production build before using real business records.

### Feature roadmap (not yet implemented)
1. Quote/invoice line items, taxes, discounts, PDFs, signature approvals, deposits, partial payments and real email delivery.
2. Full scheduling with appointment times, crew assignment, recurring jobs, Google Calendar automatic sync, dispatch and reminders.
3. Job photos, file attachments, checklists, measurements, gutter estimator and material consumption/job costing.
4. Lead capture forms, activity history, automated follow-ups, two-way SMS/email, portal and marketing.
5. Staff accounts with roles and audit history, reporting, exports/backups, accounting integrations, online payment processing and security review.

Never put OAuth secrets, Supabase service-role keys, customer data, or passwords into GitHub.

---

## v0.6 expanded modules

**Read `UPGRADE-v0.6.md` before deploying.** Run `supabase/upgrade-v0.6.sql` on a backed-up Supabase project after the v0.5 upgrade. Added features include measurement run capture and draft shopping lists, supplier price catalog, employee rates/pay history, preliminary job analytics, optional calendar times and map links, salesperson/subcontractor fields, and an internal document line-item/payment ledger. All external payment, e-sign, communication and automatic intake features remain incomplete. Do not use this release as a replacement for production billing or payroll software.
