// Remplacez par les valeurs de Supabase > Project Settings > API.
// La clé "anon" est publique par conception (la sécurité repose sur RLS). Ne mettez JAMAIS la clé service_role ici.
export const SUPABASE_URL = 'https://wxdmdvxmxhoijfyshyyg.supabase.co';
export const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind4ZG1kdnhteGhvaWpmeXNoeXlnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMwNTI4NzEsImV4cCI6MjEwODYyODg3MX0.rK0Off0QoFTEQ50lPjaddX8aU9NaP4IWMqDQqYuflKw';
// Adresse e-mail de contact (redirigée chez OVH vers la boîte Gmail de l’administration ; expéditeur des e-mails du site via Brevo).
export const CONTACT_EMAIL = 'contact@lesreinesboutique.com';
// Numéro WhatsApp affiché sur la page Contact (format international sans +).
export const CONTACT_WHATSAPP = '221775921070';
// Clé publique (« site key ») du captcha Cloudflare Turnstile. Vide = pas de captcha. La clé secrète va dans Supabase.
// Ne pas activer « Captcha protection » dans Supabase tant que cette clé n’est pas en ligne.
export const TURNSTILE_SITE_KEY = '';
// true : affiche des exemples (comme l'aperçu) tant qu'il n'y a aucun produit ni boutique. Mettre false pour les masquer.
export const DEMO_WHEN_EMPTY = false;
// Clé publique des notifications push (VAPID). La clé privée correspondante est le secret VAPID_PRIVATE_KEY de la fonction notify-order.
export const VAPID_PUBLIC_KEY = 'BCnBzMzHw_s0nU_oKyFkUiXYo6OaoIN_xv70TQvuMLmO4pdILB9DY1fOYQnOwHKsccHmYX-7G0-j5pP093Ca1rE';
