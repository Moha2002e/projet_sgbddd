SET SERVEROUTPUT ON;

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE STATS_LOG CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Table STATS_LOG supprimee');
EXCEPTION 
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE('Table n''existait pas');
END;
/

CREATE TABLE STATS_LOG (
    IdLog NUMBER PRIMARY KEY,
    DateLog DATE,
    TotalVentes NUMBER(15, 2)
);

BEGIN
    DBMS_OUTPUT.PUT_LINE('Table STATS_LOG creee');
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP DATABASE LINK DBL_ENTREPOT';
EXCEPTION 
    WHEN OTHERS THEN NULL;
END;
/

CREATE DATABASE LINK DBL_ENTREPOT
CONNECT TO SYSTEM IDENTIFIED BY oracle
USING '192.168.0.18:1521/orcl';

BEGIN
    DBMS_OUTPUT.PUT_LINE('Database Link DBL_ENTREPOT cree');
END;
/

CREATE OR REPLACE PROCEDURE MAJ_STATS IS
    total_global NUMBER(15, 2);
    id_log NUMBER;
    sql_stmt VARCHAR2(1000);
    date_aujourdhui VARCHAR2(8);
BEGIN
    date_aujourdhui := TO_CHAR(SYSDATE, 'DD/MM/YY');
    
    SELECT 
        NVL(SUM(lv.Prix * lv.Quantite), 0)
    INTO total_global
    FROM VENTES v
    JOIN LIGNES_VENTES lv ON v.IdVente = lv.IdVente
    WHERE v.DateAchat = date_aujourdhui;
    
    BEGIN
        sql_stmt := 'SELECT COALESCE(MAX(IdLog) + 1, 1) FROM STATS_LOG@DBL_ENTREPOT';
        EXECUTE IMMEDIATE sql_stmt INTO id_log;
        
        sql_stmt := 'INSERT INTO STATS_LOG@DBL_ENTREPOT VALUES (:1, :2, :3)';
        EXECUTE IMMEDIATE sql_stmt USING id_log, SYSDATE, total_global;
        
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Stats envoyees vers entrepot');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Impossible de contacter entrepot');
            DBMS_OUTPUT.PUT_LINE('Donnees non archivees');
    END;
    
END MAJ_STATS;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('Procedure MAJ_STATS creee');
END;
/

BEGIN
    MAJ_STATS;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur test DBLink: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Verifier config DBL_ENTREPOT');
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
    DBMS_OUTPUT.PUT_LINE('Job JOB_STATS cree');
END;
/

SELECT job_name, state, enabled, last_start_date, next_run_date 
FROM user_scheduler_jobs 
WHERE job_name = 'JOB_STATS';

EXEC MAJ_STATS;

SELECT * FROM STATS_LOG@DBL_ENTREPOT ORDER BY DateLog DESC;

BEGIN
    DBMS_SCHEDULER.RUN_JOB('JOB_STATS');
END;
/

SELECT log_date, status, additional_info 
FROM user_scheduler_job_run_details 
WHERE job_name = 'JOB_STATS'
ORDER BY log_date DESC;
