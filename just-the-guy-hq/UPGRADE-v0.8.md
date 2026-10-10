# Just The Guy HQ v0.8 — Townsquare-inspired billing editor

## What changed
- Collapsible From / Bill To / Details / Items / Deposits panels.
- Slide-in Add Item form with item name, description, unit price, quantity, tax, and $ / % discount.
- Option to save an item in a reusable price catalog.
- Edit/remove individual line items. Clear subtotal, discount, tax, payment and balance breakdowns.
- Added issue date, optional due/expiration date, and PO/reference fields.
- Still no automated PDF emailing, signatures, online deposits, or payment charges.

## Upgrade
1. Back up Supabase first. Keep your v0.7 deployment in GitHub for rollback.
2. Supabase SQL Editor: run `supabase/upgrade-v0.8.sql` **once** after earlier migrations. Do not rerun base schema.
3. Replace the old `just-the-guy-hq` project folder's files with the files in this ZIP. Commit and push to your Home-Page GitHub repository.
4. Verify the Vercel build and open **More → Billing Studio** to try it.
5. Select an existing estimate/invoice (create document from Estimates or Invoices first), then add items.

## Important
- Editing line items in Billing Studio currently does not update the legacy `documents.amount` field. Billing Studio shows recalculated totals; legacy dashboard/document list may still display the original amount until document totals are unified in a future release.
- The document form for initially creating a document remains as in v0.7. The enhanced editor opens under Billing Studio after the document is created.
- Historical payments linked to estimates are not automatically allocated to invoices; never record a payment twice.
- Demo mode uses browser localStorage; use Supabase for persistent, multi-device records.
- A complete Next.js production build has not been verified here. Test the deployment before using business-critical data.
