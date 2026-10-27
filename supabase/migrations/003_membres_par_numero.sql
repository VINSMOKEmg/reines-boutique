-- Membres du groupe identifiées par leur numéro WhatsApp, validation par l'admin, connexion des vendeuses par numéro.
-- À coller dans Supabase > SQL Editor > Run, après 002_telephone.sql. Peut être relancé sans risque.

-- 1. La liste des membres accepte un numéro (prioritaire) ; l'e-mail devient facultatif.
alter table member_whitelist add column if not exists phone text;
alter table member_whitelist alter column email drop not null;
alter table member_whitelist drop constraint if exists member_whitelist_phone_check;
alter table member_whitelist add constraint member_whitelist_phone_check check (phone is null or phone ~ '^[0-9]{8,15}$');
alter table member_whitelist drop constraint if exists member_whitelist_contact_check;
alter table member_whitelist add constraint member_whitelist_contact_check check (email is not null or phone is not null);
create unique index if not exists member_whitelist_phone_key on member_whitelist(phone) where phone is not null;
create index if not exists profiles_phone_idx on profiles(phone);

-- 1 bis. Le numéro du profil n'est plus modifiable depuis le site (il sert à reconnaître les membres et à connecter les vendeuses).
revoke update on profiles from authenticated, anon;
grant update(full_name) on profiles to authenticated;

-- 2. À la connexion : numéro (ou e-mail) dans la liste = en attente de validation par l'admin. Plus d'activation automatique.
create or replace function claim_membership() returns text language plpgsql security definer set search_path=public,auth as $$
declare u record;
begin
  select id,email,email_confirmed_at into u from auth.users where id=auth.uid();
  if u.id is null then return 'anon'; end if;
  if exists(select 1 from profiles where id=u.id and role in ('seller','admin')) then return 'ok'; end if;
  if exists(select 1 from member_whitelist w join profiles p on p.id=u.id where w.phone=p.phone or w.email=lower(u.email)) then return 'pending'; end if;
  return 'not_member';
end $$;
revoke execute on function claim_membership() from public, anon; grant execute on function claim_membership() to authenticated;

-- 3. Validation par l'admin : le compte devient vendeuse et sa boutique est créée avec son numéro comme WhatsApp.
create or replace function admin_activate_seller(target uuid) returns void language plpgsql security definer set search_path=public as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  update profiles set role='seller' where id=target and role='client';
  if not found then raise exception 'Compte introuvable ou déjà vendeuse'; end if;
  update seller_profiles set status='active' where id=target;
end $$;
revoke execute on function admin_activate_seller(uuid) from public, anon; grant execute on function admin_activate_seller(uuid) to authenticated;

-- 4. Connexion par numéro : e-mail du compte vendeuse lié à ce numéro (vendeuses validées uniquement).
create or replace function seller_login_email(p text) returns text language sql stable security definer set search_path=public,auth as $$
  select u.email from profiles pr join auth.users u on u.id=pr.id
  where pr.phone=regexp_replace(coalesce(p,''),'\D','','g') and pr.role='seller' order by pr.created_at limit 1 $$;
revoke execute on function seller_login_email(text) from public; grant execute on function seller_login_email(text) to anon, authenticated;

-- 5. Contrôle : membres de la liste et comptes qui portent leur numéro.
select w.full_name, w.phone, w.email, p.role, u.email as compte
from member_whitelist w left join profiles p on p.phone=w.phone left join auth.users u on u.id=p.id order by w.created_at;
