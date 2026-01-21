# ORDS - API REST

## Objectif
Créer un service REST pour exposer les données de ventes via HTTP.

## Oracle REST Data Services (ORDS)

ORDS permet de:
- Transformer des requêtes SQL en endpoints REST
- Générer automatiquement du JSON
- Exposer la base de données via HTTP
- Éviter le développement d'un middleware

## Configuration

### URL de Base
```
http://192.168.0.18:8080/ords/gamestore/
```

- **192.168.0.18** - IP du serveur Oracle
- **8080** - Port ORDS
- **gamestore** - Alias du schéma (mapping de projetBD1)

### Module Créé
```
/ventes/
```
Module dédié à la gestion des ventes.

## Endpoint Disponible

### GET /ventes/:idVente

**URL Complète:**
```
http://192.168.0.18:8080/ords/gamestore/ventes/1
```

**Description:**
Récupère toutes les informations d'une vente spécifique.

**Réponse JSON:**
```json
{
  "idVente": 1,
  "dateAchat": "15/01/2024",
  "urlTicket": "http://...",
  "ticketImageBase64": "iVBORw0KGgoAAAANSUhEUg...",
  "client": {
    "idClient": 123,
    "nom": "Dupont",
    "prenom": "Jean",
    "email": "jean.dupont@mail.com"
  },
  "magasin": {
    "idMagasin": 5,
    "nom": "GameStore Paris",
    "codePostal": 75001,
    "fragment": "DB1"
  },
  "articles": [
    {
      "idArticle": 42,
      "libelle": "FIFA 24",
      "console": "PS5",
      "prixUnitaire": 69.99,
      "quantite": 1,
      "montantTotal": 69.99
    },
    {
      "idArticle": 87,
      "libelle": "Mario Kart 8",
      "console": "Switch",
      "prixUnitaire": 49.99,
      "quantite": 2,
      "montantTotal": 99.98
    }
  ],
  "montantTotal": 169.97
}
```

**Champs:**
- `ticketImageBase64` - Image du ticket encodée en base64
- `fragment` - Indique si la vente est en DB1 ou DB2
- `articles` - Tableau JSON des articles achetés
- `montantTotal` - Somme totale de la vente

## Fonctions SQL Utilisées

**JSON_OBJECT:**
```sql
JSON_OBJECT(
    'idClient' VALUE cli.IdClient,
    'nom' VALUE cli.NomClient
)
```
Crée un objet JSON.

**JSON_ARRAYAGG:**
```sql
JSON_ARRAYAGG(
    JSON_OBJECT(...)
)
```
Crée un tableau JSON d'objets.

**APEX_WEB_SERVICE.BLOB2CLOBBASE64:**
```sql
APEX_WEB_SERVICE.BLOB2CLOBBASE64(vnt.TICKET_BLOB)
```
Convertit un BLOB en chaîne base64.

## Processus de Configuration

### 1. Nettoyage
```sql
ORDS.DELETE_MODULE(p_module_name => 'ventes_api');
```

### 2. Activation du Schéma
```sql
ORDS.ENABLE_SCHEMA(
    p_enabled => TRUE,
    p_schema => 'PROJETBD1',
    p_url_mapping_pattern => 'gamestore'
);
```

### 3. Création du Module
```sql
ORDS.DEFINE_MODULE(
    p_module_name => 'ventes_api',
    p_base_path => '/ventes/'
);
```

### 4. Définition du Template
```sql
ORDS.DEFINE_TEMPLATE(
    p_module_name => 'ventes_api',
    p_pattern => ':idVente'
);
```

### 5. Création du Handler
```sql
ORDS.DEFINE_HANDLER(
    p_module_name => 'ventes_api',
    p_pattern => ':idVente',
    p_method => 'GET',
    p_source_type => ORDS.source_type_query,
    p_source => 'SELECT ...'
);
```

## Test avec cURL

```bash
# Récupérer la vente 1
curl http://192.168.0.18:8080/ords/gamestore/ventes/1

# Avec jq pour formatter le JSON
curl http://192.168.0.18:8080/ords/gamestore/ventes/1 | jq

# Headers HTTP
curl -I http://192.168.0.18:8080/ords/gamestore/ventes/1
```

## Test avec Postman

1. Importer `Postman_ORDS_Tests.json`
2. Vérifier/modifier l'URL de base
3. Exécuter les requêtes

## Exécution

```sql
@01_ords_complet.sql
```

## Vérification

**Lister les modules ORDS:**
```sql
SELECT module_name, base_path, status 
FROM user_ords_modules;
```

**Lister les templates:**
```sql
SELECT template_name, uri_template 
FROM user_ords_templates;
```

**Lister les handlers:**
```sql
SELECT template_name, method, source_type 
FROM user_ords_handlers;
```

## Erreurs Courantes

**404 Not Found:**
- Vérifier que ORDS est démarré
- Vérifier l'URL (port, alias, endpoint)

**500 Internal Error:**
- Erreur SQL dans la requête
- Vérifier les logs ORDS

**Schéma déjà activé:**
- Normal si réexécution du script
- Ignoré automatiquement

## Extensions Possibles

**POST /ventes:**
Créer une nouvelle vente.

**PUT /ventes/:id:**
Modifier une vente.

**DELETE /ventes/:id:**
Supprimer une vente.

**GET /ventes?date=:date:**
Filtrer par date.

**GET /clients/:id/ventes:**
Ventes d'un client.
