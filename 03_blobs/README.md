# BLOBs - Gestion des Images

## Objectif
Stocker les images des tickets de caisse sous forme de BLOB dans la table VENTES.

## Pourquoi des BLOBs?
- Permet de stocker l'image complète du ticket
- Pas de dépendance à un système de fichiers externe
- Images exportables via API REST (base64)
- Cohérence des données garantie

## Processus

### Étape 1: Préparation du Fichier
```bash
cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg
```
Oracle nécessite que le fichier soit dans un répertoire accessible.
`/tmp` est utilisé car c'est un répertoire système sans lien symbolique.

### Étape 2: Création du Répertoire Oracle
```sql
CREATE OR REPLACE DIRECTORY BLOBS_DIR AS '/tmp';
```

### Étape 3: Ajout de la Colonne BLOB
```sql
ALTER TABLE VENTES ADD TICKET_BLOB BLOB;
```
Ajout d'une colonne de type BLOB à la table VENTES existante.

### Étape 4: Chargement de l'Image

**BFILENAME**
```sql
BFILENAME('BLOBS_DIR', 'ticket.jpg')
```
Crée un pointeur vers le fichier externe.

**DBMS_LOB.LOADFROMFILE**
```sql
DBMS_LOB.LOADFROMFILE(
    dest_lob => blob_temp,
    src_lob => bfile_img,
    amount => DBMS_LOB.GETLENGTH(bfile_img)
);
```
Charge le contenu du fichier dans un BLOB temporaire.

### Étape 5: Copie dans Toutes les Ventes
```sql
UPDATE VENTES SET TICKET_BLOB = blob_temp;
```
Toutes les ventes reçoivent la même image (pour la démo).

## Structure de la Table VENTES Après
```
VENTES
├── IdVente (PK)
├── IdClient (FK)
├── IdMagasin (FK)
├── DateAchat
├── URLTicket
└── TICKET_BLOB (BLOB) ← Nouveau
```

## Manipulation des BLOBs

**Taille d'un BLOB:**
```sql
SELECT DBMS_LOB.GETLENGTH(TICKET_BLOB) FROM VENTES WHERE IdVente = 1;
```

**Conversion en Base64 (pour API):**
```sql
SELECT APEX_WEB_SERVICE.BLOB2CLOBBASE64(TICKET_BLOB) FROM VENTES WHERE IdVente = 1;
```

**Export vers fichier:**
```sql
-- Utiliser UTL_FILE ou un client externe
```

## Prérequis
- Fichier `ticket.jpg` dans `/tmp`
- Format: JPEG, PNG, ou autre format image
- Droits de lecture sur `/tmp`
- Table VENTES déjà créée

## Exécution
```sql
@01_blobs_complet.sql
```

## Vérification
Le script affiche:
- Taille de l'image chargée (en octets)
- Nombre de ventes avec BLOB
- Requête récapitulative (total, avec BLOB, taille)

## Attention
- Les BLOBs augmentent significativement la taille de la base
- Pour une vraie application: 1 image = 1 vente (pas de duplication)
- Les backups incluent les BLOBs
