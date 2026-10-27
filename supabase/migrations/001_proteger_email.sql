-- Correctif : empêcher l'usurpation de profiles.email.
-- À coller dans Supabase > SQL Editor > Run, sur une base créée avec l'ancien schema.sql. Peut être relancé sans risque.

-- 1. Depuis le site, seul le nom du profil est modifiable.
revoke update on profiles from authenticated, anon;
grant update(full_name) on profiles to authenticated;

-- 2. Promotion par l'e-mail réel (auth.users), jamais par la copie de profiles.
create or replace function admin_set_role(target_email text, new_role user_role) returns void
language plpgsql security definer set search_path=public as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  update profiles p set role=new_role from auth.users u where u.id=p.id and lower(u.email)=lower(target_email);
  if not found then raise exception 'Aucun compte avec cet e-mail'; end if;
end $$;
revoke execute on function admin_set_role(text,user_role) from public, anon; grant execute on function admin_set_role(text,user_role) to authenticated;

-- 3. profiles.email suit l'e-mail réel quand il change.
create or replace function sync_profile_email() returns trigger language plpgsql security definer set search_path=public as $$
begin update profiles set email=new.email where id=new.id; return new; end $$;
drop trigger if exists on_auth_user_email on auth.users;
create trigger on_auth_user_email after update of email on auth.users for each row
  when (new.email is distinct from old.email) execute function sync_profile_email();

-- 4. Remet d'aplomb les e-mails qui auraient déjà été modifiés.
update profiles p set email=u.email from auth.users u where u.id=p.id and p.email is distinct from u.email;

-- 5. Contrôle : la liste des admins et vendeuses doit correspondre à ce que vous attendez.
select p.role, u.email, p.full_name from profiles p join auth.users u on u.id=p.id where p.role in ('admin','seller') order by p.role, u.email;
