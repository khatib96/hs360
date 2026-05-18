-- Phase 2 M3 follow-up: make seeded local auth users compatible with GoTrue password login.
-- The original seed inserted auth.users directly before M3 verification needed API login.

update auth.users
set
  instance_id = '00000000-0000-0000-0000-000000000000',
  confirmation_token = coalesce(confirmation_token, ''),
  recovery_token = coalesce(recovery_token, ''),
  email_change_token_new = coalesce(email_change_token_new, ''),
  email_change = coalesce(email_change, ''),
  email_change_token_current = coalesce(email_change_token_current, ''),
  phone_change = coalesce(phone_change, ''),
  phone_change_token = coalesce(phone_change_token, ''),
  reauthentication_token = coalesce(reauthentication_token, ''),
  email_change_confirm_status = coalesce(email_change_confirm_status, 0),
  is_sso_user = false,
  is_anonymous = false,
  updated_at = now()
where id in (
  '00000000-0000-0000-0000-000000000201',
  '00000000-0000-0000-0000-000000000202',
  '00000000-0000-0000-0000-000000000203',
  '00000000-0000-0000-0000-000000000204',
  '00000000-0000-0000-0000-000000000205'
);
