-- Les Reines de l'Entrepreneuriat — schéma complet. À coller dans Supabase > SQL Editor > Run.
create type user_role as enum ('client','seller','admin');
create type seller_status as enum ('pending','active','suspended');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text default '', role user_role not null default 'client',
  phone text check (phone is null or phone ~ '^[0-9]{8,15}$'),  -- WhatsApp, format international sans +
  created_at timestamptz not null default now());
create table seller_profiles (
  id uuid primary key references profiles(id) on delete cascade,
  shop_name text not null check (char_length(shop_name) between 2 and 80),
  full_name text, description text check (char_length(description) <= 1000),
  logo_path text, cover_path text, location text, hours text,
  whatsapp text check (whatsapp is null or whatsapp ~ '^[0-9]{8,15}$'),
  status seller_status not null default 'active',
  created_at timestamptz not null default now());
create table categories (id uuid primary key default gen_random_uuid(), name text not null unique, icon text);
create table products (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null default auth.uid() references seller_profiles(id) on delete cascade,
  category_id uuid references categories(id) on delete set null,
  name text not null check (char_length(name) between 2 and 120),
  description text default '' check (char_length(description) <= 2000),
  price_fcfa integer not null check (price_fcfa > 0 and price_fcfa <= 100000000),
  stock integer check (stock >= 0),  -- vide = illimité ; décompté à chaque commande
  option_label text check (option_label is null or char_length(option_label) <= 30),  -- ex. « Taille »
  options text[] check (options is null or cardinality(options) <= 20),               -- ex. {S,M,L}
  is_available boolean not null default true,
  is_approved boolean not null default true,
  created_at timestamptz not null default now());
create table product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references products(id) on delete cascade,
  path text not null, position int not null default 0);
create table orders (
  id uuid primary key default gen_random_uuid(), ref text not null unique,
  client_id uuid not null references profiles(id), created_at timestamptz not null default now());
create table seller_orders (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references orders(id) on delete cascade,
  seller_id uuid not null references seller_profiles(id),
  ref text not null unique, total integer not null default 0,
  status text not null default 'nouvelle' check (status in ('nouvelle','confirmee','livree','annulee')),
  created_at timestamptz not null default now());
create table order_items (
  id uuid primary key default gen_random_uuid(),
  seller_order_id uuid not null references seller_orders(id) on delete cascade,
  product_id uuid references products(id) on delete set null,
  name text not null, unit_price integer not null, qty integer not null check (qty between 1 and 99),
  option text);
create index on products(seller_id); create index on products(category_id);
create index on product_images(product_id); create index on orders(client_id);
create index on seller_orders(seller_id); create index on seller_orders(order_id); create index on order_items(seller_order_id);
create index order_items_product_id_idx on order_items(product_id);

insert into categories(name,icon) values ('Mode & Prêt-à-porter','shirt'),('Bijoux & Accessoires','gem'),('Sacs & Maroquinerie','bag'),('Couture & Tissus','ruler'),('Beauté & Soins','sparkles'),('Cosmétiques naturels','droplet'),('Coiffure & Perruques','scissors'),('Maison & Déco','home'),('Alimentation & Épicerie','utensils'),('Pâtisserie & Traiteur','cake'),('Boissons & Jus','cup'),('Artisanat','palette'),('Enfants & Bébé','smile'),('Bien-être & Santé','heart'),('Cadeaux & Événements','gift'),('Services','briefcase');

-- Fonctions de rôle : is_admin vit dans le schéma « private », non exposé par l'API (/rest/v1/rpc/).
-- Les règles d'accès l'appellent avec les droits du visiteur : anon et authenticated doivent pouvoir l'exécuter.
create schema if not exists private;
grant usage on schema private to anon, authenticated;
create function private.is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;
revoke execute on function private.is_admin() from public; grant execute on function private.is_admin() to anon, authenticated;

-- Création automatique du profil : le rôle est TOUJOURS 'client' à l'inscription.
-- Le numéro saisi est nettoyé ; s'il est invalide il est ignoré (une erreur ici bloquerait l'inscription).
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
declare ph text:=regexp_replace(coalesce(new.raw_user_meta_data->>'phone',''),'\D','','g');
begin insert into profiles(id,email,full_name,role,phone) values(new.id,new.email,left(coalesce(new.raw_user_meta_data->>'full_name',''),80),'client',
  case when ph ~ '^[0-9]{8,15}$' then ph end); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();
-- Garde profiles.email aligné sur l'e-mail réel quand celui-ci change.
create function sync_profile_email() returns trigger language plpgsql security definer set search_path=public as $$
begin update profiles set email=new.email where id=new.id; return new; end $$;
create trigger on_auth_user_email after update of email on auth.users for each row
  when (new.email is distinct from old.email) execute function sync_profile_email();

-- Quand un compte devient vendeuse, sa boutique est créée avec le numéro de l'inscription comme WhatsApp
-- (une boutique existante garde son numéro s'il est déjà renseigné).
create function on_role_change() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into seller_profiles(id,shop_name,full_name,whatsapp) values(new.id,'Ma boutique',new.full_name,new.phone)
  on conflict (id) do update set whatsapp=coalesce(seller_profiles.whatsapp,excluded.whatsapp); return new; end $$;
create trigger profiles_role_seller after update of role on profiles for each row
  when (new.role='seller' and old.role is distinct from 'seller') execute function on_role_change();

-- Protection : un utilisateur ne peut jamais changer son rôle, son statut ou l'approbation d'un produit.
-- (auth.uid() est null dans le SQL Editor : c'est ainsi que l'on crée le tout premier admin.)
create function guard_profiles() returns trigger language plpgsql set search_path=public,private as $$
begin if new.role<>old.role and auth.uid() is not null and not is_admin() and coalesce(current_setting('app.bypass',true),'')<>'1' then raise exception 'Modification du rôle interdite'; end if; return new; end $$;
create trigger t_guard_profiles before update on profiles for each row execute function guard_profiles();
create function guard_sellers() returns trigger language plpgsql set search_path=public,private as $$
begin if new.status<>old.status and auth.uid() is not null and not is_admin() then raise exception 'Modification du statut interdite'; end if; return new; end $$;
create trigger t_guard_sellers before update on seller_profiles for each row execute function guard_sellers();
create function guard_products() returns trigger language plpgsql set search_path=public,private as $$
begin
  if auth.uid() is not null and not is_admin() then
    if tg_op='INSERT' then new.is_approved:=true;
    else
      if new.is_approved<>old.is_approved then raise exception 'Modération réservée à l''administration'; end if;
      if new.seller_id<>old.seller_id then raise exception 'Propriétaire non modifiable'; end if;
    end if;
  end if; return new; end $$;
create trigger t_guard_products before insert or update on products for each row execute function guard_products();

-- Promotion d'un compte (réservée à l'administrateur).
create function admin_set_role(target_email text, new_role user_role) returns void
language plpgsql security definer set search_path=public,private as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  -- Recherche par l'e-mail réel (auth.users), jamais par la copie de profiles.
  update profiles p set role=new_role from auth.users u where u.id=p.id and lower(u.email)=lower(target_email);
  if not found then raise exception 'Aucun compte avec cet e-mail'; end if;
end $$;

-- Passage de commande : produit disponible, option valide, stock suffisant, 5 commandes par heure au plus.
-- Prix, vendeuses et stock sont lus en base, jamais fournis par le navigateur ; le stock est décompté.
create function place_order(items jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
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
revoke execute on function admin_set_role(text,user_role) from public, anon; grant execute on function admin_set_role(text,user_role) to authenticated;

-- Commande annulée : le stock revient (et inversement si l'annulation est retirée).
create function restock_on_cancel() returns trigger language plpgsql security definer set search_path=public as $$
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
create trigger t_restock after update of status on seller_orders for each row execute function restock_on_cancel();

-- Fonctions de trigger : elles n'ont pas à être appelables par l'API.
revoke execute on function handle_new_user()    from public, anon, authenticated;
revoke execute on function sync_profile_email() from public, anon, authenticated;
revoke execute on function on_role_change()     from public, anon, authenticated;
revoke execute on function restock_on_cancel()  from public, anon, authenticated;

-- Alertes en direct : les nouvelles demandes sont diffusées à l'espace vendeuse (Realtime, filtré par RLS).
do $$ begin
  alter publication supabase_realtime add table seller_orders;
exception when duplicate_object then null; end $$;


-- ROW LEVEL SECURITY
alter table profiles enable row level security; alter table seller_profiles enable row level security;
alter table categories enable row level security; alter table products enable row level security;
alter table product_images enable row level security; alter table orders enable row level security;
alter table seller_orders enable row level security; alter table order_items enable row level security;

-- (select auth.uid()) et (select private.is_admin()) : calculés une fois par requête au lieu d'une fois par ligne.
create policy profiles_read on profiles for select using (id=(select auth.uid()) or (select private.is_admin()));
create policy profiles_update on profiles for update using (id=(select auth.uid()) or (select private.is_admin()));
-- Seul le nom est modifiable depuis le site : l'e-mail (copie d'auth.users) et le numéro (fixé à l'inscription, sert à reconnaître
-- les membres et à connecter les vendeuses) ne doivent pas pouvoir être usurpés. Le WhatsApp de boutique se modifie dans seller_profiles.
revoke update on profiles from authenticated, anon; grant update(full_name) on profiles to authenticated;

create policy sellers_read on seller_profiles for select using (status='active' or id=(select auth.uid()) or (select private.is_admin()));
create policy sellers_update on seller_profiles for update using (id=(select auth.uid()) or (select private.is_admin()));

-- Écriture découpée (insert / update / delete) pour ne pas doubler la règle de lecture.
create policy cat_read on categories for select using (true);
create policy cat_admin_insert on categories for insert with check ((select private.is_admin()));
create policy cat_admin_update on categories for update using ((select private.is_admin())) with check ((select private.is_admin()));
create policy cat_admin_delete on categories for delete using ((select private.is_admin()));

create policy prod_read on products for select using (
  (is_approved and exists(select 1 from seller_profiles s where s.id=seller_id and s.status='active'))
  or seller_id=(select auth.uid()) or (select private.is_admin()));
create policy prod_insert on products for insert with check (
  seller_id=(select auth.uid()) and exists(select 1 from seller_profiles s where s.id=(select auth.uid()) and s.status='active'));
create policy prod_update on products for update using (seller_id=(select auth.uid()) or (select private.is_admin()));
create policy prod_delete on products for delete using (seller_id=(select auth.uid()) or (select private.is_admin()));

create policy img_read on product_images for select using (exists(select 1 from products p where p.id=product_id));
create policy img_insert on product_images for insert with check (
  exists(select 1 from products p where p.id=product_id and (p.seller_id=(select auth.uid()) or (select private.is_admin()))));
create policy img_update on product_images for update
  using (exists(select 1 from products p where p.id=product_id and (p.seller_id=(select auth.uid()) or (select private.is_admin()))))
  with check (exists(select 1 from products p where p.id=product_id and (p.seller_id=(select auth.uid()) or (select private.is_admin()))));
create policy img_delete on product_images for delete using (
  exists(select 1 from products p where p.id=product_id and (p.seller_id=(select auth.uid()) or (select private.is_admin()))));

create policy orders_read on orders for select using (client_id=(select auth.uid()) or (select private.is_admin()));
create policy so_read on seller_orders for select using (
  seller_id=(select auth.uid()) or (select private.is_admin())
  or exists(select 1 from orders o where o.id=order_id and o.client_id=(select auth.uid())));
create policy so_update on seller_orders for update using (seller_id=(select auth.uid()) or (select private.is_admin()));
revoke update on seller_orders from authenticated, anon; grant update(status) on seller_orders to authenticated;  -- seule la colonne "status" est modifiable
create policy oi_read on order_items for select using (exists(select 1 from seller_orders so where so.id=seller_order_id));

-- STOCKAGE (bucket public en lecture ; écriture limitée au dossier de chaque vendeuse)
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('shop-media','shop-media',true,3145728,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
create policy media_read on storage.objects for select using (bucket_id='shop-media');
create policy media_insert on storage.objects for insert to authenticated with check (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from seller_profiles where id=auth.uid()) or private.is_admin()));
create policy media_update on storage.objects for update to authenticated using (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text or private.is_admin()));
create policy media_delete on storage.objects for delete to authenticated using (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text or private.is_admin()));

-- MEMBRES DU GROUPE : liste gérée par l'admin, identifiée en priorité par le numéro WhatsApp (e-mail facultatif).
create table member_whitelist (id uuid primary key default gen_random_uuid(),
  phone text check (phone is null or phone ~ '^[0-9]{8,15}$'),
  email text unique check (email = lower(email)),
  full_name text, created_at timestamptz not null default now(),
  constraint member_whitelist_contact_check check (email is not null or phone is not null));
create unique index member_whitelist_phone_key on member_whitelist(phone) where phone is not null;
create index profiles_phone_idx on profiles(phone);
alter table member_whitelist enable row level security;
create policy mw_admin on member_whitelist for all using (private.is_admin()) with check (private.is_admin());

-- Appelée à chaque connexion : un compte dont le numéro (ou l'e-mail) figure dans la liste renvoie 'pending'.
-- C'est l'admin qui valide ensuite (admin_activate_seller) : le numéro saisi à l'inscription n'est pas vérifié par SMS.
create function claim_membership() returns text language plpgsql security definer set search_path=public,auth as $$
declare u record;
begin
  select id,email,email_confirmed_at into u from auth.users where id=auth.uid();
  if u.id is null then return 'anon'; end if;
  if exists(select 1 from profiles where id=u.id and role in ('seller','admin')) then return 'ok'; end if;
  if exists(select 1 from member_whitelist w join profiles p on p.id=u.id where w.phone=p.phone or w.email=lower(u.email)) then return 'pending'; end if;
  return 'not_member';
end $$;
revoke execute on function claim_membership() from public, anon; grant execute on function claim_membership() to authenticated;

-- Validation par l'admin d'un compte inscrit avec le numéro d'une membre : la boutique est créée (trigger on_role_change).
create function admin_activate_seller(target uuid) returns void language plpgsql security definer set search_path=public,private as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  update profiles set role='seller' where id=target and role='client';
  if not found then raise exception 'Compte introuvable ou déjà vendeuse'; end if;
  update seller_profiles set status='active' where id=target;
end $$;
revoke execute on function admin_activate_seller(uuid) from public, anon; grant execute on function admin_activate_seller(uuid) to authenticated;

-- Connexion des vendeuses par numéro : renvoie l'e-mail du compte vendeuse lié à ce numéro (null sinon).
-- Limité aux vendeuses validées, dont le numéro est de toute façon public sur leur boutique.
create function seller_login_email(p text) returns text language sql stable security definer set search_path=public,auth as $$
  select u.email from profiles pr join auth.users u on u.id=pr.id
  where pr.phone=regexp_replace(coalesce(p,''),'\D','','g') and pr.role='seller' order by pr.created_at limit 1 $$;
revoke execute on function seller_login_email(text) from public; grant execute on function seller_login_email(text) to anon, authenticated;

-- PANIER DU COMPTE : il suit la cliente d'un appareil à l'autre. Contenu [{ id, qty, opt }] non garanti : place_order revérifie tout.
create table carts (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb
    check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) <= 100 and pg_column_size(items) < 20000),
  updated_at timestamptz not null default now());
alter table carts enable row level security;
revoke all on carts from anon;
create policy carts_read on carts for select to authenticated using (user_id=(select auth.uid()));
create policy carts_insert on carts for insert to authenticated with check (user_id=(select auth.uid()));
create policy carts_update on carts for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
create policy carts_delete on carts for delete to authenticated using (user_id=(select auth.uid()));

-- PREMIER ADMINISTRATEUR : après avoir créé votre compte sur le site, exécutez (en remplaçant l'e-mail) :
-- update profiles set role='admin' where id=(select id from auth.users where lower(email)=lower('votre@email.com'));
