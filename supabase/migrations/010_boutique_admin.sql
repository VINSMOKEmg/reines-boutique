-- Une administratrice peut aussi avoir sa boutique (bouton « Ouvrir ma boutique » de l'administration).
-- Les règles existantes suffisent ensuite : produits, photos et commandes passent par seller_id = son id.
-- À coller dans Supabase > SQL Editor > Run, après 009_notifications_push.sql. Peut être relancé sans risque.
create or replace function public.admin_open_shop() returns void
language plpgsql security definer set search_path = public, private as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  -- Boutique active d'emblée, avec le numéro du profil comme WhatsApp ; rien ne change si elle existe déjà.
  insert into seller_profiles(id, shop_name, full_name, whatsapp, status)
    select p.id, 'Ma boutique', p.full_name, p.phone, 'active' from profiles p where p.id = auth.uid()
  on conflict (id) do nothing;
end $$;
revoke execute on function public.admin_open_shop() from public, anon;
grant execute on function public.admin_open_shop() to authenticated;
