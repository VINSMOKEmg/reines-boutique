-- 014 : photos du stockage qui ne servent plus (logo ou couverture remplacés, produit supprimé, compte supprimé).
-- L'administration les liste puis les efface par l'API Storage (sb.storage.remove), seule voie de suppression des fichiers.
-- Fichiers de plus d'un jour seulement : une photo en cours d'envoi n'est pas encore rattachée à son produit.
create or replace function public.admin_orphan_media() returns table(name text, size bigint) language plpgsql stable security definer set search_path=public,private,storage as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query
    select o.name, coalesce((o.metadata->>'size')::bigint,0)
    from storage.objects o
    where o.bucket_id='shop-media' and o.created_at < now()-interval '1 day'
      and not exists(select 1 from product_images i where i.path=o.name)
      and not exists(select 1 from seller_profiles s where s.logo_path=o.name or s.cover_path=o.name)
    order by o.created_at;
end $$;
revoke execute on function public.admin_orphan_media() from public, anon;
grant execute on function public.admin_orphan_media() to authenticated;
