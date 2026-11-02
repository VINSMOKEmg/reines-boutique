# Sauvegarde de la base Supabase

Chaque dimanche vers 2 h 30, GitHub exporte toute la base (structure, comptes, profils, boutiques, produits,
commandes, paniers) et toutes les photos, **chiffre** l'archive avec votre phrase secrète, puis la garde **90 jours**
(fichier `workflows/sauvegarde.yml`). Le dépôt étant public, rien n'est jamais enregistré en clair.

## Mise en place (une seule fois)

1. **Adresse de connexion à la base** : Supabase > bouton **Connect** (en haut) > **Session pooler** > copier l'adresse
   `postgresql://postgres.xxxx:[YOUR-PASSWORD]@aws-…pooler.supabase.com:5432/postgres` et remplacer `[YOUR-PASSWORD]`
   par le mot de passe de la base (oublié ? Supabase > Project Settings > Database > **Reset database password**).
   Prendre « Session pooler » et pas « Direct connection » : GitHub ne peut pas joindre cette dernière.
2. **Phrase secrète** : une phrase longue (12 caractères minimum), à noter dans un endroit sûr.
   **Sans elle, les sauvegardes sont illisibles, y compris pour vous.**
3. GitHub > dépôt > **Settings > Secrets and variables > Actions > New repository secret**, deux fois :
   - `SUPABASE_DB_URL` : l'adresse complète de l'étape 1 ;
   - `BACKUP_PASSPHRASE` : la phrase de l'étape 2.
4. GitHub > **Actions > Sauvegarde Supabase > Run workflow** pour faire une première sauvegarde tout de suite.

## Récupérer une sauvegarde

GitHub > **Actions > Sauvegarde Supabase** > choisir une exécution > en bas, **Artifacts** > télécharger
`reines-sauvegarde-AAAA-MM-JJ.tar.gz.gpg` (GitHub le livre dans un .zip : le décompresser d'abord).

Déchiffrer (Git Bash, installé avec Git) :

```sh
gpg -d reines-sauvegarde-AAAA-MM-JJ.tar.gz.gpg | tar xz
```

On obtient `sauvegarde/base/` (fichiers SQL) et `sauvegarde/photos/` (même arborescence que le stockage `shop-media`).

## Restaurer (en cas de perte)

Dans un projet Supabase vide, avec l'adresse « Session pooler » de ce projet :

```sh
psql "$NOUVELLE_ADRESSE" -f sauvegarde/base/1-roles.sql
psql "$NOUVELLE_ADRESSE" -f sauvegarde/base/2-structure.sql
psql "$NOUVELLE_ADRESSE" -c "SET session_replication_role = replica" -f sauvegarde/base/3-donnees.sql
```

Puis renvoyer les photos dans un bucket public `shop-media` en gardant les mêmes chemins, mettre la nouvelle adresse et
la nouvelle clé publique dans `js/config.js`, et refaire les réglages des tableaux de bord (SMTP Brevo, URL du site,
secret `VAPID_PRIVATE_KEY`, fonction `notify-order`). Voir la documentation Supabase « Backup and Restore using the CLI ».
