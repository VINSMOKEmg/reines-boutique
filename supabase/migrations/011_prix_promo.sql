-- Prix promotionnel : prix normal barré, prix promo affiché et payé. Facultatif, toujours inférieur au prix normal.
-- À coller dans Supabase > SQL Editor > Run, après 010_boutique_admin.sql. Peut être relancé sans risque.
alter table public.products add column if not exists promo_price_fcfa integer;
alter table public.products drop constraint if exists products_promo_check;
alter table public.products add constraint products_promo_check check (promo_price_fcfa is null or (promo_price_fcfa > 0 and promo_price_fcfa < price_fcfa));

create or replace function place_order(items jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); oid uuid; base text; n int:=0; sid uuid; soid uuid; res jsonb:='[]'::jsonb;
        it jsonb; p record; q int; o text; need int; lines jsonb; tot int; shop record;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if jsonb_typeof(items)<>'array' or jsonb_array_length(items) not between 1 and 50 then raise exception 'Panier invalide'; end if;
  if (select count(*) from orders where client_id=uid and created_at>now()-interval '1 hour')>=5 then
    raise exception 'Vous avez passé beaucoup de commandes en peu de temps : réessayez dans une heure ou écrivez directement à la vendeuse.';
  end if;
  for it in select value from jsonb_array_elements(items) loop
    -- « for update » : deux commandes simultanées ne peuvent pas vendre le même dernier article.
    select pr.* into p from products pr join seller_profiles s on s.id=pr.seller_id
      where pr.id=(it->>'product_id')::uuid and pr.is_approved and pr.is_available and s.status='active' for update of pr;
    if not found then raise exception 'Un produit du panier n''est plus disponible'; end if;
    o:=nullif(trim(coalesce(it->>'option','')),'');
    if coalesce(cardinality(p.options),0)>0 and (o is null or not (o = any(p.options))) then
      raise exception 'Choisissez « % » pour « % »', coalesce(p.option_label,'une option'), p.name;
    end if;
    if p.stock is not null then
      select coalesce(sum(least(greatest(coalesce((e->>'qty')::int,1),1),99)),0) into need
        from jsonb_array_elements(items) e where (e->>'product_id')::uuid=p.id;
      if need>p.stock then
        raise exception 'Stock insuffisant pour « % » : % disponible(s)', p.name, p.stock;
      end if;
    end if;
  end loop;
  base:='CMD-'||upper(substr(md5(gen_random_uuid()::text),1,6));
  insert into orders(ref,client_id) values(base,uid) returning id into oid;
  for sid in select distinct pr.seller_id from jsonb_array_elements(items) e join products pr on pr.id=(e->>'product_id')::uuid loop
    n:=n+1; lines:='[]'::jsonb;
    -- Prix payé = prix promo s'il existe, sinon prix normal (« regular » : prix barré, pour le message WhatsApp).
    -- Total calculé avant l'insertion : l'alerte en direct de la vendeuse reçoit le bon montant.
    select coalesce(sum(least(greatest(coalesce((e->>'qty')::int,1),1),99)*coalesce(pr.promo_price_fcfa,pr.price_fcfa)),0) into tot
      from jsonb_array_elements(items) e join products pr on pr.id=(e->>'product_id')::uuid where pr.seller_id=sid;
    insert into seller_orders(order_id,seller_id,ref,total) values(oid,sid,base||'-'||n,tot) returning id into soid;
    tot:=0;
    for it in select value from jsonb_array_elements(items) loop
      select * into p from products where id=(it->>'product_id')::uuid and seller_id=sid;
      if not found then continue; end if;
      q:=least(greatest(coalesce((it->>'qty')::int,1),1),99);
      o:=case when coalesce(cardinality(p.options),0)>0 then nullif(trim(coalesce(it->>'option','')),'') end;
      insert into order_items(seller_order_id,product_id,name,unit_price,qty,option) values(soid,p.id,p.name,coalesce(p.promo_price_fcfa,p.price_fcfa),q,o);
      tot:=tot+q*coalesce(p.promo_price_fcfa,p.price_fcfa);
      lines:=lines||jsonb_build_array(jsonb_build_object('name',p.name,'qty',q,'price',coalesce(p.promo_price_fcfa,p.price_fcfa),'regular',case when p.promo_price_fcfa is not null then p.price_fcfa end,'option',o,'option_label',p.option_label));
    end loop;
    select shop_name, whatsapp into shop from seller_profiles where id=sid;
    res:=res||jsonb_build_array(jsonb_build_object('ref',base||'-'||n,'shop_name',shop.shop_name,'whatsapp',shop.whatsapp,'total',tot,'items',lines));
  end loop;
  -- Décompte du stock (quantités cumulées par produit).
  update products pr set stock=pr.stock-x.q, is_available=(pr.stock-x.q)>0
    from (select (e->>'product_id')::uuid id, sum(least(greatest(coalesce((e->>'qty')::int,1),1),99)) q
          from jsonb_array_elements(items) e group by 1) x
    where pr.id=x.id and pr.stock is not null;
  return res;
end $$;
revoke execute on function place_order(jsonb) from public, anon; grant execute on function place_order(jsonb) to authenticated;
