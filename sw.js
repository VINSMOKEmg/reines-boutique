// Service worker de l'espace vendeuse.
// - push : notification « Nouvelle commande » envoyée par la fonction notify-order, même site fermé et téléphone verrouillé.
// - Android n'affiche aussi les alertes de la page ouverte que par son intermédiaire (voir notify dans js/ui.js).
// - Un clic sur l'alerte ramène sur l'espace vendeuse déjà ouvert, ou ouvre la page des commandes.
const ICON = new URL('assets/logo.png', self.registration.scope).href;
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('push', e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch { }
  e.waitUntil(self.registration.showNotification(d.title || 'Nouvelle commande', {
    body: d.body || '', tag: d.tag, renotify: true, icon: ICON, badge: ICON, vibrate: [200, 100, 200],
    data: { url: d.url || 'vendeuse/mes-commandes.html' }
  }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = new URL(e.notification.data?.url || 'vendeuse/mes-commandes.html', self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(L => {
    const w = L.find(c => c.url.includes('/vendeuse/'));
    return w ? w.focus() : self.clients.openWindow(url);
  }));
});
