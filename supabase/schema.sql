-- Les Reines de l'Entrepreneuriat — schéma complet. À coller dans Supabase > SQL Editor > Run.
create type user_role as enum ('client','seller','admin');
create type seller_status as enum ('pending','active','suspended');

create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text, full_name text default '', role user_role not null default 'client',
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
  stock integer not null default 1 check (stock >= 0),
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
  name text not null, unit_price integer not null, qty integer not null check (qty between 1 and 99));
create index on products(seller_id); create index on products(category_id);
create index on product_images(product_id); create index on orders(client_id);
create index on seller_orders(seller_id); create index on seller_orders(order_id); create index on order_items(seller_order_id);

insert into categories(name,icon) values ('Mode & Prêt-à-porter','shirt'),('Bijoux & Accessoires','gem'),('Sacs & Maroquinerie','bag'),('Couture & Tissus','ruler'),('Beauté & Soins','sparkles'),('Cosmétiques naturels','droplet'),('Coiffure & Perruques','scissors'),('Maison & Déco','home'),('Alimentation & Épicerie','utensils'),('Pâtisserie & Traiteur','cake'),('Boissons & Jus','cup'),('Artisanat','palette'),('Enfants & Bébé','smile'),('Bien-être & Santé','heart'),('Cadeaux & Événements','gift'),('Services','briefcase');

-- Fonctions de rôle
create function is_admin() returns boolean language sql stable security definer set search_path=public as
$$ select exists(select 1 from profiles where id=auth.uid() and role='admin') $$;

-- Création automatique du profil : le rôle est TOUJOURS 'client' à l'inscription.
create function handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into profiles(id,email,full_name,role) values(new.id,new.email,left(coalesce(new.raw_user_meta_data->>'full_name',''),80),'client'); return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();
-- Garde profiles.email aligné sur l'e-mail réel quand celui-ci change.
create function sync_profile_email() returns trigger language plpgsql security definer set search_path=public as $$
begin update profiles set email=new.email where id=new.id; return new; end $$;
create trigger on_auth_user_email after update of email on auth.users for each row
  when (new.email is distinct from old.email) execute function sync_profile_email();

-- Quand un compte devient vendeuse, sa boutique (en attente) est créée.
create function on_role_change() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into seller_profiles(id,shop_name,full_name) values(new.id,'Ma boutique',new.full_name) on conflict do nothing; return new; end $$;
create trigger profiles_role_seller after update of role on profiles for each row
  when (new.role='seller' and old.role is distinct from 'seller') execute function on_role_change();

-- Protection : un utilisateur ne peut jamais changer son rôle, son statut ou l'approbation d'un produit.
-- (auth.uid() est null dans le SQL Editor : c'est ainsi que l'on crée le tout premier admin.)
create function guard_profiles() returns trigger language plpgsql as $$
begin if new.role<>old.role and auth.uid() is not null and not is_admin() and coalesce(current_setting('app.bypass',true),'')<>'1' then raise exception 'Modification du rôle interdite'; end if; return new; end $$;
create trigger t_guard_profiles before update on profiles for each row execute function guard_profiles();
create function guard_sellers() returns trigger language plpgsql as $$
begin if new.status<>old.status and auth.uid() is not null and not is_admin() then raise exception 'Modification du statut interdite'; end if; return new; end $$;
create trigger t_guard_sellers before update on seller_profiles for each row execute function guard_sellers();
create function guard_products() returns trigger language plpgsql as $$
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
language plpgsql security definer set search_path=public as $$
begin
  if not is_admin() then raise exception 'Réservé à l''administrateur'; end if;
  -- Recherche par l'e-mail réel (auth.users), jamais par la copie de profiles.
  update profiles p set role=new_role from auth.users u where u.id=p.id and lower(u.email)=lower(target_email);
  if not found then raise exception 'Aucun compte avec cet e-mail'; end if;
end $$;

-- Passage de commande : les prix et vendeuses sont lus en base, jamais fournis par le navigateur.
create function place_order(items jsonb) returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); oid uuid; base text; n int:=0; sid uuid; soid uuid; res jsonb:='[]'::jsonb;
        it jsonb; p record; q int; lines jsonb; tot int; shop record;
begin
  if uid is null then raise exception 'Connexion requise'; end if;
  if jsonb_typeof(items)<>'array' or jsonb_array_length(items) not between 1 and 50 then raise exception 'Panier invalide'; end if;
  for it in select value from jsonb_array_elements(items) loop
    if not exists(select 1 from products pr join seller_profiles s on s.id=pr.seller_id
      where pr.id=(it->>'product_id')::uuid and pr.is_approved and pr.is_available and s.status='active')
    then raise exception 'Un produit du panier n''est plus disponible'; end if;
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
      insert into order_items(seller_order_id,product_id,name,unit_price,qty) values(soid,p.id,p.name,p.price_fcfa,q);
      tot:=tot+q*p.price_fcfa;
      lines:=lines||jsonb_build_array(jsonb_build_object('name',p.name,'qty',q,'price',p.price_fcfa));
    end loop;
    update seller_orders set total=tot where id=soid;
    select shop_name, whatsapp into shop from seller_profiles where id=sid;
    res:=res||jsonb_build_array(jsonb_build_object('ref',base||'-'||n,'shop_name',shop.shop_name,'whatsapp',shop.whatsapp,'total',tot,'items',lines));
  end loop;
  return res;
end $$;
revoke execute on function place_order(jsonb) from public, anon; grant execute on function place_order(jsonb) to authenticated;
revoke execute on function admin_set_role(text,user_role) from public, anon; grant execute on function admin_set_role(text,user_role) to authenticated;

-- ROW LEVEL SECURITY
alter table profiles enable row level security; alter table seller_profiles enable row level security;
alter table categories enable row level security; alter table products enable row level security;
alter table product_images enable row level security; alter table orders enable row level security;
alter table seller_orders enable row level security; alter table order_items enable row level security;

create policy profiles_read on profiles for select using (id=auth.uid() or is_admin());
create policy profiles_update on profiles for update using (id=auth.uid() or is_admin());
-- Seul le nom est modifiable depuis le site : l'e-mail est une copie d'auth.users et ne doit pas pouvoir être usurpé.
revoke update on profiles from authenticated, anon; grant update(full_name) on profiles to authenticated;

create policy sellers_read on seller_profiles for select using (status='active' or id=auth.uid() or is_admin());
create policy sellers_update on seller_profiles for update using (id=auth.uid() or is_admin());

create policy cat_read on categories for select using (true);
create policy cat_admin on categories for all using (is_admin()) with check (is_admin());

create policy prod_read on products for select using (
  (is_approved and exists(select 1 from seller_profiles s where s.id=seller_id and s.status='active')) or seller_id=auth.uid() or is_admin());
create policy prod_insert on products for insert with check (
  seller_id=auth.uid() and exists(select 1 from seller_profiles s where s.id=auth.uid() and s.status='active'));
create policy prod_update on products for update using (seller_id=auth.uid() or is_admin());
create policy prod_delete on products for delete using (seller_id=auth.uid() or is_admin());

create policy img_read on product_images for select using (exists(select 1 from products p where p.id=product_id));
create policy img_write on product_images for all
  using (exists(select 1 from products p where p.id=product_id and (p.seller_id=auth.uid() or is_admin())))
  with check (exists(select 1 from products p where p.id=product_id and (p.seller_id=auth.uid() or is_admin())));

create policy orders_read on orders for select using (client_id=auth.uid() or is_admin());
create policy so_read on seller_orders for select using (seller_id=auth.uid() or is_admin() or exists(select 1 from orders o where o.id=order_id and o.client_id=auth.uid()));
create policy so_update on seller_orders for update using (seller_id=auth.uid() or is_admin());
revoke update on seller_orders from authenticated, anon; grant update(status) on seller_orders to authenticated;  -- seule la colonne "status" est modifiable
create policy oi_read on order_items for select using (exists(select 1 from seller_orders so where so.id=seller_order_id));

-- STOCKAGE (bucket public en lecture ; écriture limitée au dossier de chaque vendeuse)
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('shop-media','shop-media',true,3145728,array['image/jpeg','image/png','image/webp']) on conflict (id) do nothing;
create policy media_read on storage.objects for select using (bucket_id='shop-media');
create policy media_insert on storage.objects for insert to authenticated with check (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text and exists(select 1 from seller_profiles where id=auth.uid()) or is_admin()));
create policy media_update on storage.objects for update to authenticated using (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text or is_admin()));
create policy media_delete on storage.objects for delete to authenticated using (bucket_id='shop-media' and ((storage.foldername(name))[1]=auth.uid()::text or is_admin()));

-- MEMBRES DU GROUPE : seules les adresses de cette liste (gérée par l'admin) peuvent devenir vendeuses.
create table member_whitelist (id uuid primary key default gen_random_uuid(), email text not null unique check (email = lower(email)), full_name text, created_at timestamptz not null default now());
alter table member_whitelist enable row level security;
create policy mw_admin on member_whitelist for all using (is_admin()) with check (is_admin());
-- Appelée à la connexion : active le rôle vendeuse si l'e-mail est CONFIRMÉ et présent dans la liste.
create function claim_membership() returns text language plpgsql security definer set search_path=public,auth as $$
declare u record;
begin
  select id,email,email_confirmed_at into u from auth.users where id=auth.uid();
  if u.id is null then return 'anon'; end if;
  if u.email_confirmed_at is null then return 'unconfirmed'; end if;
  if not exists(select 1 from member_whitelist where email=lower(u.email)) then return 'not_member'; end if;
  if exists(select 1 from profiles where id=u.id and role in ('seller','admin')) then return 'ok'; end if;
  perform set_config('app.bypass','1',true);
  update profiles set role='seller' where id=u.id;
  return 'ok';
end $$;
revoke execute on function claim_membership() from public, anon; grant execute on function claim_membership() to authenticated;

-- PREMIER ADMINISTRATEUR : après avoir créé votre compte sur le site, exécutez (en remplaçant l'e-mail) :
-- update profiles set role='admin' where id=(select id from auth.users where lower(email)=lower('votre@email.com'));
