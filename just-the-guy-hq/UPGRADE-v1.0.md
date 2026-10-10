# Just The Guy HQ v1.0 — Direct estimate and invoice creation

## What changed
- **New Estimate** and **New Invoice** now open a complete creation workspace instead of the old **Add document** modal.
- Select customer, property, related job and recipient address in the editor.
- Set issue date, due/expiration date, PO, contract terms, and optional title.
- Add/edit/remove line items *before* saving. Prices, quantities, tax rates, and discounts update totals instantly.
- **Save Draft** creates the document with all its initial line items, then opens the existing detailed editor for further editing or payment records.
- The old generic document modal remains available only from the existing document's **Edit recipient / document record** action.

## Update GitHub
1. Make a backup or Git commit first.
2. Unzip this package and copy the **contents** of `just-the-guy-hq/` into the same folder of your cloned `Home-Page` repository.
3. Commit and push to `main`. Check Vercel's new deployment.
4. Go to More → Estimates → New Estimate, or More → Invoices → New Invoice.

## Database
No new SQL migration for v1.0. Previous upgrades through `upgrade-v0.8.sql` must have been applied. Requires `documents`, `document_items`, and billing columns from prior releases.

## Boundaries and safety
- Drafts are saved only when you click **Save Draft**; unsaved line items will be lost if you close the page.
- A failed line-item insertion attempts to remove the new empty document; check records if a rollback error is reported.
- **No PDF generation, email delivery, electronic signatures, or card processing is active.** Nothing is sent to customers from this editor.
- Existing document line-item totals and parent `documents.amount` may not yet stay synchronized after edits; reconcile manually before using this for actual billing.
- Run a Vercel production build and test with dummy records first. No completed Next.js build was possible in the development environment.
