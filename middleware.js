// Aperçu de lien (WhatsApp, Facebook, Telegram…) propre à chaque produit et à chaque boutique.
// Ces robots ne lisent pas le contenu chargé par JavaScript : pour eux seuls, ce middleware Vercel répond aux fiches
// boutique/produit.html?id=… et boutique/vendeuse.html?id=… avec le nom, le prix et la photo. Les visiteuses et Google
// reçoivent la page normale (le middleware ne répond rien). Lecture publique (clé « anon », la même que dans js/config.js).
export const config = { matcher: ['/boutique/produit.html', '/boutique/vendeuse.html'] };

const BOTS = /WhatsApp|facebookexternalhit|Facebot|meta-externalagent|TelegramBot|Twitterbot|LinkedInBot|Slackbot|Discordbot|SkypeUriPreview|Pinterest|redditbot|vkShare|Viber|SnapchatAds/i;
const SB = 'https://wxdmdvxmxhoijfyshyyg.supabase.co';
const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4ZG1kdnhteGhvaWpmeXNoeXlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwNTI4NzEsImV4cCI6MjEwODYyODg3MX0.rK0Off0QoFTEQ50lPjaddX8aU9NaP4IWMqDQqYuflKw';
const SITE = 'https://www.lesreinesboutique.com', NAME = 'Les Reines de l’Entrepreneuriat';
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const cut = (s, n) => { s = String(s || '').replace(/\s+/g, ' ').trim(); return s.length > n ? s.slice(0, n - 1).trimEnd() + '…' : s; };
const media = p => p ? `${SB}/storage/v1/object/public/shop-media/${p.split('/').map(encodeURIComponent).join('/')}` : `${SITE}/assets/hero.jpg`;
const fcfa = n => String(Math.round(Number(n) || 0)).replace(/\B(?=(\d{3})+(?!\d))/g, ' ') + ' FCFA';
const get = async q => {
  const r = await fetch(`${SB}/rest/v1/${q}`, { headers: { apikey: ANON, Authorization: `Bearer ${ANON}` } });
  return r.ok ? (await r.json())[0] : null;
};

export default async function middleware(request) {
  if (!BOTS.test(request.headers.get('user-agent') || '')) return; // visiteuse ou Google : page normale
  const u = new URL(request.url), id = u.searchParams.get('id') || '', shop = u.pathname.endsWith('vendeuse.html');
  const url = `${SITE}${u.pathname}${id ? '?id=' + encodeURIComponent(id) : ''}`;
  let t, d, image;
  try {
    if (/^[0-9a-f-]{36}$/i.test(id) && !shop) {
      const p = await get(`products?id=eq.${id}&select=name,price_fcfa,promo_price_fcfa,description,seller_profiles(shop_name),product_images(path,position)`);
      if (p) {
        const im = (p.product_images || []).sort((a, b) => a.position - b.position)[0];
        const promo = p.promo_price_fcfa != null && p.promo_price_fcfa < p.price_fcfa;
        t = promo ? `${p.name} — ${fcfa(p.promo_price_fcfa)} au lieu de ${fcfa(p.price_fcfa)}` : `${p.name} — ${fcfa(p.price_fcfa)}`;
        d = `${p.seller_profiles?.shop_name ? 'Par ' + p.seller_profiles.shop_name + ' · ' : ''}${cut(p.description, 140) || 'Une création des Reines de l’Entrepreneuriat, à commander sur WhatsApp.'}`;
        image = media(im?.path);
      }
    } else if (/^[0-9a-f-]{36}$/i.test(id)) {
      const s = await get(`seller_profiles?id=eq.${id}&select=shop_name,description,location,logo_path,cover_path`);
      if (s) {
        t = `${s.shop_name} — ${NAME}`;
        d = cut(s.description, 160) || `La boutique de ${s.shop_name}${s.location ? ', ' + s.location : ''} : ses créations, à commander sur WhatsApp.`;
        image = media(s.cover_path || s.logo_path);
      }
    }
  } catch { /* base injoignable : aperçu général ci-dessous */ }
  t = t || NAME; d = d || 'La boutique collective des Reines de l’Entrepreneuriat.'; image = image || `${SITE}/assets/hero.jpg`;
  return new Response(`<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8"><title>${esc(t)}</title>
<meta name="description" content="${esc(d)}"><link rel="canonical" href="${esc(url)}">
<meta property="og:type" content="${shop ? 'website' : 'product'}"><meta property="og:site_name" content="${esc(NAME)}"><meta property="og:locale" content="fr_FR">
<meta property="og:title" content="${esc(t)}"><meta property="og:description" content="${esc(d)}"><meta property="og:url" content="${esc(url)}">
<meta property="og:image" content="${esc(image)}"><meta name="twitter:card" content="summary_large_image">
</head><body><p><a href="${esc(url)}">${esc(t)}</a></p></body></html>`, {
    headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' } // jamais en cache partagé : réservé aux robots
  });
}
