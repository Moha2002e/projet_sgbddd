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
    v_nb_ventes NUMBER := 0;
BEGIN
    DBMS_LOB.CREATETEMPORARY(v_blob, TRUE);
    
    DBMS_LOB.WRITEAPPEND(v_blob, 2, HEXTORAW('FFD8')); 
    DBMS_LOB.WRITEAPPEND(v_blob, 18, HEXTORAW('FFE000104A46494600010100000100010000'));
    
    FOR i IN 1..2500 LOOP
        DBMS_LOB.WRITEAPPEND(v_blob, 20, HEXTORAW('0000000000000000000000000000000000000000'));
    END LOOP;
    
    DBMS_LOB.WRITEAPPEND(v_blob, 2, HEXTORAW('FFD9'));
    
    DBMS_OUTPUT.PUT_LINE('✅ BLOB de test genere (' || DBMS_LOB.GETLENGTH(v_blob) || ' octets).');
    DBMS_OUTPUT.PUT_LINE('   Format: JPEG valide');
    
    UPDATE VENTES SET TICKET_BLOB = v_blob;
    
    SELECT COUNT(*) INTO v_nb_ventes FROM VENTES WHERE TICKET_BLOB IS NOT NULL;
    
    COMMIT;
    
    DBMS_OUTPUT.PUT_LINE('✅ BLOB copie dans ' || v_nb_ventes || ' ventes.');
    
    DBMS_LOB.FREETEMPORARY(v_blob);
    
EXCEPTION
    WHEN OTHERS THEN
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
