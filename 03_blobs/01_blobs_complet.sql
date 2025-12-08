/**
3.3 Gestion des blobs 
Les images ne sont pas fournies dans ce projet. Vous pouvez récupérer une image de ticket 
sur le site http://image.noelshack.com/fichiers/2011/42/1319286512-dsc00041.jpg (c’est 
juste un exemple). Dans les tables internes, il vous sera demandé de remplacer le chemin 
d’accès du fichier image (qui ne pointe sur rien) par un blob contenant l’image de votre 
choix. 
Pour être très clair, chaque blob contiendra donc en réalité la même image.  
**/
SET SERVEROUTPUT ON;

-- Créer ou mettre à jour le répertoire Oracle pour accéder au fichier image
-- IMPORTANT: Oracle refuse les chemins avec liens symboliques
-- Solution: utiliser /tmp qui est un répertoire réel sans lien symbolique
-- 
-- AVANT d'exécuter ce script, copiez le fichier ticket.jpg dans /tmp :
--   cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg
--
DECLARE
    v_dir_path VARCHAR2(1000);
BEGIN
    -- Vérifier où pointe le répertoire s'il existe
    BEGIN
        SELECT DIRECTORY_PATH INTO v_dir_path
        FROM ALL_DIRECTORIES 
        WHERE DIRECTORY_NAME = 'BLOBS_DIR';
        
        DBMS_OUTPUT.PUT_LINE('⚠️  Repertoire BLOBS_DIR existe deja et pointe vers: ' || v_dir_path);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            v_dir_path := NULL;
    END;
    
    -- Utiliser /tmp qui est un répertoire système réel sans lien symbolique
    -- Accessible en écriture pour tous les utilisateurs sans sudo
    EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY BLOBS_DIR AS ''/tmp''';
    DBMS_OUTPUT.PUT_LINE('✅ Repertoire BLOBS_DIR cree/mis a jour vers /tmp');
    DBMS_OUTPUT.PUT_LINE('   Assurez-vous que ticket.jpg est dans /tmp');
    DBMS_OUTPUT.PUT_LINE('   Commande: cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('❌ Erreur lors de la creation du repertoire: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('   Vous devez peut-etre avoir les privileges CREATE ANY DIRECTORY.');
        RAISE;
END;
/

DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count 
    FROM USER_TAB_COLUMNS 
    WHERE TABLE_NAME = 'VENTES' AND COLUMN_NAME = 'TICKET_BLOB';
    
    IF v_count = 0 THEN
        EXECUTE IMMEDIATE 'ALTER TABLE VENTES ADD TICKET_BLOB BLOB';
        DBMS_OUTPUT.PUT_LINE('✅ Colonne TICKET_BLOB ajoutee.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('⚠️  Colonne TICKET_BLOB existe deja.');
    END IF;
END;
/

DECLARE
    v_blob BLOB;
    v_bfile BFILE;
    v_nb_ventes NUMBER := 0;
BEGIN
    -- Créer un BLOB temporaire
    DBMS_LOB.CREATETEMPORARY(v_blob, TRUE);
    
    -- Ouvrir le fichier image via BFILENAME
    -- BLOBS_DIR pointe vers /tmp (répertoire système réel sans lien symbolique)
    -- Le fichier ticket.jpg doit être copié dans /tmp avant l'exécution
    v_bfile := BFILENAME('BLOBS_DIR', 'ticket.jpg');
    
    -- Vérifier que le fichier existe
    IF DBMS_LOB.FILEEXISTS(v_bfile) = 1 THEN
        -- Ouvrir le fichier
        DBMS_LOB.FILEOPEN(v_bfile, DBMS_LOB.FILE_READONLY);
        
        -- Charger le contenu du fichier dans le BLOB
        DBMS_LOB.LOADFROMFILE(
            dest_lob => v_blob,
            src_lob => v_bfile,
            amount => DBMS_LOB.GETLENGTH(v_bfile)
        );
        
        -- Fermer le fichier
        DBMS_LOB.FILECLOSE(v_bfile);
        
        DBMS_OUTPUT.PUT_LINE('✅ Image ticket chargee (' || DBMS_LOB.GETLENGTH(v_blob) || ' octets).');
        DBMS_OUTPUT.PUT_LINE('   Format: JPEG');
    ELSE
        DBMS_OUTPUT.PUT_LINE('❌ Erreur: Le fichier ticket.jpg est introuvable dans /tmp.');
        DBMS_OUTPUT.PUT_LINE('   Copier le fichier: cp /home/oracle/Documents/ticket.jpg /tmp/ticket.jpg');
        RAISE_APPLICATION_ERROR(-20001, 'Fichier introuvable');
    END IF;
    
    -- Copier le BLOB dans toutes les ventes
    UPDATE VENTES SET TICKET_BLOB = v_blob;
    
    SELECT COUNT(*) INTO v_nb_ventes FROM VENTES WHERE TICKET_BLOB IS NOT NULL;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('✅ BLOB copie dans ' || v_nb_ventes || ' ventes.');
    
    DBMS_LOB.FREETEMPORARY(v_blob);
    
EXCEPTION
    WHEN OTHERS THEN
        IF DBMS_LOB.FILEISOPEN(v_bfile) = 1 THEN
            DBMS_LOB.FILECLOSE(v_bfile);
        END IF;
        DBMS_OUTPUT.PUT_LINE('❌ Erreur: ' || SQLERRM);
        ROLLBACK;
END;
/

SELECT 
    COUNT(*) AS "Total ventes",
    SUM(CASE WHEN TICKET_BLOB IS NOT NULL THEN 1 ELSE 0 END) AS "Ventes avec BLOB",
    MIN(DBMS_LOB.GETLENGTH(TICKET_BLOB)) AS "Taille (octets)"
FROM VENTES;

PROMPT ✅ Etape 3 terminee avec succes !
