-- 016 : photos plus légères pour réduire la bande passante (quota « Cached Egress » de Supabase dépassé en novembre 2026).
-- - product_images.thumb_path : petite version (≈ 480 px) affichée dans le catalogue, le panier et les listes ;
--   la photo complète (path) n'est chargée que sur la fiche produit. Vide pour les anciennes photos tant que
--   l'administration n'a pas lancé « Alléger les photos » : le site affiche alors la photo complète.
-- - admin_media_todo() : photos à alléger (sans vignette, ou logo/couverture sans cache long), pour ce bouton.
-- - admin_orphan_media() : une vignette utilisée n'est pas une photo inutilisée.
-- Peut être relancé sans risque.
alter table public.product_images add column if not exists thumb_path text;

create or replace function public.admin_orphan_media() returns table(name text, size bigint) language plpgsql stable security definer set search_path=public,private,storage as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query
    select o.name, coalesce((o.metadata->>'size')::bigint,0)
    from storage.objects o
    where o.bucket_id='shop-media' and o.created_at < now()-interval '1 day'
      and not exists(select 1 from product_images i where i.path=o.name or i.thumb_path=o.name)
      and not exists(select 1 from seller_profiles s where s.logo_path=o.name or s.cover_path=o.name)
    order by o.created_at;
end $$;
revoke execute on function public.admin_orphan_media() from public, anon; grant execute on function public.admin_orphan_media() to authenticated;

-- kind : 'img' (id = product_images.id), 'logo' ou 'cover' (id = boutique). Les plus lourdes d'abord.
create or replace function public.admin_media_todo() returns table(kind text, id uuid, path text, size bigint) language plpgsql stable security definer set search_path=public,private,storage as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query
    select t.kind, t.id, t.path, coalesce((o.metadata->>'size')::bigint,0)
    from (
      select 'img'::text kind, i.id, i.path from product_images i where i.thumb_path is null
      union all select 'logo', s.id, s.logo_path from seller_profiles s where s.logo_path is not null
      union all select 'cover', s.id, s.cover_path from seller_profiles s where s.cover_path is not null
    ) t
    join storage.objects o on o.bucket_id='shop-media' and o.name=t.path
    where t.kind='img' or coalesce(o.metadata->>'cacheControl','') <> 'max-age=31536000'
    order by 4 desc;
end $$;
revoke execute on function public.admin_media_todo() from public, anon; grant execute on function public.admin_media_todo() to authenticated;
