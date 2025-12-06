/**
3.1  Intégration du fichier en tant que table externe 
Le fichier ventes_games.txt sera pointé par une table externe, ce qui permettra l’accession 
aisée de ces données à l’intérieur d’une base de données oracle 
*/
SET SERVEROUTPUT ON;

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM ALL_DIRECTORIES WHERE DIRECTORY_NAME = 'VENTES_DIR';
    
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP DIRECTORY VENTES_DIR';
    END IF;
    
    EXECUTE IMMEDIATE 'CREATE DIRECTORY VENTES_DIR AS ''/home/oracle/Documents''';
    
    EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY VENTES_DIR TO PUBLIC';
    
    DBMS_OUTPUT.PUT_LINE('✅ Dossier VENTES_DIR configuré.');
END;
/

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM USER_TABLES WHERE TABLE_NAME = 'VENTES_EXT';
    
    IF v_count > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE VENTES_EXT';
    END IF;
END;
/

CREATE TABLE VENTES_EXT (
    IdVente           NUMBER,
    IdClient          NUMBER,
    NomClient         VARCHAR2(100),
    PrenomClient      VARCHAR2(100),
    EmailClient       VARCHAR2(200),
    IdMagasin         NUMBER,
    NomMagasin        VARCHAR2(100),
    CodePostalMagasin NUMBER,
    ListeAchats       VARCHAR2(4000),
    DateAchat         VARCHAR2(10),
    URLTicket         VARCHAR2(500)
)
ORGANIZATION EXTERNAL (
    TYPE ORACLE_LOADER
    DEFAULT DIRECTORY VENTES_DIR
    ACCESS PARAMETERS (
        RECORDS DELIMITED BY NEWLINE
        CHARACTERSET UTF8
        FIELDS TERMINATED BY ';'
        MISSING FIELD VALUES ARE NULL
    )
    LOCATION ('ventes_games.txt')
)
REJECT LIMIT UNLIMITED;

DECLARE
    v_total NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM VENTES_EXT;
    DBMS_OUTPUT.PUT_LINE('✅ Table externe créée. Nombre de lignes trouvées : ' || v_total);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Erreur : Impossible de lire le fichier. Vérifiez qu''il est bien dans /home/oracle/Documents');
END;
/
