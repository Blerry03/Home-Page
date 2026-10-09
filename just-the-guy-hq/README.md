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
