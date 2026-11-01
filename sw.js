// Service worker minimal de l'espace vendeuse : Android n'affiche une notification que par son intermédiaire.
// Un clic sur l'alerte ramène sur l'espace vendeuse déjà ouvert, ou ouvre la page des commandes.
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', e => e.waitUntil(self.clients.claim()));
self.addEventListener('notificationclick', e => {
  e.notification.close();
  e.waitUntil(self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(L => {
    const w = L.find(c => c.url.includes('/vendeuse/'));
    return w ? w.focus() : self.clients.openWindow(new URL('vendeuse/mes-commandes.html', self.registration.scope).href);
  }));
});
