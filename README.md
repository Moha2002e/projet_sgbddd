# Projet Base de Données Distribuées - Gestion de Ventes de Jeux Vidéo

## Structure du Projet

### 01_setup - Configuration Initiale
Configuration de la table externe pour importer les données depuis le fichier `ventes_games.txt`.

**Ce qui est fait:**
- Création du répertoire Oracle `VENTES_DIR` pointant vers `/home/oracle/Documents`
- Création de la table externe `VENTES_EXT` qui lit directement le fichier texte
- Les données sont accessibles sans import classique

**Utilisation:**
```sql
@01_setup/01_setup_complet.sql
```

### 02_normalization - Normalisation des Données
Transformation des données brutes en modèle relationnel normalisé.

**Tables créées:**
- `CLIENTS` - Informations clients (ID, nom, prénom, email)
- `MAGASINS` - Données des magasins (ID, nom, code postal)
- `ARTICLES` - Catalogue des jeux (ID, libellé, console)
- `VENTES` - En-têtes de ventes (ID vente, client, magasin, date, ticket)
- `LIGNES_VENTES` - Détails des achats (article, prix, quantité)

**Processus:**
- Extraction et dédoublonnage des entités
- Décomposition de la colonne `ListeAchats` avec REGEXP
- Création des relations et contraintes d'intégrité

**Utilisation:**
```sql
@02_normalization/01_normalization_complet.sql
```

### 03_blobs - Gestion des Images
Ajout de la colonne BLOB pour stocker les tickets de caisse en format image.

**Ce qui est fait:**
- Création du répertoire `BLOBS_DIR` pointant vers `/tmp`
- Ajout de la colonne `TICKET_BLOB` dans la table `VENTES`
- Chargement d'une image depuis `ticket.jpg`
- Copie du BLOB dans toutes les ventes

**Prérequis:**
```bash
cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg
```

**Utilisation:**
```sql
@03_blobs/01_blobs_complet.sql
```

### 04_fragmentation - Fragmentation Horizontale
Répartition des données sur deux bases selon le code postal du magasin.

**Répartition:**
- **DB1 (projetBD1)** - Magasins avec CP entre 0 et 4999
- **DB2 (projetBD2)** - Magasins avec CP entre 5000 et 9999

**Tables fragmentées:**
- `DB1_CLIENTS` / `DB2_CLIENTS` - Réplication complète
- `DB1_ARTICLES` / `DB2_ARTICLES` - Réplication complète
- `DB1_MAGASINS` / `DB2_MAGASINS` - Fragmentation par CP
- `DB1_VENTES` / `DB2_VENTES` - Distribution selon le magasin
- `DB1_LIGNES_VENTES` / `DB2_LIGNES_VENTES` - Distribution des détails

**Utilisation:**
```sql
-- Sur projetBD1
@04_fragmentation/01_fragmentation_db1.sql

-- Sur projetBD2
@04_fragmentation/02_fragmentation_db2.sql
```

### 05_ords - API REST
Création d'un service REST avec Oracle REST Data Services.

**Endpoints créés:**
- `GET /ventes/:idVente` - Récupère les détails d'une vente
  - Retourne: infos client, magasin, articles achetés, montant total, image ticket en base64

**URL de base:**
```
http://192.168.0.18:8080/ords/gamestore/ventes/
```

**Exemple:**
```bash
curl http://192.168.0.18:8080/ords/gamestore/ventes/1
```

**Utilisation:**
```sql
@05_ords/01_ords_complet.sql
```

**Test avec Postman:**
- Importer la collection `Postman_ORDS_Tests.json`

### 06_job - Automatisation
Création d'un job planifié pour synchroniser les statistiques vers un entrepôt de données.

**Composants:**
- **Table `STATS_LOG`** - Stockage des stats (ID, date, total ventes du jour)
- **Database Link `DBL_ENTREPOT`** - Connexion vers l'entrepôt distant
- **Procédure `MAJ_STATS`** - Calcule le CA du jour et l'envoie via le DBLink
- **Job `JOB_STATS`** - Exécution quotidienne à 3h du matin

**Processus:**
1. Calcul du total des ventes du jour en cours
2. Envoi vers l'entrepôt via Database Link
3. Enregistrement dans `STATS_LOG@DBL_ENTREPOT`

**Utilisation:**
```sql
@06_job/01_job_complet.sql
```

**Tests manuels:**
```sql
-- Exécuter la procédure
EXEC MAJ_STATS;

-- Forcer l'exécution du job
BEGIN
    DBMS_SCHEDULER.RUN_JOB('JOB_STATS');
END;
/

-- Vérifier les logs
SELECT * FROM STATS_LOG@DBL_ENTREPOT ORDER BY DateLog DESC;
```

## Ordre d'Exécution Recommandé

1. **Setup** - `01_setup/01_setup_complet.sql`
2. **Normalisation** - `02_normalization/01_normalization_complet.sql`
3. **BLOBs** - `03_blobs/01_blobs_complet.sql`
4. **Fragmentation DB1** - `04_fragmentation/01_fragmentation_db1.sql`
5. **Fragmentation DB2** - `04_fragmentation/02_fragmentation_db2.sql` (sur projetBD2)
6. **ORDS** - `05_ords/01_ords_complet.sql`
7. **Job** - `06_job/01_job_complet.sql`

## Prérequis Techniques

- Oracle Database 19c ou supérieur
- SQLcl ou SQL*Plus
- ORDS installé et configuré
- Accès à deux schémas: `projetBD1` et `projetBD2`
- Fichier source: `ventes_games.txt` dans `/home/oracle/Documents`
- Fichier image: `ticket.jpg` à copier dans `/tmp`

## Configuration Réseau

- **IP du serveur:** 192.168.0.18
- **Port ORDS:** 8080
- **SID Oracle:** orcl
- **Port Oracle:** 1521

## Notes Importantes

- Les Database Links nécessitent des privilèges appropriés
- Le job quotidien ne fait pas planter le système si le DBLink est HS
- La fragmentation suppose une répartition équitable des codes postaux
- Les BLOBs peuvent augmenter significativement la taille de la base
