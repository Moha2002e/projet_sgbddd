SET SERVEROUTPUT ON;

BEGIN
    ORDS.DELETE_MODULE(p_module_name => 'ventes_api');
    DBMS_OUTPUT.PUT_LINE('Module ventes_api supprime');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ℹ️  Aucun module a supprimer.');
END;
/


-- Désactivation du schéma ORDS
BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled => FALSE,
        p_schema  => 'PROJETBD1'
    );
    DBMS_OUTPUT.PUT_LINE('✅ Schema ORDS desactive.');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('ℹ️  Aucun schema a desactiver.');
END;
/

BEGIN
    FOR rec IN (SELECT module_name FROM user_ords_modules) LOOP
        BEGIN
            ORDS.DELETE_MODULE(p_module_name => rec.module_name);
            DBMS_OUTPUT.PUT_LINE('Module ' || rec.module_name || ' supprime');
        EXCEPTION
            WHEN OTHERS THEN
                NULL;
        END;
    END LOOP;
    
    BEGIN
        ORDS_METADATA.ORDS_ADMIN.CONFIG_PLSQL_GATEWAY(
            p_enabled => FALSE,
            p_schema => 'PROJETBD1'
        );
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    
    DBMS_OUTPUT.PUT_LINE('Configuration ORDS nettoyee');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Nettoyage termine');
END;
/

BEGIN
    DBMS_LOCK.SLEEP(2);
END;
/

BEGIN
    ORDS.ENABLE_SCHEMA(
        p_enabled => TRUE,
        p_schema  => 'PROJETBD1',
        p_url_mapping_type => 'BASE_PATH',
        p_url_mapping_pattern => 'gamestore',
        p_auto_rest_auth => FALSE
    );
    DBMS_OUTPUT.PUT_LINE('Schema ORDS active: http://192.168.0.18:8080/ords/gamestore/');
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = -20006 THEN
            DBMS_OUTPUT.PUT_LINE('Schema ORDS deja active');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Erreur activation: ' || SQLERRM);
        END IF;
END;
/

BEGIN
    ORDS.DEFINE_MODULE(
        p_module_name => 'ventes_api',
        p_base_path   => '/ventes/',
        p_items_per_page => 25,
        p_status      => 'PUBLISHED'
    );
    DBMS_OUTPUT.PUT_LINE('Module ventes_api cree: http://192.168.0.18:8080/ords/gamestore/ventes/');
END;
/

BEGIN
    ORDS.DEFINE_TEMPLATE(
        p_module_name => 'ventes_api',
        p_pattern     => ':idVente'
    );
    DBMS_OUTPUT.PUT_LINE('Template GET :idVente cree');
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
    vnt.IdVente AS "idVente",
    TO_CHAR(vnt.DateAchat, 'DD/MM/YYYY') AS "dateAchat",
    vnt.URLTicket AS "urlTicket",
    APEX_WEB_SERVICE.BLOB2CLOBBASE64(vnt.TICKET_BLOB) AS "ticketImageBase64",
    JSON_OBJECT(
        'idClient' VALUE cli.IdClient,
        'nom' VALUE cli.NomClient,
        'prenom' VALUE cli.PrenomClient,
        'email' VALUE cli.EmailClient
    ) AS "client",
    JSON_OBJECT(
        'idMagasin' VALUE mag.IdMagasin,
        'nom' VALUE mag.NomMagasin,
        'codePostal' VALUE mag.CodePostalMagasin,
        'fragment' VALUE CASE 
            WHEN mag.CodePostalMagasin < 5000 THEN 'DB1' 
            ELSE 'DB2' 
        END
    ) AS "magasin",
    (
        SELECT JSON_ARRAYAGG(
            JSON_OBJECT(
                'idArticle' VALUE lv.IdArticle,
                'libelle' VALUE art.LibelleArticle,
                'console' VALUE lv.Console,
                'prixUnitaire' VALUE lv.Prix,
                'quantite' VALUE lv.Quantite,
                'montantTotal' VALUE (lv.Prix * lv.Quantite)
            )
            ORDER BY lv.IdLigneVente
        )
        FROM LIGNES_VENTES lv
        JOIN ARTICLES art ON lv.IdArticle = art.IdArticle AND lv.Console = art.Console
        WHERE lv.IdVente = vnt.IdVente
    ) AS "articles",
    (
        SELECT SUM(lv.Prix * lv.Quantite)
        FROM LIGNES_VENTES lv
        WHERE lv.IdVente = vnt.IdVente
    ) AS "montantTotal"
FROM VENTES vnt
JOIN CLIENTS cli ON vnt.IdClient = cli.IdClient
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE vnt.IdVente = :idVente
        ]'
    );
    DBMS_OUTPUT.PUT_LINE('Handler GET /ventes/:idVente cree');
END;
/
