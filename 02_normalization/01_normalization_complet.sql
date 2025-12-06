/**
3.2 Normalisation des tables 
En suivant la méthodologie vue pendant votre formation (cfr. Cours de Mme Serrhini), vous 
normaliserez la table externe en un ensemble de tables (internes, cette fois), en vous assurant 
que chaque table respecte bien la BCNF.  
Pour vous aider, voici un code permettant de décomposer le champ « Articles », et de 
récupérer un tuple par article acheté (le nom de la table et des colonnes dépend de ce que 
vous avez choisi au moment de la création de la table externe) :  
SELECT IdVente, REGEXP_SUBSTR(str, '[^.]+', 1, 1) as IdArticle, 
REGEXP_SUBSTR(str, '[^.]+', 1, 2) as Libelle, 
REGEXP_SUBSTR(str, '[^.]+', 1, 3) as Prix, 
REGEXP_SUBSTR(str, '[^.]+', 1, 4) as Quantite, 
REGEXP_SUBSTR(str, '[^.]+', 1, 5) as Console 
FROM 
( 
SELECT distinct IdVente, trim(regexp_substr(str, '[^&]+', 1, 
level)) str 
FROM (SELECT IdVente, ListeAchats str FROM ventes_ext) t 
CONNECT BY instr(str, '&', 1, level - 1) > 0 
order by IdVente 
); 
*/

SET SERVEROUTPUT ON;

BEGIN
    FOR t IN (SELECT table_name FROM user_tables 
              WHERE table_name IN ('LIGNES_VENTES', 'VENTE_ARTICLES', 'VENTES', 'ARTICLES', 'MAGASINS', 'CLIENTS')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    
    FOR v IN (SELECT view_name FROM user_views WHERE view_name = 'ARTICLES_DECOMPOSE') LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('✅ Nettoyage termine.');
END;
/

CREATE TABLE CLIENTS AS 
SELECT DISTINCT IdClient, NomClient, PrenomClient, EmailClient
FROM VENTES_EXT;

ALTER TABLE CLIENTS ADD CONSTRAINT pk_clients PRIMARY KEY (IdClient);

CREATE TABLE MAGASINS AS 
SELECT DISTINCT IdMagasin, NomMagasin, CodePostalMagasin
FROM VENTES_EXT;

ALTER TABLE MAGASINS ADD CONSTRAINT pk_magasins PRIMARY KEY (IdMagasin);

CREATE TABLE VENTES AS 
SELECT IdVente, IdClient, IdMagasin, DateAchat, URLTicket
FROM VENTES_EXT;

ALTER TABLE VENTES ADD CONSTRAINT pk_ventes PRIMARY KEY (IdVente);
ALTER TABLE VENTES ADD CONSTRAINT fk_ventes_clients FOREIGN KEY (IdClient) REFERENCES CLIENTS(IdClient);
ALTER TABLE VENTES ADD CONSTRAINT fk_ventes_magasins FOREIGN KEY (IdMagasin) REFERENCES MAGASINS(IdMagasin);

PROMPT ✅ Tables CLIENTS, MAGASINS, VENTES creees.

CREATE VIEW ARTICLES_DECOMPOSE AS
SELECT IdVente, 
       REGEXP_SUBSTR(str, '[^.]+', 1, 1) as IdArticle,
       REGEXP_SUBSTR(str, '[^.]+', 1, 2) as Libelle,
       REGEXP_SUBSTR(str, '[^.]+', 1, 3) as Prix,
       REGEXP_SUBSTR(str, '[^.]+', 1, 4) as Quantite,
       REGEXP_SUBSTR(str, '[^.]+', 1, 5) as Console
FROM (
    SELECT DISTINCT IdVente, TRIM(REGEXP_SUBSTR(str, '[^&]+', 1, LEVEL)) str
    FROM (SELECT IdVente, ListeAchats str FROM VENTES_EXT) t
    CONNECT BY INSTR(str, '&', 1, LEVEL - 1) > 0
    AND PRIOR IdVente = IdVente
    AND PRIOR SYS_GUID() IS NOT NULL
)
WHERE str IS NOT NULL AND LENGTH(str) > 5;

PROMPT ✅ Vue ARTICLES_DECOMPOSE creee.

CREATE TABLE ARTICLES (
    IdArticle NUMBER,
    LibelleArticle VARCHAR2(200),
    Console VARCHAR2(50)
);

ALTER TABLE ARTICLES ADD CONSTRAINT pk_articles PRIMARY KEY (IdArticle, Console);

INSERT INTO ARTICLES (IdArticle, LibelleArticle, Console)
SELECT DISTINCT 
    IdArticle,
    Libelle,
    Console
FROM ARTICLES_DECOMPOSE
WHERE IdArticle IS NOT NULL;

PROMPT ✅ Table ARTICLES creee et remplie.

CREATE TABLE LIGNES_VENTES (
    IdLigneVente NUMBER PRIMARY KEY,
    IdVente NUMBER,
    IdArticle NUMBER,
    Console VARCHAR2(50),
    Prix NUMBER(10,2),
    Quantite NUMBER
);

ALTER TABLE LIGNES_VENTES ADD CONSTRAINT fk_lignes_ventes FOREIGN KEY (IdVente) REFERENCES VENTES(IdVente);
ALTER TABLE LIGNES_VENTES ADD CONSTRAINT fk_lignes_articles FOREIGN KEY (IdArticle, Console) REFERENCES ARTICLES(IdArticle, Console);

DECLARE
    v_id_ligne NUMBER := 1;
BEGIN
    FOR rec IN (SELECT * FROM ARTICLES_DECOMPOSE) LOOP
        BEGIN
            IF rec.IdArticle IS NOT NULL 
               AND rec.IdVente IS NOT NULL 
               AND rec.Prix IS NOT NULL 
               AND rec.Quantite IS NOT NULL 
               AND rec.Console IS NOT NULL THEN
                
                INSERT INTO LIGNES_VENTES (IdLigneVente, IdVente, IdArticle, Console, Prix, Quantite)
                VALUES (
                    v_id_ligne,
                    TO_NUMBER(rec.IdVente),
                    TO_NUMBER(rec.IdArticle),
                    rec.Console,
                    TO_NUMBER(REPLACE(rec.Prix, ',', '.'), '999999.99', 'NLS_NUMERIC_CHARACTERS=''.,'''),
                    TO_NUMBER(rec.Quantite)
                );
                
                v_id_ligne := v_id_ligne + 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('✅ ' || (v_id_ligne - 1) || ' lignes inserees.');
END;
/

PROMPT ✅ Table LIGNES_VENTES creee et remplie.

COMMIT;

SELECT 'Clients :' AS Info, COUNT(*) AS Nb FROM CLIENTS
UNION ALL
SELECT 'Magasins :', COUNT(*) FROM MAGASINS
UNION ALL
SELECT 'Articles :', COUNT(*) FROM ARTICLES
UNION ALL
SELECT 'Ventes :', COUNT(*) FROM VENTES
UNION ALL
SELECT 'Lignes ventes :', COUNT(*) FROM LIGNES_VENTES;

PROMPT ✅ Normalisation terminee avec succes !
