// Notification push « Nouvelle commande » envoyée aux appareils de la vendeuse.
// Appelée par la base à chaque commande (trigger t_notify_new_order, migration 009) avec la clé publique du projet :
// elle ne fait confiance qu'à l'identifiant reçu, relit tout en base, et n'envoie qu'une fois par commande récente.
// Secret à définir (Supabase > Edge Functions > Secrets) : VAPID_PRIVATE_KEY. La clé publique est aussi dans js/config.js.
import webpush from "npm:web-push@3.6.7";
import { createClient } from "npm:@supabase/supabase-js@2";

const VAPID_PUBLIC_KEY = "BCnBzMzHw_s0nU_oKyFkUiXYo6OaoIN_xv70TQvuMLmO4pdILB9DY1fOYQnOwHKsccHmYX-7G0-j5pP093Ca1rE";
const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: { "Content-Type": "application/json" } });
const fcfa = (n: number) => n.toLocaleString("fr-FR").replace(/ | /g, " ") + " FCFA";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "POST attendu" }, 405);
  const key = Deno.env.get("VAPID_PRIVATE_KEY");
  if (!key) return json({ error: "Secret VAPID_PRIVATE_KEY manquant" }, 500);
  webpush.setVapidDetails("https://reines-boutique.vercel.app", VAPID_PUBLIC_KEY, key);

  const { seller_order_id: id } = await req.json().catch(() => ({}));
  if (typeof id !== "string" || !/^[0-9a-f-]{36}$/i.test(id)) return json({ error: "Identifiant invalide" }, 400);

  // Marque la commande « notifiée » : un même appel rejoué, ou une vieille commande, n'envoie rien.
  const { data: o, error } = await sb.from("seller_orders")
    .update({ notified_at: new Date().toISOString() })
    .eq("id", id).is("notified_at", null).gt("created_at", new Date(Date.now() - 10 * 60_000).toISOString())
    .select("id,ref,total,seller_id").maybeSingle();
  if (error) return json({ error: error.message }, 500);
  if (!o) return json({ sent: 0, info: "Commande introuvable, ancienne ou déjà notifiée" });

  const { data: subs } = await sb.from("push_subscriptions").select("endpoint,p256dh,auth").eq("user_id", o.seller_id);
  const payload = JSON.stringify({ title: "Nouvelle commande", body: `${o.ref} · ${fcfa(o.total)}`, tag: o.ref, url: "vendeuse/mes-commandes.html" });
  const res = await Promise.allSettled((subs ?? []).map((s) =>
    webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 86400, urgency: "high" })));

  // Appareils désabonnés ou expirés : retirés de la liste.
  const dead = res.flatMap((r, i) => r.status === "rejected" && [404, 410].includes((r.reason as { statusCode?: number })?.statusCode ?? 0) ? [subs![i].endpoint] : []);
  if (dead.length) await sb.from("push_subscriptions").delete().in("endpoint", dead);
  const failed = res.flatMap((r) => r.status === "rejected" ? [String((r.reason as { statusCode?: number; body?: string })?.statusCode ?? (r.reason as Error)?.message)] : []);
  return json({ sent: res.length - failed.length, failed, removed: dead.length });
});
