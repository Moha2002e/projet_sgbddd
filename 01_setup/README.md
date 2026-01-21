# Setup - Configuration Initiale

## Objectif
Créer une table externe Oracle pour accéder aux données du fichier texte `ventes_games.txt` sans avoir à l'importer dans une table classique.

## Fonctionnement

### 1. Création du répertoire Oracle
```sql
CREATE DIRECTORY VENTES_DIR AS '/home/oracle/Documents';
```
Le répertoire permet à Oracle d'accéder au système de fichiers.

### 2. Table externe VENTES_EXT
La table est définie mais ne stocke pas les données. Elle pointe directement vers le fichier texte.

**Structure:**
- IdVente, IdClient, NomClient, PrenomClient, EmailClient
- IdMagasin, NomMagasin, CodePostalMagasin
- ListeAchats (articles séparés par &)
- DateAchat, URLTicket

**Format du fichier:**
- Délimiteur: `;`
- Encodage: UTF8
- Une ligne par vente

### 3. Vérification
Le script compte automatiquement les lignes trouvées dans le fichier.

## Prérequis
- Le fichier `ventes_games.txt` doit être dans `/home/oracle/Documents`
- Droits de lecture sur le fichier
- Privilège `CREATE ANY DIRECTORY`

## Exécution
```sql
@01_setup_complet.sql
```

## Résultat Attendu
- Répertoire VENTES_DIR créé
- Table externe VENTES_EXT accessible
- Message affichant le nombre de lignes lues

## En Cas d'Erreur
- Vérifier que le fichier existe bien dans le répertoire
- Vérifier les permissions de lecture
- S'assurer que le chemin est correct (pas de lien symbolique)
