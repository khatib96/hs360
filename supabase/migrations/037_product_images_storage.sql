-- Phase 3 M1: product_images storage bucket and policies (SECURITY.md section 4).

insert into storage.buckets (id, name, public)
values ('product_images', 'product_images', true)
on conflict (id) do nothing;

drop policy if exists product_images_public_read on storage.objects;
drop policy if exists product_images_admin_write on storage.objects;

create policy product_images_public_read
  on storage.objects
  for select
  to public
  using (bucket_id = 'product_images');

create policy product_images_admin_write
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'product_images'
    and (storage.foldername(name))[1] = current_tenant_id()::text
    and user_has_permission('products.edit')
  );

-- M5: add storage.objects UPDATE/DELETE policies for primary image replace/remove.
-- M1 intentionally allows INSERT only; MVP uses products.image_url as canonical URL.
