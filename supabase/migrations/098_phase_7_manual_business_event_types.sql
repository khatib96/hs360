-- Phase 7 M7A (part 1): extend calendar_event_type with manual business categories.
-- Enum ADD VALUE must commit before RPCs/casts that use the new labels (same pattern as
-- billing_due in 090 → usage in 091). Do not reference these labels in this migration.

alter type public.calendar_event_type add value if not exists 'customer_visit';
alter type public.calendar_event_type add value if not exists 'internal_meeting';
alter type public.calendar_event_type add value if not exists 'internal_task';
alter type public.calendar_event_type add value if not exists 'internal_activity';
-- `custom` already exists from 003_enums.sql
