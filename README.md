# Les Reines de l’Entrepreneuriat — boutique collective

HTML5 / CSS3 / JavaScript natif (modules ES) + Supabase (Auth, PostgreSQL, Storage, RLS). Aucun framework.

## Arborescence
```
index.html                  accueil
404.html                    page introuvable (reste à la racine pour l’hébergeur)
boutique/   catalogue.html  produit.html  vendeuses.html  vendeuse.html (une boutique)  panier.html
compte/     connexion.html  inscription.html  client.html (espace cliente)
vendeuse/   dashboard.html  mes-commandes.html  mes-produits.html  ajouter-produit.html  modifier-produit.html  profil-boutique.html
admin/      index.html (administration, une section par ancre : #commandes, #membres…)
infos/      apropos.html  contact.html
css/style.css
js/         config.js  supabase.js  cart.js  ui.js  demo.js
assets/     logo.png (256 px : en-têtes, onglet)  logo-grand.png (1080 px : impression, réseaux)  hero.jpg  placeholder.svg
supabase/   schema.sql  migrations/
```
Les pages rangées dans un dossier commencent par `<base href="../">` : tous leurs liens s’écrivent depuis la racine du site (ex. `boutique/panier.html`, `assets/logo.png`). `404.html` utilise `<base href="/">`, car l’hébergeur l’affiche à n’importe quelle adresse.
`vendeuse/modifier-produit.html` redirige vers `vendeuse/ajouter-produit.html?id=…` (même formulaire pour ajouter et modifier).

## 1. Configurer Supabase
1. Créez un projet sur supabase.com.
2. **SQL Editor** : collez tout `supabase/schema.sql`, puis *Run*. Cela crée tables, index, triggers, politiques RLS, le bucket `shop-media` (JPG/PNG/WebP, 3 Mo max) et la fonction sécurisée `place_order`.
   **Base déjà créée avec une version précédente ?** N’exécutez pas `schema.sql` à nouveau : lancez dans l’ordre les scripts de `supabase/migrations/` (`001_…`, `002_…`, `003_…`), chacun une seule fois suffit.
3. **Authentication > Providers** : Email activé. **Laissez « Confirm email » activé** : c’est ce qui garantit que seules les membres de la liste deviennent vendeuses.
4. **Authentication > URL Configuration** : ajoutez l’URL locale puis l’URL de production dans *Redirect URLs*, avec `/**` à la fin (ex. `http://localhost:3000/**`, `https://votre-site.netlify.app/**`). Sans cela, le lien « Mot de passe oublié ? » ne ramène pas sur `connexion.html`.
   **Authentication > Email Templates > Reset Password** : vous pouvez traduire l’e-mail en français (gardez `{{ .ConfirmationURL }}`).
   **E-mails réels** : le service d’envoi intégré de Supabase est très limité (quelques e-mails par heure, et selon votre offre, uniquement vers les adresses de l’équipe du projet). Avant l’ouverture, configurez un SMTP dans **Project Settings > Authentication > SMTP Settings** (Brevo, Resend, Gmail…), sinon les e-mails de confirmation et de réinitialisation n’arriveront pas.
5. **Project Settings > API** : copiez *Project URL* et la clé *anon public* dans `js/config.js`, ainsi que `CONTACT_WHATSAPP` (numéro de la page Contact). N’utilisez jamais la clé `service_role` dans ce projet.

## 2. Lancer en local
Les modules ES exigent un serveur (pas de double-clic sur le fichier) :
- VS Code : extension **Live Server** > « Go Live », ou
- `npx serve .` dans le dossier du projet.

## 3. Premier administrateur
Créez un compte via `compte/inscription.html`, puis dans le SQL Editor :
`update profiles set role='admin' where id=(select id from auth.users where lower(email)=lower('votre@email.com'));`
(La recherche passe par `auth.users`, l'e-mail réel et vérifié, et non par la copie de `profiles`.)

## 4. Vendeuses : réservé aux membres du groupe
Le site appartient à un groupe : seules les membres peuvent vendre. Elles sont reconnues par leur **numéro WhatsApp**.
1. Dans `admin/` > **Membres du groupe**, l’admin ajoute le numéro WhatsApp de chaque membre (nom et e-mail facultatifs).
2. La membre crée son compte sur `compte/inscription.html` avec **ce même numéro** (et confirme son e-mail si la confirmation est activée).
3. Elle apparaît **« À valider »** dans l’admin (et dans « À traiter » du tableau de bord). Le numéro saisi à l’inscription n’étant pas vérifié par SMS, l’admin s’assure que c’est bien elle (par exemple sur WhatsApp), puis clique **Activer** : sa boutique est créée avec ce numéro comme WhatsApp.
4. Elle se connecte ensuite avec **son numéro (ou son e-mail) et son mot de passe**. Elle gère seule son logo, son WhatsApp et ses produits (publiés immédiatement).
Un compte hors liste reste cliente. Si plusieurs comptes utilisent le numéro d’une membre, l’admin les voit tous et n’active que le bon. « Retirer » une membre suspend sa boutique ; l’ajouter de nouveau la réactive.
La connexion par numéro est réservée aux vendeuses validées ; les clientes se connectent avec leur e-mail.
L’admin peut modifier toute boutique ou tout produit, désactiver ou supprimer un produit, suspendre ou réactiver une boutique, et gérer les niches.

## 5. Parcours de commande
Carte produit : **Commander** (ajoute et ouvre le panier) ou **Ajouter au panier**. Dans le panier, **Valider ma commande** enregistre la commande côté serveur (prix relus en base), la regroupe par vendeuse, puis affiche un bouton WhatsApp par vendeuse avec le message prérempli et la référence `CMD-XXXXXX-n`. La cliente envoie elle-même le message.

## 6. Publier
Site 100 % statique : Netlify, Vercel, Cloudflare Pages ou GitHub Pages (déposer le dossier). Ajoutez l’URL finale dans Supabase > Authentication > URL Configuration.

## 7. Checklist de tests (2 vendeuses A et B, 2 clientes C1 et C2)
- [ ] Inscription C1 : rôle `client`, accès à `compte/client.html` ; en ouvrant `vendeuse/dashboard.html` ou `admin/`, elle est renvoyée vers son espace.
- [ ] Console navigateur : `sb.from('profiles').update({role:'admin'})` est refusé (trigger + RLS).
- [ ] Console navigateur : `sb.from('profiles').update({email:'autre@mail.com'}).eq('id', monId)` est refusé (permission denied).
- [ ] Inscription avec « 77 123 45 67 » : `profiles.phone` vaut `221771234567` ; une membre inscrite ainsi a ce numéro comme WhatsApp de boutique dès sa première connexion.
- [ ] « Mot de passe oublié ? » : l’e-mail arrive, le lien ouvre le formulaire « Nouveau mot de passe », la connexion fonctionne ensuite avec le nouveau mot de passe ; un lien déjà utilisé affiche « lien expiré ».
- [ ] A et B ajoutées aux membres par l’admin, inscrites avec cet e-mail et confirmées : boutiques actives à la connexion.
- [ ] Un compte hors liste ne devient jamais vendeuse (essayer aussi `sb.rpc('claim_membership')` depuis la console).
- [ ] Membre ajoutée par numéro, inscrite avec ce numéro : « À valider » dans l’admin, aucune boutique avant le clic sur « Activer » ; ensuite connexion possible avec le numéro + mot de passe.
- [ ] Une cliente ne peut pas se connecter avec son numéro (message « pas encore celui d’une vendeuse validée »).
- [ ] A crée un produit : visible aussitôt au catalogue ; l’admin le désactive, A ne peut pas le réactiver.
- [ ] B ne voit ni ne modifie les produits de A (essayer un `update` sur un id de A : 0 ligne).
- [ ] A envoie une image > 3 Mo ou un PDF : refusé. A écrit dans le dossier de B : refusé.
- [ ] Panier avec produits de A et B : deux boutons WhatsApp, bons numéros, bon message.
- [ ] Modifier le prix dans le panier (localStorage) : le total enregistré reste le vrai prix.
- [ ] C1 ne voit pas les commandes de C2 ; A ne voit que ses demandes.
- [ ] Suspension de A par l’admin : ses produits disparaissent du catalogue.

## Limites de cette version
Pas de variantes (tailles/couleurs), de signalements, de textes de page d’accueil modifiables depuis l’admin ni de notifications ; stock affiché sans décrément automatique. À ajouter ensuite.
