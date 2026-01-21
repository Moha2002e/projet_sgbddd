# Normalisation - Modèle Relationnel

## Objectif
Transformer les données brutes de la table externe en un modèle relationnel normalisé avec contraintes d'intégrité.

## Processus de Normalisation

### Étape 1: Nettoyage
Suppression des anciennes tables si elles existent (CLIENTS, MAGASINS, VENTES, ARTICLES, LIGNES_VENTES).

### Étape 2: Extraction des Entités

**CLIENTS**
```sql
SELECT DISTINCT IdClient, NomClient, PrenomClient, EmailClient
FROM VENTES_EXT
```
- Clé primaire: IdClient
- Dédoublonnage automatique

**MAGASINS**
```sql
SELECT DISTINCT IdMagasin, NomMagasin, CodePostalMagasin
FROM VENTES_EXT
```
- Clé primaire: IdMagasin

**VENTES**
```sql
SELECT IdVente, IdClient, IdMagasin, DateAchat, URLTicket
FROM VENTES_EXT
```
- Clé primaire: IdVente
- Clés étrangères vers CLIENTS et MAGASINS

### Étape 3: Décomposition des Articles

**Vue ARTICLES_DECOMPOSE**
La colonne `ListeAchats` contient plusieurs articles séparés par `&`.
Chaque article est au format: `IdArticle.Libelle.Prix.Quantite.Console`

Utilisation de REGEXP_SUBSTR pour:
1. Séparer les articles (délimiteur &)
2. Extraire chaque champ (délimiteur .)

**Table ARTICLES**
```sql
SELECT DISTINCT IdArticle, Libelle, Console
FROM ARTICLES_DECOMPOSE
```
- Clé primaire composite: (IdArticle, Console)
- Un même jeu peut exister sur plusieurs consoles

**Table LIGNES_VENTES**
Détails de chaque article acheté dans une vente:
- IdLigneVente (séquentiel auto-généré)
- IdVente (référence vers VENTES)
- IdArticle, Console (référence vers ARTICLES)
- Prix, Quantite

## Tables Créées

```
CLIENTS
├── IdClient (PK)
├── NomClient
├── PrenomClient
└── EmailClient

MAGASINS
├── IdMagasin (PK)
├── NomMagasin
└── CodePostalMagasin

ARTICLES
├── IdArticle (PK)
├── LibelleArticle
└── Console (PK)

VENTES
├── IdVente (PK)
├── IdClient (FK → CLIENTS)
├── IdMagasin (FK → MAGASINS)
├── DateAchat
└── URLTicket

LIGNES_VENTES
├── IdLigneVente (PK)
├── IdVente (FK → VENTES)
├── IdArticle (FK → ARTICLES)
├── Console (FK → ARTICLES)
├── Prix
└── Quantite
```

## Contraintes d'Intégrité

- **Clés primaires** sur toutes les tables
- **Clés étrangères** pour garantir la cohérence
- **CASCADE DELETE** sur LIGNES_VENTES (si vente supprimée, détails aussi)

## Exécution
```sql
@01_normalization_complet.sql
```

## Vérification
Le script affiche un résumé:
- Nombre de clients
- Nombre d'articles
- Nombre de magasins
- Nombre de ventes
- Nombre de lignes de vente

## Notes
- La vue ARTICLES_DECOMPOSE est intermédiaire, utilisée pour l'import
- Les données invalides (champs NULL) sont automatiquement filtrées
- Les erreurs de conversion sont ignorées (EXCEPTION WHEN OTHERS THEN NULL)
