-- Notifications push : la vendeuse est prévenue de chaque nouvelle commande, même téléphone verrouillé.
-- À coller dans Supabase > SQL Editor > Run, après 008_total_commande_alerte.sql. Peut être relancé sans risque.
-- Envoi : fonction Edge « notify-order » (supabase/functions/notify-order), appelée par la base à chaque commande.

create extension if not exists pg_net with schema extensions;

-- 1. Appareils abonnés (un par navigateur / téléphone). Clés fournies par le navigateur, sans secret côté site.
create table if not exists public.push_subscriptions (
  endpoint text primary key check (endpoint ~ '^https://' and char_length(endpoint) < 1000),
  user_id uuid not null references auth.users(id) on delete cascade,
  p256dh text not null check (char_length(p256dh) < 200),
  auth text not null check (char_length(auth) < 100),
  created_at timestamptz not null default now());
create index if not exists push_subscriptions_user_id_idx on public.push_subscriptions(user_id);
alter table public.push_subscriptions enable row level security;
revoke all on public.push_subscriptions from anon;
-- Lecture et suppression de ses propres appareils ; l'enregistrement passe par save_push_subscription.
drop policy if exists push_read on public.push_subscriptions;
create policy push_read on public.push_subscriptions for select to authenticated using (user_id = (select auth.uid()));
drop policy if exists push_delete on public.push_subscriptions;
create policy push_delete on public.push_subscriptions for delete to authenticated using (user_id = (select auth.uid()));

-- Un appareil appartient au dernier compte connecté dessus (téléphone partagé, changement de compte).
create or replace function public.save_push_subscription(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Connexion requise'; end if;
  insert into push_subscriptions(endpoint, user_id, p256dh, auth) values (p_endpoint, auth.uid(), p_p256dh, p_auth)
    on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth, created_at = now();
end $$;
revoke execute on function public.save_push_subscription(text, text, text) from public, anon;
grant execute on function public.save_push_subscription(text, text, text) to authenticated;

-- 2. Une seule notification par commande, même si l'appel est rejoué (marqué par la fonction d'envoi).
alter table public.seller_orders add column if not exists notified_at timestamptz;

-- 3. À chaque commande, la base appelle la fonction d'envoi (asynchrone : n'allonge ni ne bloque la commande).
create or replace function private.notify_new_order() returns trigger
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform net.http_post(
    url := 'https://wxdmdvxmxhoijfyshyyg.supabase.co/functions/v1/notify-order',
    body := jsonb_build_object('seller_order_id', new.id),
    -- Clé publique (« anon ») du projet, la même que dans js/config.js : exigée pour appeler une fonction Edge.
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4ZG1kdnhteGhvaWpmeXNoeXlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwNTI4NzEsImV4cCI6MjEwODYyODg3MX0.rK0Off0QoFTEQ50lPjaddX8aU9NaP4IWMqDQqYuflKw'),
    timeout_milliseconds := 10000);
  return new;
end $$;
revoke execute on function private.notify_new_order() from public, anon, authenticated;
drop trigger if exists t_notify_new_order on public.seller_orders;
create trigger t_notify_new_order after insert on public.seller_orders for each row execute function private.notify_new_order();
