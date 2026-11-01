-- Avertissements de sécurité Supabase : fonctions appelables par l'API sans raison. Aucun changement de comportement.
-- À coller dans Supabase > SQL Editor > Run, après 005_optimisations.sql. Peut être relancé sans risque.

-- 1. rls_auto_enable sert seulement au déclencheur ensure_rls (activation automatique de RLS) :
--    personne n'a à l'appeler par /rest/v1/rpc/.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;

-- 2. is_admin passe dans un schéma « private », non exposé par l'API.
--    Les règles d'accès la retrouvent seules (elles pointent la fonction, pas son nom) ;
--    les fonctions qui l'appellent par son nom cherchent aussi dans « private ».
create schema if not exists private;
grant usage on schema private to anon, authenticated;

do $$ begin
  if exists(select 1 from pg_proc where proname='is_admin' and pronamespace='public'::regnamespace) then
    alter function public.is_admin() set schema private;
  end if;
end $$;
revoke execute on function private.is_admin() from public;
grant execute on function private.is_admin() to anon, authenticated;

alter function public.guard_profiles()                    set search_path = public, private;
alter function public.guard_sellers()                     set search_path = public, private;
alter function public.guard_products()                    set search_path = public, private;
alter function public.admin_set_role(text, user_role)     set search_path = public, private;
alter function public.admin_activate_seller(uuid)         set search_path = public, private;
