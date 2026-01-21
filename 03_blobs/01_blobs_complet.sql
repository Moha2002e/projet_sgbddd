SET SERVEROUTPUT ON;

DECLARE
    dir_path VARCHAR2(1000);
BEGIN
    BEGIN
        SELECT DIRECTORY_PATH INTO dir_path
        FROM ALL_DIRECTORIES 
        WHERE DIRECTORY_NAME = 'BLOBS_DIR';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            dir_path := NULL;
    END;
    
    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY BLOBS_DIR AS ''/tmp''';
    DBMS_OUTPUT.PUT_LINE('Repertoire BLOBS_DIR cree -> /tmp');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erreur creation repertoire: ' || SQLERRM);
        RAISE;
END;
/

DECLARE
    cnt NUMBER;
BEGIN
    SELECT COUNT(*) INTO cnt 
    FROM USER_TAB_COLUMNS 
    WHERE TABLE_NAME = 'VENTES' AND COLUMN_NAME = 'TICKET_BLOB';
    
    IF cnt = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE VENTES ADD TICKET_BLOB BLOB';
        DBMS_OUTPUT.PUT_LINE('Colonne TICKET_BLOB ajoutee');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Colonne TICKET_BLOB deja presente');
    END IF;
END;
/

DECLARE
    blob_temp BLOB;
    bfile_img BFILE;
    nb_ventes NUMBER := 0;
BEGIN
    DBMS_LOB.CREATETEMPORARY(blob_temp, TRUE);
    
    bfile_img := BFILENAME('BLOBS_DIR', 'ticket.jpg');
    
    IF DBMS_LOB.FILEEXISTS(bfile_img) = 1 THEN
        DBMS_LOB.FILEOPEN(bfile_img, DBMS_LOB.FILE_READONLY);
        
        DBMS_LOB.LOADFROMFILE(
            dest_lob => blob_temp,
            src_lob => bfile_img,
            amount => DBMS_LOB.GETLENGTH(bfile_img)
        );
        
        DBMS_LOB.FILECLOSE(bfile_img);
        
        DBMS_OUTPUT.PUT_LINE('Image chargee: ' || DBMS_LOB.GETLENGTH(blob_temp) || ' octets');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Fichier ticket.jpg introuvable dans /tmp');
        RAISE_APPLICATION_ERROR(-20001, 'Fichier introuvable');
    END IF;
    
    UPDATE VENTES SET TICKET_BLOB = blob_temp;
    
    SELECT COUNT(*) INTO nb_ventes FROM VENTES WHERE TICKET_BLOB IS NOT NULL;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('BLOB copie dans ' || nb_ventes || ' ventes');
    
    DBMS_LOB.FREETEMPORARY(blob_temp);
    
EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_LOB.FILEISOPEN(bfile_img) = 1 THEN
            DBMS_LOB.FILECLOSE(bfile_img);
        END IF;
        DBMS_OUTPUT.PUT_LINE('Erreur: ' || SQLERRM);
        ROLLBACK;
END;
/

SELECT 
    COUNT(*) AS "Total ventes",
    SUM(CASE WHEN TICKET_BLOB IS NOT NULL THEN 1 ELSE 0 END) AS "Ventes avec BLOB",
    MIN(DBMS_LOB.GETLENGTH(TICKET_BLOB)) AS "Taille (octets)"
FROM VENTES;
