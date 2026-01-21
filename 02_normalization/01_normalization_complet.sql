
SET SERVEROUTPUT ON;

BEGIN
    FOR t IN (SELECT table_name FROM user_tables 
              WHERE table_name IN ('LIGNES_VENTES', 'VENTE_ARTICLES', 'VENTES', 'ARTICLES', 'MAGASINS', 'CLIENTS')) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    
    FOR v IN (SELECT view_name FROM user_views WHERE view_name = 'ARTICLES_DECOMPOSE') LOOP
        EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('Nettoyage ok');
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
    id_ligne NUMBER := 1;
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
                    id_ligne,
                    TO_NUMBER(rec.IdVente),
                    TO_NUMBER(rec.IdArticle),
                    rec.Console,
                    TO_NUMBER(REPLACE(rec.Prix, ',', '.'), '999999.99', 'NLS_NUMERIC_CHARACTERS=''.,'''),
                    TO_NUMBER(rec.Quantite)
                );
                
                id_ligne := id_ligne + 1;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN NULL;
        END;
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE((id_ligne - 1) || ' lignes ok');
END;
/

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
