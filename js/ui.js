import { sb, me, requireRole } from './supabase.js';
import * as cart from './cart.js';
export const ICONS = {"shirt": ["M20.4 3.5 16 2a4 4 0 0 1-8 0L3.6 3.5a2 2 0 0 0-1.3 2.2l.6 3.5a1 1 0 0 0 1 .8H6v10a2 2 0 0 0 2 2h8a2 2 0 0 0 2-2V10h2.1a1 1 0 0 0 1-.8l.6-3.5a2 2 0 0 0-1.3-2.2z"], "gem": ["M6 3h12l4 6-10 13L2 9z", "M11 3 8 9l4 13 4-13-3-6", "M2 9h20"], "bag": ["M6 2 3 6v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6l-3-4z", "M3 6h18", "M16 10a4 4 0 0 1-8 0"], "ruler": ["M21.3 15.3a2.4 2.4 0 0 1 0 3.4l-2.6 2.6a2.4 2.4 0 0 1-3.4 0L2.7 8.7a2.4 2.4 0 0 1 0-3.4l2.6-2.6a2.4 2.4 0 0 1 3.4 0z", "M14.5 12.5l2-2", "M11.5 9.5l2-2", "M8.5 6.5l2-2", "M17.5 15.5l2-2"], "sparkles": ["M9.9 15.5A2 2 0 0 0 8.5 14.1l-6.1-1.6a.5.5 0 0 1 0-1L8.5 9.9A2 2 0 0 0 9.9 8.5l1.6-6.1a.5.5 0 0 1 1 0l1.6 6.1a2 2 0 0 0 1.4 1.4l6.1 1.6a.5.5 0 0 1 0 1l-6.1 1.6a2 2 0 0 0-1.4 1.4l-1.6 6.1a.5.5 0 0 1-1 0z"], "droplet": ["M12 22a7 7 0 0 0 7-7c0-2-1-3.9-3-5.5s-3.5-4-4-6.5c-.5 2.5-2 4.9-4 6.5C6 11.1 5 13 5 15a7 7 0 0 0 7 7z"], "scissors": ["M6 9a3 3 0 1 0 0-6 3 3 0 0 0 0 6z", "M6 21a3 3 0 1 0 0-6 3 3 0 0 0 0 6z", "M20 4 8.1 15.9", "M14.5 14.5 20 20", "M8.1 8.1 12 12"], "home": ["M3 10l9-7 9 7v10a1 1 0 0 1-1 1h-5v-7H9v7H4a1 1 0 0 1-1-1z"], "utensils": ["M3 2v7a2 2 0 0 0 2 2h4a2 2 0 0 0 2-2V2", "M7 2v20", "M21 15V2a5 5 0 0 0-5 5v6a2 2 0 0 0 2 2h3zm0 0v7"], "cake": ["M20 21v-8a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8", "M4 16s.5-1 2-1 2.5 2 4 2 2.5-2 4-2 2.5 2 4 2 2-1 2-1", "M2 21h20", "M7 8v3", "M12 8v3", "M17 8v3", "M7 4h.01", "M12 4h.01", "M17 4h.01"], "cup": ["M10 2v2", "M14 2v2", "M6 2v2", "M16 8h1a4 4 0 1 1 0 8h-1", "M3 8h14v9a4 4 0 0 1-4 4H7a4 4 0 0 1-4-4z"], "palette": ["M12 22a1 1 0 0 1 0-20 10 9 0 0 1 10 9 5 5 0 0 1-5 5h-2.3a1.7 1.7 0 0 0-1.4 2.8l.3.4a1.7 1.7 0 0 1-1.4 2.8z", "M13.5 6.5h.01", "M17.5 10.5h.01", "M6.5 12.5h.01", "M8.5 7.5h.01"], "smile": ["M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z", "M8 14s1.5 2 4 2 4-2 4-2", "M9 9h.01", "M15 9h.01"], "heart": ["M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7z"], "gift": ["M20 12v10H4V12", "M2 7h20v5H2z", "M12 22V7", "M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z", "M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z"], "briefcase": ["M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16", "M4 6h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2z"], "search": ["M11 18a7 7 0 1 0 0-14 7 7 0 0 0 0 14z", "M21 21l-4.3-4.3"], "user": ["M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z", "M4 21a8 8 0 0 1 16 0"], "cart": ["M3 3h2l2.4 12.4a2 2 0 0 0 2 1.6h7.7a2 2 0 0 0 2-1.5L21 8H6", "M10 21h.01", "M18 21h.01"], "shield": ["M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z", "M8.5 12l2.5 2.5 4.5-5"], "chat": ["M21 12a8 8 0 0 1-11.6 7.1L3 21l1.9-5.4A8 8 0 1 1 21 12z"], "crown": ["M3 8l4.5 4L12 5l4.5 7L21 8l-2 11H5z"], "store": ["M4 9l1-5h14l1 5", "M4 9a2.7 2.7 0 0 0 5.3 0 2.7 2.7 0 0 0 5.4 0A2.7 2.7 0 0 0 20 9", "M5 12v8h14v-8", "M10 20v-5h4v5"], "box": ["M21 8l-9-5-9 5v8l9 5 9-5z", "M3.3 7.5 12 12.5l8.7-5", "M12 22V12.5"], "truck": ["M1 6h13v10H1z","M14 9h4l3 3v4h-7","M5.5 19.2a1.5 1.5 0 1 0 .01 0","M17.5 19.2a1.5 1.5 0 1 0 .01 0"], "wallet": ["M3 7h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z","M3 7l13-3v3","M16 14h2"], "clock": ["M12 22a10 10 0 1 0 0-20 10 10 0 0 0 0 20z","M12 7v5l3 2"], "menu": ["M4 6h16","M4 12h16","M4 18h16"], "close": ["M6 6l12 12","M18 6 6 18"], "dots": ["M5 12h.01", "M12 12h.01", "M19 12h.01"]};
export const ic = n => `<svg class="ic" viewBox="0 0 24 24" aria-hidden="true">${(ICONS[n]||ICONS.dots).map(d => `<path d="${d}"/>`).join('')}</svg>`;
export const PSEL = 'id,name,price_fcfa,is_available,seller_id,categories(name),seller_profiles(shop_name,logo_path),product_images(path,position)';
export const $ = (s, r = document) => r.querySelector(s);
export const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const money = n => Number(n).toLocaleString('fr-FR') + ' FCFA';
export const img = p => p ? sb.storage.from('shop-media').getPublicUrl(p).data.publicUrl : 'assets/placeholder.svg';
export const firstImg = p => [...(p.product_images || [])].sort((a, b) => a.position - b.position)[0]?.path;
export function toast(m, err) { const t = document.createElement('div'); t.className = 'toast' + (err ? ' err' : ''); t.textContent = m; document.body.append(t); setTimeout(() => t.remove(), 3500); }
export const logout = () => sb.auth.signOut().then(() => location.href = 'index.html');

export async function header() {
  let u = null; try { u = await me(); } catch {}
  const home = { seller: 'dashboard.html', admin: 'admin.html', client: 'client.html' }[u?.role] || 'connexion.html';
  const who = u ? esc((u.full_name || 'Compte').split(' ')[0]) : 'Compte';
  const pg = location.pathname.split('/').pop() || 'index.html';
  const on = (...n) => n.includes(pg) ? ' class="on"' : '';
  $('#hdr').innerHTML = `<div class="top"><button type="button" class="burger" id="bg" aria-label="Menu" aria-expanded="false" aria-controls="drawer">${ic('menu')}</button>
  <a class="brand" href="index.html"><img src="assets/logo.jpg" alt="Logo"><span><b>Les Reines</b><small>de l’Entrepreneuriat</small></span></a>
  <form class="search" action="catalogue.html">${ic('search')}<input name="q" placeholder="Rechercher un produit, une vendeuse…" aria-label="Rechercher"></form>
  <div class="ico"><a href="catalogue.html?fav=1">${ic('heart')}Favoris</a><a href="${home}">${ic('user')}${who}</a><a href="panier.html">${ic('cart')}Panier<i id="cc"></i></a></div></div>
  <nav class="mnav"><a href="index.html"${on('index.html', '')}>Accueil</a><a href="catalogue.html"${on('catalogue.html', 'produit.html')}>Boutique</a><a href="vendeuses.html"${on('vendeuses.html', 'vendeuse.html')}>Vendeuses</a><a href="apropos.html"${on('apropos.html')}>À propos</a><a href="contact.html"${on('contact.html')}>Contact</a></nav>
  <nav class="tabs"><a href="index.html"${on('index.html', '')}>${ic('home')}Accueil</a><a href="catalogue.html#niches"${on('catalogue.html')}>${ic('gem')}Catégories</a><a href="vendeuses.html"${on('vendeuses.html')}>${ic('store')}Vendeuses</a><a href="panier.html"${on('panier.html')}>${ic('cart')}Panier</a><a href="${home}">${ic('user')}${who}</a></nav>
  <div class="ov" id="ov"></div><aside class="drawer" id="drawer" aria-label="Menu"><div class="dh"><a class="brand" href="index.html"><img src="assets/logo.jpg" alt=""><span><b>Les Reines</b><small>de l’Entrepreneuriat</small></span></a><button type="button" class="dx" data-close aria-label="Fermer">${ic('close')}</button></div>
  <a href="index.html">${ic('home')}Accueil</a><a href="catalogue.html">${ic('bag')}Boutique</a><a href="catalogue.html#niches">${ic('gem')}Catégories</a><a href="vendeuses.html">${ic('store')}Vendeuses</a><a href="catalogue.html?fav=1">${ic('heart')}Mes favoris</a><a href="apropos.html">${ic('crown')}À propos</a><a href="contact.html">${ic('chat')}Contact</a><hr>
  <a href="panier.html">${ic('cart')}Mon panier</a><a href="${home}">${ic('user')}${u ? 'Mon espace' : 'Connexion'}</a>${u ? '<a href="#" id="dlo">' + ic('close') + 'Déconnexion</a>' : '<a href="inscription.html">' + ic('user') + 'Créer un compte</a>'}</aside>`;
  const bg = $('#bg'), tog = o => { document.body.classList.toggle('menu-open', o); bg.setAttribute('aria-expanded', o); };
  bg.onclick = () => tog(!document.body.classList.contains('menu-open')); $('#ov').onclick = () => tog(false);
  $('#drawer').addEventListener('click', e => { if (e.target.closest('a,[data-close]')) tog(false); });
  document.addEventListener('keydown', e => { if (e.key === 'Escape') tog(false); });
  if ($('#dlo')) $('#dlo').onclick = ev => { ev.preventDefault(); logout(); };
  const upd = () => { const n = cart.count(), el = $('#cc'); el.textContent = n || ''; el.hidden = !n; }; upd(); document.addEventListener('cart', upd);
  return u;
}
const FK = 'reines_fav';
export const favs = () => { try { return JSON.parse(localStorage.getItem(FK) || '[]'); } catch { return []; } };
document.addEventListener('click', e => { const h = e.target.closest('[data-fav]'); if (!h) return; e.preventDefault(); e.stopPropagation();
  const id = h.dataset.fav; let f = favs(); f = f.includes(id) ? f.filter(x => x !== id) : [...f, id]; localStorage.setItem(FK, JSON.stringify(f)); h.classList.toggle('on'); });
// Apparition douce des éléments au défilement
const io = 'IntersectionObserver' in window ? new IntersectionObserver(es => es.forEach(x => { if (x.isIntersecting) { x.target.classList.add('in'); io.unobserve(x.target); } }), { threshold: .08 }) : null;
new MutationObserver(() => document.querySelectorAll('.rv:not(.seen)').forEach(el => { el.classList.add('seen'); io ? io.observe(el) : el.classList.add('in'); })).observe(document.documentElement, { childList: true, subtree: true });
document.addEventListener('click', e => {
  const a = e.target.closest('[data-add],[data-go]'); if (!a) return;
  cart.add(a.dataset.add || a.dataset.go);
  if (a.dataset.go) { me().then(u => { location.href = u ? 'panier.html' : 'connexion.html?next=panier.html'; }).catch(() => { location.href = 'connexion.html?next=panier.html'; }); } else toast('Produit ajouté au panier');
});
export const mini = sp => sp?.logo_path ? `<img class="mi" src="${img(sp.logo_path)}" alt="">` : `<span class="mi">${esc((sp?.shop_name || '?')[0])}</span>`;
export const card = p => `<div class="p"><a href="produit.html?id=${p.id}" class="ph"><img loading="lazy" src="${img(firstImg(p))}" alt="${esc(p.name)}"><button type="button" class="heart ${favs().includes(p.id) ? 'on' : ''}" data-fav="${p.id}" aria-label="Favori">${ic('heart')}</button></a>
<div class="pb"><b>${esc(p.name)}</b><div class="pr">${money(p.price_fcfa)}</div><div class="sl">${mini(p.seller_profiles)}${esc(p.seller_profiles?.shop_name)}</div>
${p.is_available ? `<div class="acts"><button class="btn" data-go="${p.id}">Commander</button><button class="btn wa" data-add="${p.id}">Ajouter au panier</button></div>` : '<p class="mut" style="margin:0">Indisponible</p>'}</div></div>`;

// Coque du dashboard vendeuse : menu + vérification du rôle + bandeau de validation.
export async function seller(active) {
  const u = await requireRole(['seller']); if (!u) return null;
  const { data: shop } = await sb.from('seller_profiles').select('*').eq('id', u.id).single();
  const L = [['dashboard.html', 'Vue d’ensemble', 'home'], ['profil-boutique.html', 'Ma boutique', 'store'], ['mes-produits.html', 'Mes produits', 'box'], ['ajouter-produit.html', 'Ajouter un produit', 'gift'], ['dashboard.html#commandes', 'Demandes de commande', 'chat']];
  $('#side').innerHTML = '<h4>Espace Vendeuse</h4>' + L.map(l => `<a href="${l[0]}" class="${l[0] === active ? 'on' : ''}">${l[1]}</a>`).join('') + '<a href="#" id="lo">Déconnexion</a>';
  $('#lo').onclick = e => { e.preventDefault(); logout(); };
  if (shop?.status === 'suspended') $('#bn').innerHTML = '<div class="note" style="margin:0">Votre boutique est suspendue par l’administration : vos produits ne sont plus visibles. Contactez-la pour la réactiver.</div>';
  return { u, shop };
}
