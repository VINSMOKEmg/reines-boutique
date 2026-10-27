-- Numéro WhatsApp à l'inscription (clientes et vendeuses).
-- À coller dans Supabase > SQL Editor > Run, après 001_proteger_email.sql. Peut être relancé sans risque.

-- 1. Colonne téléphone sur le profil (format international sans +, ex. 221771234567).
alter table profiles add column if not exists phone text;
alter table profiles drop constraint if exists profiles_phone_check;
alter table profiles add constraint profiles_phone_check check (phone is null or phone ~ '^[0-9]{8,15}$');

-- 2. Le numéro saisi à l'inscription est copié dans le profil (nettoyé ; ignoré s'il est invalide).
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare ph text:=regexp_replace(coalesce(new.raw_user_meta_data->>'phone',''),'\D','','g');
begin insert into profiles(id,email,full_name,role,phone) values(new.id,new.email,left(coalesce(new.raw_user_meta_data->>'full_name',''),80),'client',
  case when ph ~ '^[0-9]{8,15}$' then ph end); return new; end $$;

-- 3. Quand un compte devient vendeuse, ce numéro devient le WhatsApp de sa boutique (sans écraser un numéro existant).
create or replace function on_role_change() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into seller_profiles(id,shop_name,full_name,whatsapp) values(new.id,'Ma boutique',new.full_name,new.phone)
  on conflict (id) do update set whatsapp=coalesce(seller_profiles.whatsapp,excluded.whatsapp); return new; end $$;

-- 4. Le nom et le téléphone restent modifiables par leur propriétaire ; l'e-mail non.
revoke update on profiles from authenticated, anon;
grant update(full_name,phone) on profiles to authenticated;

-- 5. Comptes déjà créés : on récupère le numéro depuis l'inscription ou depuis le WhatsApp de la boutique.
update profiles p set phone=x.ph from (
  select u.id, regexp_replace(coalesce(u.raw_user_meta_data->>'phone',''),'\D','','g') ph from auth.users u) x
  where x.id=p.id and p.phone is null and x.ph ~ '^[0-9]{8,15}$';
update profiles p set phone=s.whatsapp from seller_profiles s where s.id=p.id and p.phone is null and s.whatsapp is not null;
update seller_profiles s set whatsapp=p.phone from profiles p where p.id=s.id and s.whatsapp is null and p.phone is not null;

-- 6. Contrôle : boutiques encore sans WhatsApp (à compléter par la vendeuse dans « Ma boutique »).
select s.shop_name, u.email from seller_profiles s join auth.users u on u.id=s.id where s.whatsapp is null;
