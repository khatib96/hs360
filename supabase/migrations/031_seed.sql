-- Phase 1D: repeatable local seed for RLS verification.
-- Test password for all seeded auth users: Password123!

do $$
declare
  v_tenant_a uuid := '00000000-0000-0000-0000-000000000101';
  v_tenant_b uuid := '00000000-0000-0000-0000-000000000102';

  v_owner_user uuid := '00000000-0000-0000-0000-000000000201';
  v_zero_user uuid := '00000000-0000-0000-0000-000000000202';
  v_products_user uuid := '00000000-0000-0000-0000-000000000203';
  v_tenant_b_user uuid := '00000000-0000-0000-0000-000000000204';
  v_field_user uuid := '00000000-0000-0000-0000-000000000205';

  v_owner_tu uuid := '00000000-0000-0000-0000-000000000301';
  v_zero_tu uuid := '00000000-0000-0000-0000-000000000302';
  v_products_tu uuid := '00000000-0000-0000-0000-000000000303';
  v_tenant_b_tu uuid := '00000000-0000-0000-0000-000000000304';
  v_field_tu uuid := '00000000-0000-0000-0000-000000000305';

  v_kwd_a uuid := '00000000-0000-0000-0000-000000000401';
  v_kwd_b uuid := '00000000-0000-0000-0000-000000000402';

  v_cash uuid := '00000000-0000-0000-0000-000000000501';
  v_bank uuid := '00000000-0000-0000-0000-000000000502';
  v_ar uuid := '00000000-0000-0000-0000-000000000503';
  v_ap uuid := '00000000-0000-0000-0000-000000000504';
  v_inventory uuid := '00000000-0000-0000-0000-000000000505';
  v_revenue uuid := '00000000-0000-0000-0000-000000000506';
  v_cogs uuid := '00000000-0000-0000-0000-000000000507';
  v_expense uuid := '00000000-0000-0000-0000-000000000508';
  v_b_cash uuid := '00000000-0000-0000-0000-000000000509';

  v_owner_employee uuid := '00000000-0000-0000-0000-000000000601';
  v_field_employee uuid := '00000000-0000-0000-0000-000000000602';
  v_warehouse_employee uuid := '00000000-0000-0000-0000-000000000603';

  v_main_warehouse uuid := '00000000-0000-0000-0000-000000000701';
  v_van_warehouse uuid := '00000000-0000-0000-0000-000000000702';

  v_devices_group uuid := '00000000-0000-0000-0000-000000000801';
  v_oils_group uuid := '00000000-0000-0000-0000-000000000802';
  v_perfumes_group uuid := '00000000-0000-0000-0000-000000000803';
  v_b_group uuid := '00000000-0000-0000-0000-000000000804';

  v_product_a uuid := '00000000-0000-0000-0000-000000000901';
  v_product_b uuid := '00000000-0000-0000-0000-000000000902';
begin
  insert into auth.users (
    id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  )
  values
    (v_owner_user, 'authenticated', 'authenticated', 'owner@hayat-secret.test', extensions.crypt('Password123!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Hayat Owner"}', now(), now()),
    (v_zero_user, 'authenticated', 'authenticated', 'zero@hayat-secret.test', extensions.crypt('Password123!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Zero Permission User"}', now(), now()),
    (v_products_user, 'authenticated', 'authenticated', 'products@hayat-secret.test', extensions.crypt('Password123!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Products User"}', now(), now()),
    (v_tenant_b_user, 'authenticated', 'authenticated', 'owner@tenant-b.test', extensions.crypt('Password123!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Tenant B Owner"}', now(), now()),
    (v_field_user, 'authenticated', 'authenticated', 'field@hayat-secret.test', extensions.crypt('Password123!', extensions.gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"name":"Field Agent"}', now(), now())
  on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  )
  values
    (v_owner_user::text, v_owner_user, jsonb_build_object('sub', v_owner_user::text, 'email', 'owner@hayat-secret.test', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now()),
    (v_zero_user::text, v_zero_user, jsonb_build_object('sub', v_zero_user::text, 'email', 'zero@hayat-secret.test', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now()),
    (v_products_user::text, v_products_user, jsonb_build_object('sub', v_products_user::text, 'email', 'products@hayat-secret.test', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now()),
    (v_tenant_b_user::text, v_tenant_b_user, jsonb_build_object('sub', v_tenant_b_user::text, 'email', 'owner@tenant-b.test', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now()),
    (v_field_user::text, v_field_user, jsonb_build_object('sub', v_field_user::text, 'email', 'field@hayat-secret.test', 'email_verified', true, 'phone_verified', false), 'email', now(), now(), now())
  on conflict (provider_id, provider) do nothing;

  insert into tenants (id, name, slug, default_locale, country_code, timezone)
  values
    (v_tenant_a, 'Hayat Secret', 'hayat-secret', 'ar', 'KW', 'Asia/Kuwait'),
    (v_tenant_b, 'Tenant B Test', 'tenant-b-test', 'en', 'KW', 'Asia/Kuwait')
  on conflict (id) do nothing;

  insert into tenant_users (id, tenant_id, user_id, account_type, display_name, preferred_locale, is_active)
  values
    (v_owner_tu, v_tenant_a, v_owner_user, 'manager', 'Hayat Owner', 'ar', true),
    (v_zero_tu, v_tenant_a, v_zero_user, 'user', 'Zero Permission User', 'ar', true),
    (v_products_tu, v_tenant_a, v_products_user, 'user', 'Products User', 'en', true),
    (v_tenant_b_tu, v_tenant_b, v_tenant_b_user, 'manager', 'Tenant B Owner', 'en', true),
    (v_field_tu, v_tenant_a, v_field_user, 'user', 'Field Agent', 'ar', true)
  on conflict (tenant_id, user_id) do nothing;

  insert into permissions (id, module, action, scope, field_name, label_ar, label_en, is_sensitive, category, sort_order)
  values
    ('audit_log.view','audit_log','view','action',null,'audit_log.view','View audit log',true,'security',10),
    ('calendar.create','calendar','create','action',null,'calendar.create','Create calendar events',false,'calendar',20),
    ('calendar.delete','calendar','delete','action',null,'calendar.delete','Delete calendar events',false,'calendar',21),
    ('calendar.edit','calendar','edit','action',null,'calendar.edit','Edit calendar events',false,'calendar',22),
    ('calendar.view','calendar','view','action',null,'calendar.view','View calendar events',false,'calendar',23),
    ('calendar.view_assigned','calendar','view_assigned','action',null,'calendar.view_assigned','View assigned calendar events',false,'calendar',24),
    ('chart_of_accounts.create','chart_of_accounts','create','action',null,'chart_of_accounts.create','Create chart accounts',true,'accounting',30),
    ('chart_of_accounts.delete','chart_of_accounts','delete','action',null,'chart_of_accounts.delete','Delete chart accounts',true,'accounting',31),
    ('chart_of_accounts.edit','chart_of_accounts','edit','action',null,'chart_of_accounts.edit','Edit chart accounts',true,'accounting',32),
    ('chart_of_accounts.view','chart_of_accounts','view','action',null,'chart_of_accounts.view','View chart accounts',false,'accounting',33),
    ('contracts.create','contracts','create','action',null,'contracts.create','Create contracts',false,'sales',40),
    ('contracts.delete','contracts','delete','action',null,'contracts.delete','Delete contracts',true,'sales',41),
    ('contracts.edit','contracts','edit','action',null,'contracts.edit','Edit contracts',false,'sales',42),
    ('contracts.oil_change','contracts','oil_change','action',null,'contracts.oil_change','Change contract oil',false,'sales',43),
    ('contracts.oil_change.delete','contracts','oil_change.delete','action',null,'contracts.oil_change.delete','Delete contract oil changes',true,'sales',44),
    ('contracts.view','contracts','view','action',null,'contracts.view','View contracts',false,'sales',45),
    ('contracts.field.snapshot_device_cost','contracts','view','field','snapshot_device_monthly_cost','contracts.field.snapshot_device_cost','View device cost snapshot',true,'sales',46),
    ('contracts.field.snapshot_oil_cost','contracts','view','field','snapshot_oil_monthly_cost','contracts.field.snapshot_oil_cost','View oil cost snapshot',true,'sales',47),
    ('contracts.field.snapshot_profit','contracts','view','field','snapshot_monthly_profit','contracts.field.snapshot_profit','View expected profit',true,'sales',48),
    ('customers.create','customers','create','action',null,'customers.create','Create customers',false,'sales',50),
    ('customers.delete','customers','delete','action',null,'customers.delete','Delete customers',false,'sales',51),
    ('customers.edit','customers','edit','action',null,'customers.edit','Edit customers',false,'sales',52),
    ('customers.view','customers','view','action',null,'customers.view','View customers',false,'sales',53),
    ('customers.view_ledger','customers','view_ledger','action',null,'customers.view_ledger','View customer ledger',true,'sales',54),
    ('dashboard.view','dashboard','view','action',null,'dashboard.view','View dashboard',false,'core',55),
    ('hr.advances.create','hr.advances','create','action',null,'hr.advances.create','Create advances',true,'hr',60),
    ('hr.advances.delete','hr.advances','delete','action',null,'hr.advances.delete','Delete advances',true,'hr',61),
    ('hr.advances.edit','hr.advances','edit','action',null,'hr.advances.edit','Edit advances',true,'hr',62),
    ('hr.advances.view','hr.advances','view','action',null,'hr.advances.view','View advances',true,'hr',63),
    ('hr.commissions.create','hr.commissions','create','action',null,'hr.commissions.create','Create commissions',true,'hr',64),
    ('hr.commissions.delete','hr.commissions','delete','action',null,'hr.commissions.delete','Delete commissions',true,'hr',65),
    ('hr.commissions.edit','hr.commissions','edit','action',null,'hr.commissions.edit','Edit commissions',true,'hr',66),
    ('hr.commissions.view','hr.commissions','view','action',null,'hr.commissions.view','View commissions',true,'hr',67),
    ('hr.employees.create','hr.employees','create','action',null,'hr.employees.create','Create employees',false,'hr',68),
    ('hr.employees.delete','hr.employees','delete','action',null,'hr.employees.delete','Delete employees',true,'hr',69),
    ('hr.employees.edit','hr.employees','edit','action',null,'hr.employees.edit','Edit employees',false,'hr',70),
    ('hr.employees.view','hr.employees','view','action',null,'hr.employees.view','View employees',false,'hr',71),
    ('hr.salaries.create','hr.salaries','create','action',null,'hr.salaries.create','Create salaries',true,'hr',72),
    ('hr.salaries.delete','hr.salaries','delete','action',null,'hr.salaries.delete','Delete salaries',true,'hr',73),
    ('hr.salaries.edit','hr.salaries','edit','action',null,'hr.salaries.edit','Edit salaries',true,'hr',74),
    ('hr.salaries.view','hr.salaries','view','action',null,'hr.salaries.view','View salaries',true,'hr',75),
    ('inventory.view','inventory','view','action',null,'inventory.view','View inventory balances',false,'inventory',80),
    ('inventory_movements.create','inventory_movements','create','action',null,'inventory_movements.create','Create inventory movements',true,'inventory',81),
    ('inventory_movements.delete','inventory_movements','delete','action',null,'inventory_movements.delete','Delete inventory movements',true,'inventory',82),
    ('inventory_movements.view','inventory_movements','view','action',null,'inventory_movements.view','View inventory movements',false,'inventory',83),
    ('invoices.cancel','invoices','cancel','action',null,'invoices.cancel','Cancel invoices',true,'finance',90),
    ('invoices.create','invoices','create','action',null,'invoices.create','Create invoices',false,'finance',91),
    ('invoices.edit','invoices','edit','action',null,'invoices.edit','Edit invoices',false,'finance',92),
    ('invoices.view','invoices','view','action',null,'invoices.view','View invoices',false,'finance',93),
    ('journal.view','journal','view','action',null,'journal.view','View journal',true,'accounting',100),
    ('maintenance.create','maintenance','create','action',null,'maintenance.create','Create maintenance records',false,'operations',110),
    ('maintenance.delete','maintenance','delete','action',null,'maintenance.delete','Delete maintenance records',true,'operations',111),
    ('maintenance.edit','maintenance','edit','action',null,'maintenance.edit','Edit maintenance records',false,'operations',112),
    ('maintenance.view','maintenance','view','action',null,'maintenance.view','View maintenance records',false,'operations',113),
    ('notifications.create','notifications','create','action',null,'notifications.create','Create notifications',false,'communications',120),
    ('notifications.delete','notifications','delete','action',null,'notifications.delete','Delete notifications',false,'communications',121),
    ('notifications.view','notifications','view','action',null,'notifications.view','View notifications',false,'communications',122),
    ('product_groups.create','product_groups','create','action',null,'product_groups.create','Create product groups',false,'inventory',130),
    ('product_groups.delete','product_groups','delete','action',null,'product_groups.delete','Delete product groups',false,'inventory',131),
    ('product_groups.edit','product_groups','edit','action',null,'product_groups.edit','Edit product groups',false,'inventory',132),
    ('product_groups.view','product_groups','view','action',null,'product_groups.view','View product groups',false,'inventory',133),
    ('product_units.create','product_units','create','action',null,'product_units.create','Create product units',false,'inventory',140),
    ('product_units.delete','product_units','delete','action',null,'product_units.delete','Delete product units',true,'inventory',141),
    ('product_units.edit','product_units','edit','action',null,'product_units.edit','Edit product units',false,'inventory',142),
    ('product_units.view','product_units','view','action',null,'product_units.view','View product units',false,'inventory',143),
    ('products.create','products','create','action',null,'products.create','Create products',false,'inventory',150),
    ('products.delete','products','delete','action',null,'products.delete','Delete products',true,'inventory',151),
    ('products.edit','products','edit','action',null,'products.edit','Edit products',false,'inventory',152),
    ('products.view','products','view','action',null,'products.view','View products',false,'inventory',153),
    ('products.field.avg_cost','products','view','field','avg_cost','products.field.avg_cost','View average cost',true,'inventory',154),
    ('products.field.last_purchase_cost','products','view','field','last_purchase_cost','products.field.last_purchase_cost','View last purchase cost',true,'inventory',155),
    ('products.field.min_sale_price','products','view','field','min_sale_price','products.field.min_sale_price','View min sale price',true,'inventory',156),
    ('products.field.min_rental_price','products','view','field','min_rental_price','products.field.min_rental_price','View min rental price',true,'inventory',157),
    ('quotations.create','quotations','create','action',null,'quotations.create','Create quotations',false,'sales',160),
    ('quotations.delete','quotations','delete','action',null,'quotations.delete','Delete quotations',false,'sales',161),
    ('quotations.edit','quotations','edit','action',null,'quotations.edit','Edit quotations',false,'sales',162),
    ('quotations.view','quotations','view','action',null,'quotations.view','View quotations',false,'sales',163),
    ('settings.company.delete','settings.company','delete','action',null,'settings.company.delete','Delete company settings',true,'settings',170),
    ('settings.company.edit','settings.company','edit','action',null,'settings.company.edit','Edit company settings',true,'settings',171),
    ('settings.company.view','settings.company','view','action',null,'settings.company.view','View company settings',false,'settings',172),
    ('settings.users.deactivate','settings.users','deactivate','action',null,'settings.users.deactivate','Deactivate users',true,'settings',173),
    ('settings.users.edit','settings.users','edit','action',null,'settings.users.edit','Edit users',true,'settings',174),
    ('settings.users.invite','settings.users','invite','action',null,'settings.users.invite','Invite users',true,'settings',175),
    ('settings.users.view','settings.users','view','action',null,'settings.users.view','View users',false,'settings',176),
    ('suppliers.create','suppliers','create','action',null,'suppliers.create','Create suppliers',false,'purchasing',180),
    ('suppliers.delete','suppliers','delete','action',null,'suppliers.delete','Delete suppliers',true,'purchasing',181),
    ('suppliers.edit','suppliers','edit','action',null,'suppliers.edit','Edit suppliers',false,'purchasing',182),
    ('suppliers.view','suppliers','view','action',null,'suppliers.view','View suppliers',false,'purchasing',183),
    ('visits.create','visits','create','action',null,'visits.create','Create visits',false,'field_ops',190),
    ('visits.delete','visits','delete','action',null,'visits.delete','Delete visits',true,'field_ops',191),
    ('visits.edit','visits','edit','action',null,'visits.edit','Edit visits',false,'field_ops',192),
    ('visits.edit_assigned','visits','edit_assigned','action',null,'visits.edit_assigned','Edit assigned visits',false,'field_ops',193),
    ('visits.view','visits','view','action',null,'visits.view','View visits',false,'field_ops',194),
    ('visits.view_assigned','visits','view_assigned','action',null,'visits.view_assigned','View assigned visits',false,'field_ops',195),
    ('vouchers.cancel','vouchers','cancel','action',null,'vouchers.cancel','Cancel vouchers',true,'finance',200),
    ('vouchers.create_payment','vouchers','create_payment','action',null,'vouchers.create_payment','Create payment vouchers',false,'finance',201),
    ('vouchers.create_receipt','vouchers','create_receipt','action',null,'vouchers.create_receipt','Create receipt vouchers',false,'finance',202),
    ('vouchers.edit','vouchers','edit','action',null,'vouchers.edit','Edit vouchers',false,'finance',203),
    ('vouchers.view','vouchers','view','action',null,'vouchers.view','View vouchers',false,'finance',204),
    ('warehouses.create','warehouses','create','action',null,'warehouses.create','Create warehouses',false,'inventory',210),
    ('warehouses.delete','warehouses','delete','action',null,'warehouses.delete','Delete warehouses',true,'inventory',211),
    ('warehouses.edit','warehouses','edit','action',null,'warehouses.edit','Edit warehouses',false,'inventory',212),
    ('warehouses.view','warehouses','view','action',null,'warehouses.view','View warehouses',false,'inventory',213)
  on conflict (id) do update set
    module = excluded.module,
    action = excluded.action,
    scope = excluded.scope,
    field_name = excluded.field_name,
    label_ar = excluded.label_ar,
    label_en = excluded.label_en,
    is_sensitive = excluded.is_sensitive,
    category = excluded.category,
    sort_order = excluded.sort_order;

  insert into currencies (
    id, tenant_id, iso_code, major_name_ar, major_name_en, major_symbol_ar, major_symbol_en,
    minor_name_ar, minor_name_en, minor_symbol_ar, minor_symbol_en, decimal_places,
    minor_units_per_major, symbol_position, is_default, sort_order
  )
  values
    (v_kwd_a, v_tenant_a, 'KWD', 'دينار', 'Kuwaiti dinar', 'د.ك', 'KWD', 'فلس', 'fils', 'فلس', 'fils', 3, 1000, 'after', true, 1),
    (v_kwd_b, v_tenant_b, 'KWD', 'دينار', 'Kuwaiti dinar', 'د.ك', 'KWD', 'فلس', 'fils', 'فلس', 'fils', 3, 1000, 'after', true, 1)
  on conflict (tenant_id, iso_code) do nothing;

  update tenants set default_currency_id = v_kwd_a where id = v_tenant_a;
  update tenants set default_currency_id = v_kwd_b where id = v_tenant_b;

  insert into tenant_settings (
    tenant_id, company_name_ar, company_name_en, receipt_footer_ar, receipt_footer_en
  )
  values
    (v_tenant_a, 'حياة سكرت', 'Hayat Secret', 'شكراً لتعاملكم معنا', 'Thank you for your business'),
    (v_tenant_b, 'شركة اختبار ب', 'Tenant B Test', 'شكراً', 'Thank you')
  on conflict (tenant_id) do nothing;

  insert into chart_of_accounts (id, tenant_id, code, name_ar, name_en, type, is_system)
  values
    (v_cash, v_tenant_a, '1101', 'الصندوق', 'Cash on hand', 'asset', true),
    (v_bank, v_tenant_a, '1102', 'البنك الرئيسي', 'Main bank', 'asset', true),
    (v_ar, v_tenant_a, '1201', 'ذمم العملاء', 'Accounts receivable', 'asset', true),
    (v_ap, v_tenant_a, '2101', 'ذمم الموردين', 'Accounts payable', 'liability', true),
    (v_inventory, v_tenant_a, '1301', 'المخزون', 'Inventory', 'asset', true),
    (v_revenue, v_tenant_a, '4101', 'إيرادات المبيعات', 'Sales revenue', 'income', true),
    (v_cogs, v_tenant_a, '5101', 'تكلفة البضاعة', 'Cost of goods sold', 'expense', true),
    (v_expense, v_tenant_a, '6101', 'مصروفات عامة', 'General expenses', 'expense', true),
    (v_b_cash, v_tenant_b, '1101', 'الصندوق', 'Cash on hand', 'asset', true)
  on conflict (tenant_id, code) do nothing;

  insert into employees (id, tenant_id, user_id, code, name_ar, name_en, job_type, phone, email, base_salary, hire_date)
  values
    (v_owner_employee, v_tenant_a, v_owner_user, 'EMP-001', 'محمد المدير', 'Manager Mohammad', 'office', '+96550000001', 'owner@hayat-secret.test', 0, current_date),
    (v_field_employee, v_tenant_a, v_field_user, 'EMP-002', 'أحمد المندوب', 'Field Ahmad', 'field_refill', '+96550000002', 'field@hayat-secret.test', 350.000, current_date),
    (v_warehouse_employee, v_tenant_a, null, 'EMP-003', 'سارة المخزن', 'Warehouse Sara', 'warehouse_ops', '+96550000003', 'warehouse@hayat-secret.test', 400.000, current_date)
  on conflict (tenant_id, code) do nothing;

  insert into warehouses (id, tenant_id, name_ar, name_en, type, agent_id, location_address)
  values
    (v_main_warehouse, v_tenant_a, 'المخزن الرئيسي', 'Main warehouse', 'main', null, 'Kuwait City'),
    (v_van_warehouse, v_tenant_a, 'سيارة أحمد', 'Ahmad van', 'van', v_field_employee, 'Field route')
  on conflict (id) do nothing;

  insert into product_groups (id, tenant_id, name_ar, name_en, sort_order, created_by)
  values
    (v_devices_group, v_tenant_a, 'الأجهزة', 'Devices', 1, v_owner_user),
    (v_oils_group, v_tenant_a, 'الزيوت', 'Oils', 2, v_owner_user),
    (v_perfumes_group, v_tenant_a, 'العطور', 'Perfumes', 3, v_owner_user),
    (v_b_group, v_tenant_b, 'Tenant B Products', 'Tenant B Products', 1, v_tenant_b_user)
  on conflict (id) do nothing;

  insert into products (
    id, tenant_id, sku, barcode, name_ar, name_en, group_id, product_type,
    unit_primary, unit_secondary, conversion_factor, sale_price, min_sale_price,
    rental_price_monthly, avg_cost, last_purchase_cost, expected_lifespan_months,
    default_oil_ml_per_month, is_serialized, trackable_for_maintenance, reorder_point,
    created_by
  )
  values
    (v_product_a, v_tenant_a, 'HS-DEV-001', '628000000001', 'جهاز تعطير HS', 'HS Diffuser', v_devices_group, 'asset_rental', 'piece', null, 1, 0, null, 12.500, 45.000, 45.000, 24, null, true, true, 2, v_owner_user),
    (v_product_b, v_tenant_b, 'TB-DEV-001', '628000000002', 'منتج شركة ب', 'Tenant B Diffuser', v_b_group, 'asset_rental', 'piece', null, 1, 0, null, 10.000, 30.000, 30.000, 24, null, true, true, 1, v_tenant_b_user)
  on conflict (tenant_id, sku) do nothing;

  insert into user_permissions (tenant_id, tenant_user_id, permission_id, granted_by)
  values
    (v_tenant_a, v_products_tu, 'products.view', v_owner_user),
    (v_tenant_a, v_products_tu, 'products.create', v_owner_user),
    (v_tenant_a, v_products_tu, 'product_groups.view', v_owner_user),
    (v_tenant_a, v_field_tu, 'visits.view_assigned', v_owner_user),
    (v_tenant_a, v_field_tu, 'visits.edit_assigned', v_owner_user)
  on conflict (tenant_user_id, permission_id) do nothing;
end $$;
