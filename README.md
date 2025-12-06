# Projet GameStoreDB - Base de Données Avancée

Ce projet met en œuvre une architecture de base de données Oracle complète et avancée pour la gestion d'une chaîne de magasins de jeux vidéo ("GameStore").

Il a été réalisé dans le cadre du cours de Base de Données Avancées (méthodologie Mme Serrhini) et couvre des concepts clés tels que les tables externes, la normalisation BCNF, la gestion des objets binaires (BLOBs), la fragmentation de données (base distribuée), les services RESTful (ORDS) et l'automatisation par Jobs.

## 📂 Structure du Projet

Le projet est divisé en 6 étapes séquentielles, chacune contenue dans son propre dossier :

| Dossier | Description |
|---------|-------------|
| `01_setup` | **Intégration** : Création du répertoire Oracle et de la table externe `VENTES_EXT` pour lire les données brutes depuis un fichier texte. |
| `02_normalization` | **Normalisation** : Nettoyage et transformation des données brutes en un modèle relationnel normalisé (BCNF) composé de tables internes (`CLIENTS`, `MAGASINS`, `ARTICLES`, `VENTES`, `LIGNES_VENTES`). |
| `03_blobs` | **Multimédia** : Ajout et gestion d'une colonne `BLOB` pour stocker les images des tickets de caisse. |
| `04_fragmentation` | **Distribution** : Simulation d'une architecture distribuée. <br> - **Réplication** : Tables `CLIENTS` et `ARTICLES` copiées sur tous les nœuds.<br> - **Fragmentation** : Tables `MAGASINS` et `VENTES` divisées selon le code postal (DB1 < 5000, DB2 >= 5000). |
| `05_ords` | **API REST** : Configuration des services ORDS pour exposer les données. <br> - `GET`: Consultation d'une vente.<br> - `POST`: Mise à jour d'un magasin avec gestion automatique de la re-fragmentation des données. |
| `06_job` | **Automatisation** : Mise en place d'un Job planifié (`DBMS_SCHEDULER`) pour l'agrégation quotidienne des ventes dans un mini-entrepôt de données (`STATS_LOG`). |

## 🚀 Installation et Démarrage

Les scripts doivent être exécutés dans l'ordre numérique strict pour garantir la cohérence des dépendances.

1.  **Prérequis** :
    *   Oracle Database (12c, 19c, 21c ou 23ai).
    *   ORDS (Oracle REST Data Services) activé et configuré.
    *   Accès au dossier `/home/oracle/Documents` (ou adapter le chemin dans `01_setup`) pour le fichier source.

2.  **Exécution** :
    *   Connectez-vous à votre schéma utilisateur.
    *   Exécutez les fichiers `.sql` de chaque dossier dans l'ordre :
        1.  `01_setup/01_setup_complet.sql`
        2.  `02_normalization/01_normalization_complet.sql`
        3.  `03_blobs/01_blobs_complet.sql`
        4.  `04_fragmentation/02_fragmentation_db2.sql` (Note : assurez-vous que la DB1 est aussi gérée si applicable, ici l'exemple focuse sur DB2 et la logique de fragmentation)
        5.  `05_ords/01_ords_complet.sql`
        6.  `06_job/01_job_complet.sql`

## 🛠 Détails Techniques

### 1. Tables Externes
Utilisation de `ORGANIZATION EXTERNAL` pour mapper le fichier plat `ventes_games.txt` directement en table SQL, facilitant l'ETL initial.

### 2. Normalisation
Utilisation intensive de **Expressions Régulières (Regex)** pour parser la colonne complexe contenant la liste des achats (format `id.libelle.prix.qte.console&...`) et éclater ces données en tuples atomiques pour la table `LIGNES_VENTES`.

### 3. API REST (ORDS)
*   **EndPoint GET** `/ventes/{idVente}` : Retourne un JSON complet de la vente.
*   **EndPoint POST** `/ventes/updateMagasin` : Reçoit un JSON `{idMagasin, newCodePostal}`.
    *   *Logique métier complexe* : Si le changement de code postal fait passer le magasin d'une zone de fragmentation à une autre (ex: 4000 -> 6000), le script PL/SQL déplace automatiquement le magasin et toutes ses ventes associées de la table virtuelle DB1 vers DB2 (et inversement).

### 4. Automatisation
Le Job `JOB_STATS` est programmé pour tourner tous les jours à 03h00 `FREQ=DAILY; BYHOUR=3` afin de ne pas impacter les performances en journée.

---
*Projet réalisé dans le cadre du cours de Base de Données Avancées.*
