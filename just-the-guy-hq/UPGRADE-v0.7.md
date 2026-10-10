# Just The Guy HQ v0.7 — Employee hours redesign

## What changed
- Employees are added once with their own pay rate.
- The Employee Hours page and Payroll Tracker now open the same employee-specific tracker.
- Select an employee to see **only that employee**'s timesheet, week totals, calendar, and payment history.
- Enter **start/end times**, date, unpaid break minutes and an optional job. Overnight times (e.g. 9 PM to 8:46 AM) are supported; work is credited to the shift start date.
- Each entry captures the pay rate used at the time of entry, preserving historical rate values.
- A Monday–Sunday week view shows each day and subtotal; the per-employee month calendar shows daily hours.
- Pay-period history is saved per person. The app records **estimated straight-time/base pay only**, and cannot calculate legally required overtime, taxes or final payroll. Do not use these numbers as a payroll processor.

## Upgrade
1. Back up Supabase. Make sure v0.5 and v0.6 database upgrades were applied.
2. In Supabase SQL Editor, run `supabase/upgrade-v0.7.sql` once. It adds 3 columns to existing `time_entries`; no existing records are deleted.
3. Copy the updated project's *contents* into your GitHub Desktop clone's `just-the-guy-hq` folder, commit, push, and confirm the Vercel build.
4. Open More → Employee Hours, add an employee, log a shift, review the week and personal calendar.

## Old records
Older Employee Hours records were entered under arbitrary names without an `employee_id`. Those legacy records are preserved but **will not automatically appear under a new employee**. Matching names automatically could attribute time to the wrong person. To backfill safely, first review the unmatched entries and assign their employee IDs with an authenticated data correction procedure.

## Pay limitations
Timesheets and pay history are administrative estimates. Overtime (including overtime spanning multiple entries, weeks and changing rates), state/federal taxes, classification and deductions must be handled by your payroll process. Editing an old entry after recording a pay period may create a mismatch in the saved pay-history snapshot.

## Validation
The source was checked structurally; a full Next.js production build has not been verified in this environment. Test with demo records before using real payroll information.
