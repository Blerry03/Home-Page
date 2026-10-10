# Just The Guy HQ — v0.6 implementation notes

## Before updating production

- **Make a Supabase database backup/export first.** Do not test against irreplaceable production records.
- Use a private GitHub repository. Never commit `.env.local` or secret keys.
- **DO NOT replace your company CRM yet.** This is pre-production software and payment / authorization flows are incomplete.
- The v0.6 migration assumes `schema.sql`, `upgrade-v0.2.sql` where applicable, `google-calendar-v0.4.sql` where applicable, and `upgrade-v0.5.sql` were already applied. v0.6 requires `material_items` and `time_entries` from v0.5.

## GitHub update

1. Download and extract `just-the-guy-hq-v0.6.zip`.
2. In GitHub Desktop, clone your private `Home-Page` repository if you haven't already.
3. Open the repository and find the existing `just-the-guy-hq` directory (the Next.js project root, where `package.json` lives).
4. **Copy the contents** of the ZIP's `just-the-guy-hq` folder into that directory. Replace matching files, including the new `app/field-tools.tsx` and `app/billing-studio.tsx`.
5. Commit and push. If Vercel builds before the database upgrade, new views will show errors; **prefer migrating the test database before deploying.**
6. Confirm in Vercel that the **Root Directory** is `just-the-guy-hq`. Review build errors and environment variables. The `npm install` and Next.js production build could not be completed in the authoring environment (npm registry unavailable).

## Supabase migration

1. **Back up the data.** Open Supabase → SQL Editor, paste `supabase/upgrade-v0.6.sql` and run it once.
2. In Table Editor verify: `measurement_runs`, `job_accessories`, `supplier_prices`, `employees`, `pay_periods`, `document_items`, and `document_payments`.
3. Verify the new job fields for lead source, contact method, salesperson, subcontractor and appointment times.
4. Existing database records are left in place. There are **no destructive DROP TABLE statements**.
5. The schema is single-owner only. Do not share the owner login with salespeople or subcontractors; staff accounts and individual access rules have not been built.

## What is included

- Gutter measurements: separate gutter runs with feet, inches and eighths, color, size, endcaps, notes, totals; accessory counts; a **reviewable material draft** generated from saved job quantities. It does not assume hanger spacing, wastage, or inventory.
- Materials: the v0.5 needed/ordered/received workflow plus supplier price-book entries and **partial/complete cost comparison** for matching material lines. These are manually entered prices, not live ABC Supply or Michigan Aluminum feeds.
- Calendar: month/week/day layouts, optional start and end times, customer/service/location; directions to Google or Apple Maps; one-way manual Google Calendar sync supports event times after OAuth is configured.
- Job form: lead source vs contact method, salesperson, subcontractor, inbound vs outbound subcontracting (text entries).
- Payroll tracker: employee pay rates, hours with saved rate snapshots, date-range totals, period history and paid-date recording. Gross estimate excludes overtime, deductions, withholdings and employer taxes. Former v0.5 hour records remain separate until migrated/linked manually.
- Preliminary reports: period counts and source counts. **Conversion percentages are approximations and can be misleading for multi-estimate or repeat customers.** Accurate conversion requires lead entities, linking and cohort logic; do not rely on for business decisions yet.
- Line-item billing studio: draft line items, editable contract terms, issue dates, tax percentage per line, manual payment/deposit records, balance calculation. **Existing document headline amount is not updated automatically**, and deposits entered on estimates are not yet transferred into invoices.
- Completed job address list links to maps; no interactive pin map yet.

## Not implemented yet (do not use for actual payments or legally binding contracts)

- Customer e-signatures / signature audit trail; contract acceptance and automated estimate-to-job flows.
- Online payment collection (Stripe etc.), cash/check/card choice for online payment, card processing surcharges, automatic deposit transfer, invoices with payment links.
- Real email/SMS sending, chat inbox, delivery logs, message opt-ins.
- Website form → validated lead intake, deduplication, spam defenses and lead assignment.
- Staff roles, real commissions, subcontractor portal, full job-costing, inventory deductions, supplier API purchasing or prices.
- True map pins with geocoding and an address map provider.
- Reliable accounting reports, cash receipt tracking, linked lead conversion cohorts, historical change audits, payroll tax/compliance.
- Automated two-way Google calendar sync (only manual one-way is supported).

**Billing and safety:** Card surcharges require processor/card-network and state-law compliance and cannot simply be added to every card transaction. No payments are charged by this code. No customer's confidential details should be uploaded during testing until authentication, authorization, backups and data policies are independently verified.
