/**
3.5 Service ORDS pour visualiser et modifier les données 
Votre base de données publiera un service REST à l’aide d’ORDS. 
Deux modules devront être opérationnels : 
1) Un module GET, permettant d’accéder à toutes les informations d’une vente (id, 
date, liste des articles, etc). Pour des questions de performances, vous chercherez 
l’information depuis les tables internes, et non pas depuis la table externe. L’image 
doit être envoyée sous le format Base64. 
2) Un module POST permettant de modifier le code postal d’un magasin. Le module 
prendra donc, en entrée dans le body de la requête, l’ID du magasin ainsi que son 
nouveau code postal. Pensez que le schéma de fragmentation de votre base de 
données distribuée doit rester cohérent, même après utilisation de votre procédure 
REST. La valeur de retour sera simplement les nouvelles informations du magasin 
modifié (ID, Nom, code postal). Vous pouvez créer un petit module GET pour ces 
informations, et rediriger la réponse du module POST vers ce module si cela vous 
semble plus simple. Attention que la base de données est fragmentée par rapport à 
son code postal, mettez donc en œuvre tout ce qu’il faut pour qu’elle reste dans un 
état cohérent. 
Les modules peuvent être testés soit avec un simple navigateur ou via un outil tel que 
Postman. Vous pouvez aussi développer une application qui appelle ces modules. 
**/


SET SERVEROUTPUT ON;

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled => TRUE,
        p_schema  => USER,
        p_url_mapping_type => 'BASE_PATH',
        p_url_mapping_pattern => 'gamestore',
        p_auto_rest_auth => FALSE
    );
    DBMS_OUTPUT.PUT_LINE('✅ Schema ORDS active : http://localhost:8080/ords/gamestore/');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  Schema deja active ou erreur : ' || SQLERRM);
END;
/

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'ventes_api');
    DBMS_OUTPUT.PUT_LINE('✅ Module ventes_api supprime.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('⚠️  Aucun module a supprimer.');
END;
/

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name => 'ventes_api',
        p_base_path   => '/ventes/',
        p_items_per_page => 25,
        p_status      => 'PUBLISHED'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Module cree : http://localhost:8080/ords/gamestore/ventes/');
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ventes_api',
        p_pattern     => ':idVente'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Template GET :idVente cree.');
END;
/

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ventes_api',
        p_pattern     => ':idVente',
        p_method      => 'GET',
        p_source_type => ORDS.source_type_query,
        p_source      => q'[
SELECT 
    vnt.IdVente,
    vnt.DateAchat,
    cli.NomClient AS clientNom,
    cli.PrenomClient AS clientPrenom,
    cli.EmailClient AS clientEmail,
    mag.NomMagasin AS magasinNom,
    mag.CodePostalMagasin AS codePostal,
    APEX_WEB_SERVICE.BLOB2CLOBBASE64(vnt.TICKET_BLOB) as ticketImage,
    CURSOR(
        SELECT 
            lv.IdArticle,
            lv.Console,
            lv.Prix,
            lv.Quantite,
            art.LibelleArticle
        FROM LIGNES_VENTES lv
        JOIN ARTICLES art ON lv.IdArticle = art.IdArticle AND lv.Console = art.Console
        WHERE lv.IdVente = vnt.IdVente
    ) as articles
FROM VENTES vnt
JOIN CLIENTS cli ON vnt.IdClient = cli.IdClient
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE vnt.IdVente = :idVente
        ]'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Handler GET /ventes/:idVente cree.');
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ventes_api',
        p_pattern     => 'updateMagasin'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Template POST updateMagasin cree.');
END;
/

BEGIN
    ORDS.DEFINE_HANDLER(
        p_module_name => 'ventes_api',
        p_pattern     => 'updateMagasin',
        p_method      => 'POST',
        p_source_type => ORDS.source_type_plsql,
        p_items_per_page => 0,
        p_source      => q'[
DECLARE
    v_idMagasin NUMBER;
    v_newCodePostal NUMBER;
    v_oldCodePostal NUMBER;
    v_nomMagasin VARCHAR2(100);
    v_result CLOB;
    v_json_body CLOB;
BEGIN
    v_json_body := :body_text;
    
    APEX_JSON.PARSE(v_json_body);
    v_idMagasin := APEX_JSON.get_number(p_path => 'idMagasin');
    v_newCodePostal := APEX_JSON.get_number(p_path => 'newCodePostal');
    
    SELECT CodePostalMagasin, NomMagasin 
    INTO v_oldCodePostal, v_nomMagasin
    FROM MAGASINS 
    WHERE IdMagasin = v_idMagasin;
    
    UPDATE MAGASINS
    SET CodePostalMagasin = v_newCodePostal
    WHERE IdMagasin = v_idMagasin;
    
    IF (v_oldCodePostal < 5000 AND v_newCodePostal >= 5000) OR 
       (v_oldCodePostal >= 5000 AND v_newCodePostal < 5000) THEN
        
        IF v_oldCodePostal < 5000 THEN
            DELETE FROM DB1_MAGASINS WHERE IdMagasin = v_idMagasin;
            DELETE FROM DB1_LIGNES_VENTES WHERE IdVente IN (SELECT IdVente FROM DB1_VENTES WHERE IdMagasin = v_idMagasin);
            DELETE FROM DB1_VENTES WHERE IdMagasin = v_idMagasin;
        ELSE
            DELETE FROM DB2_MAGASINS WHERE IdMagasin = v_idMagasin;
            DELETE FROM DB2_LIGNES_VENTES WHERE IdVente IN (SELECT IdVente FROM DB2_VENTES WHERE IdMagasin = v_idMagasin);
            DELETE FROM DB2_VENTES WHERE IdMagasin = v_idMagasin;
        END IF;
        
        IF v_newCodePostal < 5000 THEN
            INSERT INTO DB1_MAGASINS SELECT * FROM MAGASINS WHERE IdMagasin = v_idMagasin;
            INSERT INTO DB1_VENTES SELECT * FROM VENTES WHERE IdMagasin = v_idMagasin;
            INSERT INTO DB1_LIGNES_VENTES 
            SELECT lgn.* FROM LIGNES_VENTES lgn
            JOIN VENTES vnt ON lgn.IdVente = vnt.IdVente
            WHERE vnt.IdMagasin = v_idMagasin;
        ELSE
            INSERT INTO DB2_MAGASINS SELECT * FROM MAGASINS WHERE IdMagasin = v_idMagasin;
            INSERT INTO DB2_VENTES SELECT * FROM VENTES WHERE IdMagasin = v_idMagasin;
            INSERT INTO DB2_LIGNES_VENTES 
            SELECT lgn.* FROM LIGNES_VENTES lgn
            JOIN VENTES vnt ON lgn.IdVente = vnt.IdVente
            WHERE vnt.IdMagasin = v_idMagasin;
        END IF;
    ELSE
        IF v_newCodePostal < 5000 THEN
            UPDATE DB1_MAGASINS SET CodePostalMagasin = v_newCodePostal WHERE IdMagasin = v_idMagasin;
        ELSE
            UPDATE DB2_MAGASINS SET CodePostalMagasin = v_newCodePostal WHERE IdMagasin = v_idMagasin;
        END IF;
    END IF;
    
    COMMIT;
    
    v_result := JSON_OBJECT(
        'idMagasin' VALUE v_idMagasin,
        'nomMagasin' VALUE v_nomMagasin,
        'oldCodePostal' VALUE v_oldCodePostal,
        'newCodePostal' VALUE v_newCodePostal,
        'message' VALUE 'Code postal mis a jour avec succes'
    );
    
    :status := 200;
    HTP.PRINT(v_result);
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :status := 404;
        HTP.PRINT('{"error": "Magasin non trouve"}');
    WHEN OTHERS THEN
        :status := 500;
        HTP.PRINT('{"error": "' || SQLERRM || '"}');
END;
        ]'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Handler POST /ventes/updateMagasin cree.');
END;
/

COMMIT;

PROMPT ✅ Configuration ORDS terminee !
PROMPT 
PROMPT 📡 URLs disponibles :
PROMPT    - GET  : http://localhost:8080/ords/gamestore/ventes/{idVente}
PROMPT    - POST : http://localhost:8080/ords/gamestore/ventes/updateMagasin

PROMPT ✅ Etape 5 terminee avec succes !
