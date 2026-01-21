# Fragmentation - Distribution des Données

## Objectif
Répartir les données sur deux bases de données distinctes selon le code postal des magasins.

## Principe de la Fragmentation Horizontale

**Critère de fragmentation:** Code postal du magasin

- **DB1 (projetBD1):** Magasins avec CP 0 à 4999
- **DB2 (projetBD2):** Magasins avec CP 5000 à 9999

## Stratégie de Distribution

### Tables Répliquées (identiques sur les 2 bases)
```
DB1_CLIENTS = DB2_CLIENTS (tous les clients)
DB1_ARTICLES = DB2_ARTICLES (tous les articles)
```
**Pourquoi?** Les clients peuvent acheter partout, les articles sont les mêmes.

### Tables Fragmentées (données différentes)
```
DB1_MAGASINS: CP 0-4999
DB2_MAGASINS: CP 5000-9999

DB1_VENTES: Ventes des magasins CP 0-4999
DB2_VENTES: Ventes des magasins CP 5000-9999

DB1_LIGNES_VENTES: Détails ventes CP 0-4999
DB2_LIGNES_VENTES: Détails ventes CP 5000-9999
```

## Architecture

```
┌─────────────────────────┐     ┌─────────────────────────┐
│   BASE projetBD1        │     │   BASE projetBD2        │
│  (Code Postal 0-4999)   │     │  (Code Postal 5000-9999)│
├─────────────────────────┤     ├─────────────────────────┤
│ DB1_CLIENTS (répliqué)  │     │ DB2_CLIENTS (répliqué)  │
│ DB1_ARTICLES (répliqué) │     │ DB2_ARTICLES (répliqué) │
│ DB1_MAGASINS (fragment) │     │ DB2_MAGASINS (fragment) │
│ DB1_VENTES (fragment)   │     │ DB2_VENTES (fragment)   │
│ DB1_LIGNES_VENTES (frag)│     │ DB2_LIGNES_VENTES (frag)│
└─────────────────────────┘     └─────────────────────────┘
```

## Processus de Fragmentation

### Sur projetBD1 (01_fragmentation_db1.sql)

**1. Nettoyage**
```sql
DROP TABLE DB1_* CASCADE CONSTRAINTS;
```

**2. Création des Structures**
Tables DB1_* avec mêmes contraintes que l'original.

**3. Réplication Complète**
```sql
INSERT INTO DB1_CLIENTS SELECT * FROM projetBD1.CLIENTS;
INSERT INTO DB1_ARTICLES SELECT * FROM projetBD1.ARTICLES;
```

**4. Fragmentation par CP**
```sql
INSERT INTO DB1_MAGASINS 
SELECT * FROM projetBD1.MAGASINS 
WHERE CodePostalMagasin >= 0 AND CodePostalMagasin <= 4999;

INSERT INTO DB1_VENTES 
SELECT v.*
FROM projetBD1.VENTES v
JOIN projetBD1.MAGASINS m ON v.IdMagasin = m.IdMagasin
WHERE m.CodePostalMagasin >= 0 AND CodePostalMagasin <= 4999;
```

**5. Contraintes**
- Clés primaires sur toutes les tables
- Clés étrangères internes au fragment
- CHECK CONSTRAINT sur CodePostalMagasin (0-4999)

### Sur projetBD2 (02_fragmentation_db2.sql)
Même processus mais avec CP 5000-9999.

## Avantages de cette Fragmentation

**Performance:**
- Moins de données par base
- Requêtes plus rapides (moins de lignes à scanner)

**Scalabilité:**
- Chaque base peut être sur un serveur différent
- Charge répartie

**Maintenance:**
- Backups plus petits et plus rapides
- Possibilité de maintenance indépendante

**Géographique:**
- DB1 pourrait être en France Nord
- DB2 pourrait être en France Sud

## Requêtes Distribuées

Pour interroger les deux fragments:
```sql
SELECT * FROM DB1_VENTES
UNION ALL
SELECT * FROM DB2_VENTES@DB_LINK_TO_DB2;
```

## Exécution

**Sur projetBD1:**
```sql
@01_fragmentation_db1.sql
```

**Sur projetBD2:**
```sql
@02_fragmentation_db2.sql
```

## Vérification

Chaque script affiche:
- Nombre de clients (identique sur les 2)
- Nombre d'articles (identique sur les 2)
- Nombre de magasins (différent)
- Nombre de ventes (différent)
- Nombre de lignes de vente (différent)

## Notes Importantes

- Les contraintes CHECK garantissent qu'aucune donnée ne peut être insérée dans le mauvais fragment
- La réplication complète facilite les jointures locales
- Pour une vraie application distribuée: utiliser des Database Links
- Les BLOBs sont aussi répliqués (attention à la taille)
