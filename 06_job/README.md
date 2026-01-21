# Job - Automatisation et Synchronisation

## Objectif
Créer un job planifié qui calcule quotidiennement le chiffre d'affaires et l'envoie vers un entrepôt de données distant.

## Architecture

```
┌─────────────────────────┐
│  BASE PRINCIPALE        │
│  (projetBD1)            │
│                         │
│  ┌─────────────────┐    │
│  │ Procédure       │    │      ┌─────────────────────────┐
│  │ MAJ_STATS       │────┼─────→│  ENTREPÔT (projetBD1)   │
│  │                 │    │      │                         │
│  └────────▲────────┘    │      │  ┌─────────────────┐    │
│           │             │      │  │ STATS_LOG       │    │
│  ┌────────┴────────┐    │      │  │ (historique)    │    │
│  │ JOB_STATS       │    │      │  └─────────────────┘    │
│  │ (tous les jours │    │      │                         │
│  │  à 3h00)        │    │      └─────────────────────────┘
│  └─────────────────┘    │               ▲
│                         │               │
└─────────────────────────┘      Database Link
                                  DBL_ENTREPOT
```

## Composants

### 1. Table STATS_LOG (Entrepôt)

**Structure:**
```sql
CREATE TABLE STATS_LOG (
    IdLog NUMBER PRIMARY KEY,
    DateLog DATE,
    TotalVentes NUMBER(15, 2)
);
```

**But:** Stocker l'historique des chiffres d'affaires quotidiens.

### 2. Database Link DBL_ENTREPOT

**Création:**
```sql
CREATE DATABASE LINK DBL_ENTREPOT
CONNECT TO SYSTEM IDENTIFIED BY oracle
USING '192.168.0.18:1521/orcl';
```

**But:** Connexion permanente vers l'entrepôt distant.

**Utilisation:**
```sql
SELECT * FROM STATS_LOG@DBL_ENTREPOT;
INSERT INTO STATS_LOG@DBL_ENTREPOT VALUES (...);
```

### 3. Procédure MAJ_STATS

**Algorithme:**
```
1. Récupérer la date du jour (format DD/MM/YY)
2. Calculer le CA: SUM(Prix × Quantité) pour les ventes du jour
3. Se connecter à l'entrepôt via DBLink
4. Récupérer le prochain IdLog (MAX + 1)
5. Insérer (IdLog, DateDuJour, CA) dans STATS_LOG@DBL_ENTREPOT
6. COMMIT
```

**Code simplifié:**
```sql
CREATE OR REPLACE PROCEDURE MAJ_STATS IS
    total_global NUMBER(15, 2);
    id_log NUMBER;
BEGIN
    -- Calcul local
    SELECT NVL(SUM(lv.Prix * lv.Quantite), 0)
    INTO total_global
    FROM VENTES v
    JOIN LIGNES_VENTES lv ON v.IdVente = lv.IdVente
    WHERE v.DateAchat = TO_CHAR(SYSDATE, 'DD/MM/YY');
    
    -- Envoi distant
    EXECUTE IMMEDIATE 'INSERT INTO STATS_LOG@DBL_ENTREPOT VALUES (...)';
    COMMIT;
END;
```

**Gestion d'erreurs:**
Si le DBLink est HS, la procédure n'échoue pas (pour ne pas bloquer le job).

### 4. Job JOB_STATS

**Configuration:**
```sql
DBMS_SCHEDULER.CREATE_JOB(
    job_name => 'JOB_STATS',
    job_type => 'STORED_PROCEDURE',
    job_action => 'MAJ_STATS',
    repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=0',
    enabled => TRUE
);
```

**Planification:**
- Fréquence: DAILY (tous les jours)
- Heure: 3h00 du matin
- Action: Exécuter la procédure MAJ_STATS

## Flux de Données

```
VENTES + LIGNES_VENTES
         │
         ▼
   Procédure MAJ_STATS
    (calcul du CA)
         │
         ▼
    Database Link
         │
         ▼
   STATS_LOG@DBL_ENTREPOT
  (historique archivé)
```

## Utilisation

### Exécution du Script
```sql
@01_job_complet.sql
```

### Test Manuel de la Procédure
```sql
EXEC MAJ_STATS;
```

### Forcer l'Exécution du Job
```sql
BEGIN
    DBMS_SCHEDULER.RUN_JOB('JOB_STATS');
END;
/
```

### Vérifier l'État du Job
```sql
SELECT job_name, state, enabled, last_start_date, next_run_date 
FROM user_scheduler_jobs 
WHERE job_name = 'JOB_STATS';
```

### Consulter l'Historique d'Exécution
```sql
SELECT log_date, status, additional_info 
FROM user_scheduler_job_run_details 
WHERE job_name = 'JOB_STATS'
ORDER BY log_date DESC;
```

### Consulter les Stats dans l'Entrepôt
```sql
SELECT * FROM STATS_LOG@DBL_ENTREPOT ORDER BY DateLog DESC;
```

## Gestion du Job

**Désactiver:**
```sql
BEGIN
    DBMS_SCHEDULER.DISABLE('JOB_STATS');
END;
/
```

**Activer:**
```sql
BEGIN
    DBMS_SCHEDULER.ENABLE('JOB_STATS');
END;
/
```

**Supprimer:**
```sql
BEGIN
    DBMS_SCHEDULER.DROP_JOB('JOB_STATS', TRUE);
END;
/
```

**Modifier la Planification:**
```sql
BEGIN
    DBMS_SCHEDULER.SET_ATTRIBUTE(
        name => 'JOB_STATS',
        attribute => 'repeat_interval',
        value => 'FREQ=HOURLY; BYMINUTE=0'
    );
END;
/
```

## Cas d'Usage Réel

**Entrepôt de Données (Data Warehouse):**
- Historisation des métriques business
- Analyses temporelles (évolution du CA)
- Tableaux de bord (dashboards)
- Reporting périodique

**Agrégations Pré-calculées:**
- Éviter de recalculer tout l'historique
- Performances améliorées pour les requêtes analytiques

**Archivage:**
- Décharger la base transactionnelle
- Conserver l'historique sur un serveur dédié

## Requêtes Analytiques sur l'Entrepôt

**CA par mois:**
```sql
SELECT 
    TO_CHAR(DateLog, 'YYYY-MM') AS mois,
    SUM(TotalVentes) AS ca_mensuel
FROM STATS_LOG@DBL_ENTREPOT
GROUP BY TO_CHAR(DateLog, 'YYYY-MM')
ORDER BY mois;
```

**Moyenne mobile sur 7 jours:**
```sql
SELECT 
    DateLog,
    TotalVentes,
    AVG(TotalVentes) OVER (ORDER BY DateLog ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS moyenne_7j
FROM STATS_LOG@DBL_ENTREPOT
ORDER BY DateLog DESC;
```

**Évolution année sur année:**
```sql
SELECT 
    TO_CHAR(DateLog, 'MM-DD') AS jour_annee,
    SUM(CASE WHEN TO_CHAR(DateLog, 'YYYY') = '2024' THEN TotalVentes END) AS ca_2024,
    SUM(CASE WHEN TO_CHAR(DateLog, 'YYYY') = '2025' THEN TotalVentes END) AS ca_2025
FROM STATS_LOG@DBL_ENTREPOT
GROUP BY TO_CHAR(DateLog, 'MM-DD')
ORDER BY jour_annee;
```

## Prérequis

- Table VENTES et LIGNES_VENTES peuplées
- Privilèges pour créer Database Links
- Privilèges pour créer des jobs (DBMS_SCHEDULER)
- Accès réseau entre les deux bases

## Notes Importantes

- Le job continue même si le DBLink est HS (robustesse)
- Les statistiques ne sont pas en temps réel (snapshot quotidien)
- Le Database Link doit être testé avant mise en production
- Les identifiants dans le DBLink sont en clair (sécuriser si nécessaire)
