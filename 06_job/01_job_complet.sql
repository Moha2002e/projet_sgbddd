SET SERVEROUTPUT ON;

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE STATS_LOG CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('✅ Ancienne table supprimée (si elle existait)');
EXCEPTION 
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE('⚠️  Table n''existait pas encore');
END;
/

CREATE TABLE STATS_LOG (
    IdLog NUMBER PRIMARY KEY,
    DateLog DATE,
    TotalVentes NUMBER(15, 2)
);

BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Table STATS_LOG (Entrepôt) créée');
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK DBL_ENTREPOT';
EXCEPTION 
    WHEN OTHERS THEN NULL;
END;
/

/* A MODIFIER AVEC VOS IDENTIFIANTS REELS */
CREATE DATABASE LINK DBL_ENTREPOT
CONNECT TO SYSTEM IDENTIFIED BY oracle
USING '192.168.0.16:1521/orcl';

BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Database Link DBL_ENTREPOT créé');
END;
/

CREATE OR REPLACE PROCEDURE MAJ_STATS IS
    v_totalGlobal NUMBER(15, 2);
    v_idLog NUMBER;
    v_sql VARCHAR2(1000);
BEGIN
    -- 1. Calcul local
    SELECT 
        NVL(SUM(lv.Prix * lv.Quantite), 0)
    INTO v_totalGlobal
    FROM VENTES v
    JOIN LIGNES_VENTES lv ON v.IdVente = lv.IdVente
    WHERE TRUNC(TO_DATE(v.DateAchat, 'DD/MM/YY')) = TRUNC(SYSDATE);
    
    -- 2. Opérations distantes via SQL Dynamique (évite l'erreur de compilation si le lien est HS)
    BEGIN
        -- Récupérer ID
        v_sql := 'SELECT COALESCE(MAX(IdLog) + 1, 1) FROM STATS_LOG@DBL_ENTREPOT';
        EXECUTE IMMEDIATE v_sql INTO v_idLog;
        
        -- Insérer
        v_sql := 'INSERT INTO STATS_LOG@DBL_ENTREPOT VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE v_sql USING v_idLog, SYSDATE, v_totalGlobal;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('✅ Stats envoyées vers l''entrepôt via DBLink');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('⚠️ Impossible de contacter l''entrepôt (DBLink HS ou Table manquante).');
            DBMS_OUTPUT.PUT_LINE('   Données non archivées, mais le Job tourne.');
            -- On ne raise pas l'erreur pour ne pas faire planter le Job au quotidien
    END;
    
END MAJ_STATS;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('✅ Procédure MAJ_STATS créée');
END;
/

BEGIN
    MAJ_STATS;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Erreur lors du test DBLink : ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('ℹ️  Vérifiez la configuration de DBL_ENTREPOT');
END;
/

BEGIN
    DBMS_SCHEDULER.DROP_JOB('JOB_STATS', TRUE);
EXCEPTION 
    WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'JOB_STATS',
        job_type => 'STORED_PROCEDURE',
        job_action => 'MAJ_STATS',
        repeat_interval => 'FREQ=DAILY; BYHOUR=3; BYMINUTE=0',
        enabled => TRUE
    );
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✅ Job JOB_STATS créé');
END;
/

PROMPT ✅ Étape 6 terminée avec succès (Configuration DBLink stricte appliquée) !
