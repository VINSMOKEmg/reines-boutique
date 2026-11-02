// Captcha Cloudflare Turnstile (connexion, inscription, mot de passe oublié), exigé par Supabase quand
// « Captcha protection » est activée dans Authentication > Attack Protection.
// Sans clé publique (TURNSTILE_SITE_KEY vide dans config.js) : rien n'est affiché, aucun jeton n'est envoyé.
// Le plus souvent invisible ; une case à cocher n'apparaît que si Cloudflare a un doute.
import { TURNSTILE_SITE_KEY } from './config.js';

let wid = null, tok = '', waiting = [];
const take = () => { const t = tok; tok = ''; if (wid != null) window.turnstile.reset(wid); return t; }; // jeton à usage unique
const got = t => { tok = t; waiting.splice(0).forEach(f => f()); };

// Place le widget dans `el` (une div du formulaire) et charge le script de Cloudflare.
export function mountCaptcha(el) {
  if (!TURNSTILE_SITE_KEY || !el) return;
  window.onTurnstileLoad = () => {
    wid = window.turnstile.render(el, {
      sitekey: TURNSTILE_SITE_KEY, language: 'fr', appearance: 'interaction-only',
      callback: got, 'expired-callback': () => { tok = ''; }, 'error-callback': () => { tok = ''; }
    });
  };
  const s = document.createElement('script');
  s.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?onload=onTurnstileLoad&render=explicit';
  s.async = true;
  document.head.append(s);
}

// Jeton à joindre à l'appel Supabase (undefined sans captcha) ; attend la vérification si elle n'est pas finie.
export function captchaToken(ms = 20000) {
  if (!TURNSTILE_SITE_KEY) return Promise.resolve(undefined);
  if (tok) return Promise.resolve(take());
  return new Promise(res => {
    const t = setTimeout(() => res(''), ms);
    waiting.push(() => { clearTimeout(t); res(take()); });
  });
}

// Message clair quand Supabase refuse faute de captcha valide.
export const captchaError = err => /captcha/i.test(err?.message || '')
  ? 'La vérification anti-robot n’a pas abouti : rechargez la page et réessayez.' : '';
