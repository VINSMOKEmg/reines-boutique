# Les Reines de l’Entrepreneuriat — boutique collective

HTML5 / CSS3 / JavaScript natif (modules ES) + Supabase (Auth, PostgreSQL, Storage, RLS). Aucun framework.

## Arborescence
```
index.html catalogue.html produit.html vendeuse.html panier.html connexion.html inscription.html client.html
dashboard.html profil-boutique.html mes-produits.html ajouter-produit.html modifier-produit.html admin.html apropos.html contact.html 404.html
css/style.css
js/ config.js  supabase.js  cart.js  ui.js
assets/ logo.jpg  placeholder.svg
supabase/schema.sql
```
`modifier-produit.html` redirige vers `ajouter-produit.html?id=…` (même formulaire pour ajouter et modifier).

## 1. Configurer Supabase
1. Créez un projet sur supabase.com.
2. **SQL Editor** : collez tout `supabase/schema.sql`, puis *Run*. Cela crée tables, index, triggers, politiques RLS, le bucket `shop-media` (JPG/PNG/WebP, 3 Mo max) et la fonction sécurisée `place_order`.
3. **Authentication > Providers** : Email activé. **Laissez « Confirm email » activé** : c’est ce qui garantit que seules les membres de la liste deviennent vendeuses.
4. **Authentication > URL Configuration** : ajoutez l’URL locale puis l’URL de production.
5. **Project Settings > API** : copiez *Project URL* et la clé *anon public* dans `js/config.js`, ainsi que `CONTACT_WHATSAPP` (numéro de la page Contact). N’utilisez jamais la clé `service_role` dans ce projet.

## 2. Lancer en local
Les modules ES exigent un serveur (pas de double-clic sur le fichier) :
- VS Code : extension **Live Server** > « Go Live », ou
- `npx serve .` dans le dossier du projet.

## 3. Premier administrateur
Créez un compte via `inscription.html`, puis dans le SQL Editor :
`update profiles set role='admin' where email='votre@email.com';`

## 4. Vendeuses : réservé aux membres du groupe
Le site appartient à un groupe : seules les membres peuvent vendre.
1. Dans `admin.html` > **Membres du groupe**, l’admin ajoute l’e-mail de chaque membre.
2. La membre crée son compte sur `inscription.html` avec cet e-mail et **confirme son e-mail**.
3. À sa connexion, elle devient vendeuse automatiquement et sa boutique est créée. Elle gère ensuite seule son logo, son WhatsApp et ses produits (publiés immédiatement), sans accord de l’admin.
Un compte dont l’e-mail n’est pas dans la liste reste cliente. « Retirer » une membre suspend sa boutique.
L’admin peut modifier toute boutique ou tout produit, désactiver ou supprimer un produit, suspendre ou réactiver une boutique, et gérer les niches.

## 5. Parcours de commande
Carte produit : **Commander** (ajoute et ouvre le panier) ou **Ajouter au panier**. Dans le panier, **Valider ma commande** enregistre la commande côté serveur (prix relus en base), la regroupe par vendeuse, puis affiche un bouton WhatsApp par vendeuse avec le message prérempli et la référence `CMD-XXXXXX-n`. La cliente envoie elle-même le message.

## 6. Publier
Site 100 % statique : Netlify, Vercel, Cloudflare Pages ou GitHub Pages (déposer le dossier). Ajoutez l’URL finale dans Supabase > Authentication > URL Configuration.

## 7. Checklist de tests (2 vendeuses A et B, 2 clientes C1 et C2)
- [ ] Inscription C1 : rôle `client`, accès à `client.html`, redirection refusée vers `dashboard.html` et `admin.html`.
- [ ] Console navigateur : `sb.from('profiles').update({role:'admin'})` est refusé (trigger + RLS).
- [ ] A et B ajoutées aux membres par l’admin, inscrites avec cet e-mail et confirmées : boutiques actives à la connexion.
- [ ] Un compte hors liste ne devient jamais vendeuse (essayer aussi `sb.rpc('claim_membership')` depuis la console).
- [ ] A crée un produit : visible aussitôt au catalogue ; l’admin le désactive, A ne peut pas le réactiver.
- [ ] B ne voit ni ne modifie les produits de A (essayer un `update` sur un id de A : 0 ligne).
- [ ] A envoie une image > 3 Mo ou un PDF : refusé. A écrit dans le dossier de B : refusé.
- [ ] Panier avec produits de A et B : deux boutons WhatsApp, bons numéros, bon message.
- [ ] Modifier le prix dans le panier (localStorage) : le total enregistré reste le vrai prix.
- [ ] C1 ne voit pas les commandes de C2 ; A ne voit que ses demandes.
- [ ] Suspension de A par l’admin : ses produits disparaissent du catalogue.

## Limites de cette version
Pas de variantes (tailles/couleurs), de signalements, de textes de page d’accueil modifiables depuis l’admin ni de notifications ; stock affiché sans décrément automatique. À ajouter ensuite.
