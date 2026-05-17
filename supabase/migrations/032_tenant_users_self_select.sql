-- Phase 2 M2: allow authenticated users to read their own tenant_users row for session bootstrap.
-- Does not grant settings.users.view or access to other users' rows.

create policy tenant_users_select_self
  on tenant_users
  for select
  to authenticated
  using (user_id = auth.uid());
