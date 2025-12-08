# Projet GameStoreDB - Base de Données Avancée

Ce projet met en œuvre une architecture de base de données Oracle complète et avancée pour la gestion d'une chaîne de magasins de jeux vidéo ("GameStore").

Il a été réalisé dans le cadre du cours de Base de Données Avancées (méthodologie Mme Serrhini) et couvre des concepts clés tels que les tables externes, la normalisation BCNF, la gestion des objets binaires (BLOBs), la fragmentation de données (base distribuée), les services RESTful (ORDS) et l'automatisation par Jobs.

## 📂 Structure du Projet

Le projet est divisé en 6 étapes séquentielles, chacune contenue dans son propre dossier :

| Dossier | Description |
|---------|-------------|
| `01_setup` | **Intégration** : Création du répertoire Oracle et de la table externe `VENTES_EXT` pour lire les données brutes depuis un fichier texte. |
| `02_normalization` | **Normalisation** : Nettoyage et transformation des données brutes en un modèle relationnel normalisé (BCNF) composé de tables internes (`CLIENTS`, `MAGASINS`, `ARTICLES`, `VENTES`, `LIGNES_VENTES`). |
| `03_blobs` | **Multimédia** : Ajout et gestion d'une colonne `BLOB` pour stocker les images des tickets de caisse. Utilise `BFILENAME` et `DBMS_LOB.LOADFROMFILE` pour charger les images depuis le système de fichiers. |
| `04_fragmentation` | **Distribution** : Simulation d'une architecture distribuée. <br> - **Réplication** : Tables `CLIENTS` et `ARTICLES` copiées sur tous les nœuds.<br> - **Fragmentation** : Tables `MAGASINS` et `VENTES` divisées selon le code postal (DB1 < 5000, DB2 >= 5000). |
| `05_ords` | **API REST** : Configuration des services ORDS pour exposer les données. <br> - `GET`: Consultation d'une vente.<br> - `POST`: Mise à jour d'un magasin avec gestion automatique de la re-fragmentation des données. |
| `06_job` | **Automatisation** : Mise en place d'un Job planifié (`DBMS_SCHEDULER`) pour l'agrégation quotidienne des ventes dans un mini-entrepôt de données (`STATS_LOG`). |

## 🚀 Installation et Démarrage

Les scripts doivent être exécutés dans l'ordre numérique strict pour garantir la cohérence des dépendances.

### Prérequis

*   Oracle Database (12c, 19c, 21c ou 23ai).
*   ORDS (Oracle REST Data Services) activé et configuré.
*   Accès au dossier `/home/oracle/Documents` pour le fichier source `ventes_games.txt`.
*   Fichier image `ticket.jpg` dans `/home/oracle/Documents` (pour l'étape 3).

### Exécution

1. **Connectez-vous à votre schéma utilisateur Oracle** (SQL*Plus, SQL Developer, ou autre client).

2. **Exécutez les fichiers `.sql` de chaque dossier dans l'ordre strict** :

   ```sql
   -- Étape 1 : Intégration
   @01_setup/01_setup_complet.sql
   
   -- Étape 2 : Normalisation
   @02_normalization/01_normalization_complet.sql
   
   -- Étape 3 : Gestion des BLOBs
   -- IMPORTANT : Voir les instructions spécifiques ci-dessous
   @03_blobs/01_blobs_complet.sql
   
   -- Étape 4 : Fragmentation
   @04_fragmentation/02_fragmentation_db2.sql
   
   -- Étape 5 : API REST (ORDS)
   @05_ords/01_ords_complet.sql
   
   -- Étape 6 : Automatisation
   @06_job/01_job_complet.sql
   ```

### Instructions Spécifiques pour l'Étape 3 (BLOBs)

**⚠️ IMPORTANT** : Oracle refuse les chemins contenant des liens symboliques pour des raisons de sécurité. Le script utilise `/tmp` comme répertoire Oracle car c'est un répertoire système réel sans liens symboliques.

**Avant d'exécuter `03_blobs/01_blobs_complet.sql`** :

1. Assurez-vous que le fichier `ticket.jpg` existe dans `/home/oracle/Documents/`
2. Copiez le fichier dans `/tmp` (répertoire sans lien symbolique) :

   ```bash
   cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg
   ```

3. Vérifiez que le fichier est bien présent :

   ```bash
   ls -lh /tmp/ticket.jpg
   ```

4. Exécutez ensuite le script SQL. Le script créera automatiquement le répertoire Oracle `BLOBS_DIR` pointant vers `/tmp` et chargera l'image dans toutes les ventes.

## 🛠 Détails Techniques

### 1. Tables Externes
Utilisation de `ORGANIZATION EXTERNAL` pour mapper le fichier plat `ventes_games.txt` directement en table SQL, facilitant l'ETL initial. Le fichier doit être accessible depuis Oracle via un répertoire DIRECTORY.

### 2. Normalisation
Utilisation intensive de **Expressions Régulières (Regex)** pour parser la colonne complexe contenant la liste des achats (format `id.libelle.prix.qte.console&...`) et éclater ces données en tuples atomiques pour la table `LIGNES_VENTES`. Le modèle résultant respecte la forme normale BCNF (Boyce-Codd Normal Form).

### 3. Gestion des BLOBs
*   **Colonne `TICKET_BLOB`** : Ajoutée à la table `VENTES` pour stocker les images de tickets au format BLOB.
*   **Chargement** : Utilisation de `BFILENAME` et `DBMS_LOB.LOADFROMFILE` pour charger les fichiers binaires depuis le système de fichiers.
*   **Répertoire Oracle** : Création automatique du DIRECTORY `BLOBS_DIR` pointant vers `/tmp` (répertoire sans lien symbolique).
*   **Contrainte** : Oracle refuse les chemins contenant des liens symboliques (`ORA-22288: soft link in path`). La solution est d'utiliser un répertoire système réel comme `/tmp`, `/etc`, ou `/opt`.

### 4. Fragmentation et Distribution
*   **Réplication** : Les tables `CLIENTS` et `ARTICLES` sont répliquées sur tous les nœuds (DB1 et DB2) car elles sont fréquemment consultées.
*   **Fragmentation horizontale** : Les tables `MAGASINS` et `VENTES` sont fragmentées selon le code postal :
    *   **DB1** : Code postal < 5000
    *   **DB2** : Code postal >= 5000
*   **Vues distribuées** : Utilisation de vues pour masquer la fragmentation et permettre des requêtes transparentes.

### 5. API REST (ORDS)
*   **EndPoint GET** `/ventes/{idVente}` : Retourne un JSON complet de la vente avec toutes les informations associées (client, magasin, articles, lignes de vente).
*   **EndPoint POST** `/ventes/updateMagasin` : Reçoit un JSON `{idMagasin, newCodePostal}`.
    *   *Logique métier complexe* : Si le changement de code postal fait passer le magasin d'une zone de fragmentation à une autre (ex: 4000 -> 6000), le script PL/SQL déplace automatiquement le magasin et toutes ses ventes associées de la table virtuelle DB1 vers DB2 (et inversement).
    *   Cette fonctionnalité garantit la cohérence des données après un changement de code postal.

### 6. Automatisation
Le Job `JOB_STATS` est programmé pour tourner tous les jours à 03h00 (`FREQ=DAILY; BYHOUR=3`) afin de ne pas impacter les performances en journée. Il agrège les statistiques de ventes dans la table `STATS_LOG` (mini-entrepôt de données).

## ⚠️ Problèmes Courants et Solutions

### Erreur ORA-22288 : "soft link in path"
**Problème** : Oracle refuse d'accéder aux fichiers dans des répertoires contenant des liens symboliques.

**Solution** : Utilisez un répertoire système réel sans liens symboliques :
*   `/tmp` (recommandé, accessible sans sudo)
*   `/etc` (nécessite sudo pour copier le fichier)
*   `/opt` (si accessible)

Le script `03_blobs/01_blobs_complet.sql` utilise automatiquement `/tmp`.

### Fichier introuvable lors du chargement du BLOB
**Problème** : Le fichier `ticket.jpg` n'est pas trouvé par Oracle.

**Solutions** :
1. Vérifiez que le fichier existe dans le répertoire spécifié : `ls -lh /tmp/ticket.jpg`
2. Vérifiez les permissions : `chmod 644 /tmp/ticket.jpg`
3. Vérifiez que le DIRECTORY Oracle pointe vers le bon répertoire :
   ```sql
   SELECT DIRECTORY_NAME, DIRECTORY_PATH FROM ALL_DIRECTORIES WHERE DIRECTORY_NAME = 'BLOBS_DIR';
   ```

### Erreur de privilèges CREATE DIRECTORY
**Problème** : Impossible de créer le répertoire Oracle DIRECTORY.

**Solution** : Demandez à l'administrateur de vous accorder le privilège `CREATE ANY DIRECTORY` ou de créer le DIRECTORY pour vous.

## 📊 Schéma de la Base de Données

### Tables Principales
*   **CLIENTS** : Informations sur les clients
*   **MAGASINS** : Informations sur les magasins (fragmentée par code postal)
*   **ARTICLES** : Catalogue des articles (jeux vidéo)
*   **VENTES** : En-têtes des ventes (contient le BLOB du ticket, fragmentée par code postal)
*   **LIGNES_VENTES** : Détails des lignes de vente (articles achetés)

### Tables de Support
*   **VENTES_EXT** : Table externe pour lire le fichier source
*   **STATS_LOG** : Mini-entrepôt de données pour les statistiques agrégées

## 📝 Notes Importantes

*   Tous les scripts sont idempotents : ils peuvent être exécutés plusieurs fois sans erreur.
*   Les scripts vérifient l'existence des objets avant de les créer.
*   L'ordre d'exécution est critique : chaque étape dépend des précédentes.
*   Le fichier `ticket.jpg` doit être une vraie image de ticket (même simpliste) pour permettre la visualisation lors de l'extraction du BLOB.

---
*Projet réalisé dans le cadre du cours de Base de Données Avancées.*
