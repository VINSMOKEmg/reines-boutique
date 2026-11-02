# Modèles d'e-mails (Supabase Auth)

À coller dans Supabase > Authentication > Emails > Templates : pour chaque modèle, remplacer l'objet et tout le contenu
(onglet « Source ») par ceux ci-dessous. Les `{{ .ConfirmationURL }}`, `{{ .Email }}`, `{{ .NewEmail }}` sont remplis par Supabase.
Le logo est chargé depuis le site : https://www.lesreinesboutique.com/assets/logo.png

| Modèle Supabase      | Fichier                          | Objet |
|----------------------|----------------------------------|-------|
| Confirm signup       | `confirmation-inscription.html`  | Confirmez votre inscription — Les Reines de l'Entrepreneuriat |
| Reset password       | `mot-de-passe-oublie.html`       | Votre nouveau mot de passe — Les Reines de l'Entrepreneuriat |
| Change email address | `changement-adresse.html`        | Confirmez votre nouvelle adresse — Les Reines de l'Entrepreneuriat |

Expéditeur (Authentication > Emails > SMTP Settings, via Brevo) :
nom « Les Reines de l'Entrepreneuriat », adresse `contact@lesreinesboutique.com` (redirigée chez OVH vers la boîte Gmail).
