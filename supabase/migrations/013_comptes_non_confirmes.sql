-- 013 : une boutique ne s'active que sur un compte dont l'e-mail est confirmé.
-- Cas réel du 2026-11-05 : boutique activée sur un compte jamais confirmé, la vendeuse en recrée un autre
-- et ne peut plus se connecter (« Email not confirmed » avec son numéro, compte cliente avec son nouvel e-mail).

-- Activation refusée tant que le lien de confirmation n'a pas été cliqué.
create or replace function public.admin_activate_seller(target uuid) returns void language plpgsql security definer set search_path=public,private as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  if exists(select 1 from auth.users where id=target and email_confirmed_at is null) then
    raise exception 'Ce compte n''a pas encore confirmé son e-mail : demandez-lui de cliquer sur le lien reçu (pensez aux spams), puis réessayez.';
  end if;
  update profiles set role='seller' where id=target and role='client';
  if not found then raise exception 'Compte introuvable ou déjà vendeuse'; end if;
  update seller_profiles set status='active' where id=target;
end $$;

-- Connexion par numéro : le compte confirmé passe avant un éventuel ancien compte non confirmé.
create or replace function public.seller_login_email(p text) returns text language sql stable security definer set search_path=public,auth as $$
  select u.email from profiles pr join auth.users u on u.id=pr.id
  where pr.phone=regexp_replace(coalesce(p,''),'\D','','g') and pr.role='seller'
  order by u.email_confirmed_at is null, pr.created_at limit 1 $$;

-- Pour l'administration : comptes (non anonymes) dont l'e-mail n'est pas encore confirmé.
create or replace function public.admin_unconfirmed() returns setof uuid language plpgsql stable security definer set search_path=public,private as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query select id from auth.users where email_confirmed_at is null and not coalesce(is_anonymous,false);
end $$;
revoke execute on function public.admin_unconfirmed() from public, anon;
grant execute on function public.admin_unconfirmed() to authenticated;
