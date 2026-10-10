-- Just The Guy HQ v0.7; RUN AFTER v0.5 and v0.6 upgrades.
-- Add optional clock-in/out fields to the existing per-employee entries.
-- Existing entries remain intact, and historical decimal-hour entries continue to display.
alter table public.time_entries add column if not exists start_time time without time zone;
alter table public.time_entries add column if not exists end_time time without time zone;
alter table public.time_entries add column if not exists break_minutes integer not null default 0;
-- Hourly rates are already snapshotted by v0.6; per-employee pay_periods already exist.
-- A work_date represents the start date for an overnight shift.
-- The app groups employees by employee_id, not the typed name, to prevent mixing records.
