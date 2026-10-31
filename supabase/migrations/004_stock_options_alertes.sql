-- Stock vérifié et décompté, options de produit (taille, couleur…), limite anti-abus, alertes en direct.
-- À coller dans Supabase > SQL Editor > Run, après 003_membres_par_numero.sql. Peut être relancé sans risque.

-- 1. Stock : vide (null) = illimité. Les produits encore au stock par défaut (1) deviennent illimités,
--    car le stock n'était jusqu'ici qu'indicatif : chaque vendeuse renseigne ensuite son vrai stock.
alter table products alter column stock drop not null;
alter table products alter column stock set default null;
update products set stock = null where stock = 1;

-- 2. Option de produit : un intitulé (« Taille ») et ses choix (« S », « M », « L »).
alter table products add column if not exists option_label text;
alter table products add column if not exists options text[];
alter table products drop constraint if exists products_options_check;
alter table products add constraint products_options_check check (
  (option_label is null or char_length(option_label) <= 30) and (options is null or cardinality(options) <= 20));
alter table order_items add column if not exists option text;

-- 3. Passage de commande : produit disponible, option valide, stock suffisant, 5 commandes par heure au plus.
--    Prix, vendeuses et stock sont lus en base, jamais fournis par le navigateur. Le stock est décompté ;
--    un produit qui tombe à 0 devient indisponible.
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
    n:=n+1; lines:='[]'::jsonb; tot:=0;
    insert into seller_orders(order_id,seller_id,ref) values(oid,sid,base||'-'||n) returning id into soid;
    for it in select value from jsonb_array_elements(items) loop
      select * into p from products where id=(it->>'product_id')::uuid and seller_id=sid;
      if not found then continue; end if;
      q:=least(greatest(coalesce((it->>'qty')::int,1),1),99);
      o:=case when coalesce(cardinality(p.options),0)>0 then nullif(trim(coalesce(it->>'option','')),'') end;
      insert into order_items(seller_order_id,product_id,name,unit_price,qty,option) values(soid,p.id,p.name,p.price_fcfa,q,o);
      tot:=tot+q*p.price_fcfa;
      lines:=lines||jsonb_build_array(jsonb_build_object('name',p.name,'qty',q,'price',p.price_fcfa,'option',o,'option_label',p.option_label));
    end loop;
    update seller_orders set total=tot where id=soid;
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

-- 4. Commande annulée : le stock revient (et inversement si l'annulation est retirée).
create or replace function restock_on_cancel() returns trigger language plpgsql security definer set search_path=public as $$
begin
  if new.status='annulee' and old.status<>'annulee' then
    update products pr set stock=pr.stock+x.q, is_available=case when pr.stock=0 then true else pr.is_available end
      from (select product_id, sum(qty) q from order_items where seller_order_id=new.id group by product_id) x
      where pr.id=x.product_id and pr.stock is not null;
  elsif old.status='annulee' and new.status<>'annulee' then
    update products pr set stock=greatest(pr.stock-x.q,0), is_available=pr.is_available and (pr.stock-x.q)>0
      from (select product_id, sum(qty) q from order_items where seller_order_id=new.id group by product_id) x
      where pr.id=x.product_id and pr.stock is not null;
  end if;
  return new;
end $$;
drop trigger if exists t_restock on seller_orders;
create trigger t_restock after update of status on seller_orders for each row execute function restock_on_cancel();

-- 5. Alertes en direct : les nouvelles demandes sont diffusées à l'espace vendeuse (Realtime, filtré par RLS).
do $$ begin
  alter publication supabase_realtime add table seller_orders;
exception when duplicate_object then null; end $$;

-- 6. Contrôle : produits avec leur stock (vide = illimité) et leur option.
select name, stock, option_label, options from products order by created_at desc limit 20;
