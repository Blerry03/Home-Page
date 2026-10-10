# Just The Guy HQ v0.9 — Estimates and Invoices direct editor

The stand-alone Billing Studio menu has been removed. Open **More → Estimates** or **More → Invoices**, then select a document to edit its line items, taxes, discounts, dates, and payments on that same page. New documents start with a short customer/property/recipient setup form; after you click Save, the detailed editor opens automatically. The “Edit customer, recipient & details” button opens that setup form again without leaving the editor.

## Update
1. Make a backup of your Supabase database and GitHub repo.
2. Extract this ZIP and copy the contents of `just-the-guy-hq` over the same folder in the `Home-Page` GitHub repository, replacing matching files. Commit and push.
3. Wait for Vercel to deploy, then test creating and editing a draft estimate and invoice.
4. **No new v0.9 SQL migration is needed.** This editor requires the **v0.8 SQL upgrade** already applied to Supabase for document_items and billing_catalog.

## Limitations
This version does not send emails, attach PDFs, collect online payments, or capture verified signatures. Saving line-item totals currently does not automatically update the amount stored in the main `documents` record; this reconciliation needs another improvement before production invoicing. Complete production build and integration tests must be performed after deployment.
