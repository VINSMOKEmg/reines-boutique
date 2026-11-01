-- Optimisations et nettoyage signalés par les conseillers Supabase. Aucun changement de comportement.
-- À coller dans Supabase > SQL Editor > Run, après 004_stock_options_alertes.sql. Peut être relancé sans risque.

-- 1. Fonctions de trigger : elles n'ont pas à être appelables par l'API (/rest/v1/rpc/...).
--    (is_admin reste exécutable : les règles d'accès l'appellent avec les droits du visiteur.)
revoke execute on function public.handle_new_user()    from public, anon, authenticated;
revoke execute on function public.on_role_change()     from public, anon, authenticated;
revoke execute on function public.restock_on_cancel()  from public, anon, authenticated;
revoke execute on function public.sync_profile_email() from public, anon, authenticated;

-- 2. Fonctions de protection : chemin de recherche fixé.
alter function public.guard_profiles() set search_path = public;
alter function public.guard_sellers()  set search_path = public;
alter function public.guard_products() set search_path = public;

-- 3. Index manquant sur une clé étrangère.
create index if not exists order_items_product_id_idx on public.order_items(product_id);

-- 4. Règles d'accès réécrites à l'identique, avec (select auth.uid()) et (select is_admin()) :
--    calculés une fois par requête au lieu d'une fois par ligne. Les règles « ALL » des catégories
--    et des images sont découpées (insert / update / delete) pour ne plus doubler la règle de lecture.
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select using (id = (select auth.uid()) or (select is_admin()));
drop policy if exists profiles_update on public.profiles;
create policy profiles_update on public.profiles for update using (id = (select auth.uid()) or (select is_admin()));

drop policy if exists sellers_read on public.seller_profiles;
create policy sellers_read on public.seller_profiles for select using (status = 'active' or id = (select auth.uid()) or (select is_admin()));
drop policy if exists sellers_update on public.seller_profiles;
create policy sellers_update on public.seller_profiles for update using (id = (select auth.uid()) or (select is_admin()));

drop policy if exists cat_admin on public.categories;
drop policy if exists cat_admin_insert on public.categories;
drop policy if exists cat_admin_update on public.categories;
drop policy if exists cat_admin_delete on public.categories;
create policy cat_admin_insert on public.categories for insert with check ((select is_admin()));
create policy cat_admin_update on public.categories for update using ((select is_admin())) with check ((select is_admin()));
create policy cat_admin_delete on public.categories for delete using ((select is_admin()));

drop policy if exists prod_read on public.products;
create policy prod_read on public.products for select using (
  (is_approved and exists(select 1 from public.seller_profiles s where s.id = seller_id and s.status = 'active'))
  or seller_id = (select auth.uid()) or (select is_admin()));
drop policy if exists prod_insert on public.products;
create policy prod_insert on public.products for insert with check (
  seller_id = (select auth.uid()) and exists(select 1 from public.seller_profiles s where s.id = (select auth.uid()) and s.status = 'active'));
drop policy if exists prod_update on public.products;
create policy prod_update on public.products for update using (seller_id = (select auth.uid()) or (select is_admin()));
drop policy if exists prod_delete on public.products;
create policy prod_delete on public.products for delete using (seller_id = (select auth.uid()) or (select is_admin()));

drop policy if exists img_write on public.product_images;
drop policy if exists img_insert on public.product_images;
drop policy if exists img_update on public.product_images;
drop policy if exists img_delete on public.product_images;
create policy img_insert on public.product_images for insert with check (
  exists(select 1 from public.products p where p.id = product_id and (p.seller_id = (select auth.uid()) or (select is_admin()))));
create policy img_update on public.product_images for update
  using (exists(select 1 from public.products p where p.id = product_id and (p.seller_id = (select auth.uid()) or (select is_admin()))))
  with check (exists(select 1 from public.products p where p.id = product_id and (p.seller_id = (select auth.uid()) or (select is_admin()))));
create policy img_delete on public.product_images for delete using (
  exists(select 1 from public.products p where p.id = product_id and (p.seller_id = (select auth.uid()) or (select is_admin()))));

drop policy if exists orders_read on public.orders;
create policy orders_read on public.orders for select using (client_id = (select auth.uid()) or (select is_admin()));

drop policy if exists so_read on public.seller_orders;
create policy so_read on public.seller_orders for select using (
  seller_id = (select auth.uid()) or (select is_admin())
  or exists(select 1 from public.orders o where o.id = order_id and o.client_id = (select auth.uid())));
drop policy if exists so_update on public.seller_orders;
create policy so_update on public.seller_orders for update using (seller_id = (select auth.uid()) or (select is_admin()));
