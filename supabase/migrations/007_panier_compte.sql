-- Panier enregistré dans le compte : il suit la cliente d'un appareil ou d'un navigateur à l'autre.
-- À coller dans Supabase > SQL Editor > Run, après 006_securite_fonctions.sql. Peut être relancé sans risque.
-- Contenu : [{ id, qty, opt }] comme le panier local. Rien n'y est garanti : place_order revérifie tout.

create table if not exists public.carts (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  items jsonb not null default '[]'::jsonb
    check (jsonb_typeof(items) = 'array' and jsonb_array_length(items) <= 100 and pg_column_size(items) < 20000),
  updated_at timestamptz not null default now()
);
alter table public.carts enable row level security;
revoke all on public.carts from anon;

-- Chacune ne voit et ne modifie que son propre panier.
drop policy if exists carts_read on public.carts;
create policy carts_read on public.carts for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists carts_insert on public.carts;
create policy carts_insert on public.carts for insert to authenticated with check (user_id = (select auth.uid()));
drop policy if exists carts_update on public.carts;
create policy carts_update on public.carts for update to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
drop policy if exists carts_delete on public.carts;
create policy carts_delete on public.carts for delete to authenticated using (user_id = (select auth.uid()));
