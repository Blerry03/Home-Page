# HQ development backlog

All changes target `hq-upgrades-test` and Just The Guy HQ Test. Production and customer communications require separate authorization.

| Priority | Work | Status |
| --- | --- | --- |
| 1 | Organization access and audit trail | Test policies, privilege grants, and audit triggers installed. Shared workspace owner verified. Individual accounts require a separate provisioning decision. |
| 1 | Reliability | Add activity views, safe synchronization, stale-write protection, recoverable deletes, duplicate prevention, restore verification, and monitoring. |
| 2 | Customer intake and calendar | Customer lookup now includes contact details and service addresses. Next, create the customer, property, and appointment in one transaction from the calendar. Add appointment times, crew assignments, dispatch, and conflict checks. |
| 2 | Dashboard and CRM | Add global search, linked timelines, reminders, configurable widgets, lead tracking, and mobile quick actions. |
| 3 | Estimate to payment | Extend gutter pricing presets, branded PDFs, approvals, conversion to jobs and invoices, portal, balances, and reconciliation. Configure email, SMS, and Square only with authorized test credentials. |
| 4 | Field operations | Expand measurements, preparation lists, inventory, suppliers, checklists, photos and file storage, employee hours, subcontractors, and job costing. |
| 5 | Bookkeeping and reporting | Add duplicate-safe transaction imports, merchant rules, receipt matching, accountant exports, and reports from actual records. |
| 5 | Marketing and automation | Add authorized lead sources, deduplicated follow-ups, and an automation log. |
| Throughout | Product design | Apply the company color palette, responsive layouts, accessible controls, and user preferences while preserving existing features. |

Reference workflows include [Housecall Pro scheduling](https://help.housecallpro.com/en/articles/6758788-scheduling-jobs-and-estimates), [Jobber quote approvals](https://help.getjobber.com/en/articles/quote-approvals/), [ServiceTitan dispatch](https://help.servicetitan.com/v1/docs/dispatch-pro-overview), and [CompanyCam project links](https://help.companycam.com/en/articles/8653668-using-the-companycam-quickbooks-online-integration). For HQ, the common thread is linking work to the customer and service property from intake through payment.

Before closing an item, record its Preview build, database permission tests where relevant, and functional checks. Review desktop and mobile behavior before calling a user-facing module complete.
