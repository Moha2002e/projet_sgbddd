/**
3.4 Fragmentation dans une base de données distribuée 
Votre base de données sera en réalité distribuée en deux bases de données distinctes. 
Chaque base de données contiendra le même schéma, mais les données seront répliquées 
et/ou fragmentées. 
Les informations concernant les articles et les clients seront répliquées sur chacune des deux 
bases de données. On considèrera que cette information ne sera pas soumise à changement 
(pas de nouveaux clients, pas de nouveaux articles ou de retraits d’articles). 
Les informations sur les ventes et les magasins seront fragmentées par rapport au code 
postal du magasin. La première base de données contiendra uniquement les informations 
concernant les ventes s’étant effectuées dans un magasin dont le code postal est compris 
entre 0 et 4999, alors que la deuxième base de données contiendra les informations des 
magasins avec un code postal entre 5000 et 9999. 
*/
SET SERVEROUTPUT ON;

BEGIN
    FOR t IN (SELECT table_name FROM user_tables 
              WHERE table_name LIKE 'DB2_%') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('✅ Tables DB2 nettoyees.');
END;
/

CREATE TABLE DB2_CLIENTS (
    IdClient NUMBER PRIMARY KEY,
    NomClient VARCHAR2(100),
    PrenomClient VARCHAR2(100),
    EmailClient VARCHAR2(200) UNIQUE
);

CREATE TABLE DB2_ARTICLES (
    IdArticle NUMBER,
    LibelleArticle VARCHAR2(200),
    Console VARCHAR2(50),
    PRIMARY KEY (IdArticle, Console)
);

CREATE TABLE DB2_MAGASINS (
    IdMagasin NUMBER PRIMARY KEY,
    NomMagasin VARCHAR2(100),
    CodePostalMagasin NUMBER,
    CONSTRAINT CK_DB2_MAGASINS_CP CHECK (CodePostalMagasin >= 5000 AND CodePostalMagasin <= 9999)
);

CREATE TABLE DB2_VENTES (
    IdVente NUMBER PRIMARY KEY,
    IdClient NUMBER REFERENCES DB2_CLIENTS(IdClient),
    IdMagasin NUMBER REFERENCES DB2_MAGASINS(IdMagasin),
    DateAchat DATE,
    URLTicket VARCHAR2(500)
);

CREATE TABLE DB2_LIGNES_VENTES (
    IdLigneVente NUMBER PRIMARY KEY,
    IdVente NUMBER REFERENCES DB2_VENTES(IdVente) ON DELETE CASCADE,
    IdArticle NUMBER,
    Console VARCHAR2(50),
    Prix NUMBER(10,2),
    Quantite NUMBER,
    FOREIGN KEY (IdArticle, Console) REFERENCES DB2_ARTICLES(IdArticle, Console)
);

PROMPT ✅ Tables DB2 creees.

INSERT INTO DB2_CLIENTS SELECT * FROM CLIENTS;
PROMPT ✅ Clients repliques dans DB2.

INSERT INTO DB2_ARTICLES SELECT * FROM ARTICLES;
PROMPT ✅ Articles repliques dans DB2.

INSERT INTO DB2_MAGASINS 
SELECT * FROM MAGASINS 
WHERE CodePostalMagasin >= 5000 AND CodePostalMagasin <= 9999;
PROMPT ✅ Magasins (CP 5000-9999) inseres dans DB2.

INSERT INTO DB2_VENTES (IdVente, IdClient, IdMagasin, DateAchat, URLTicket)
SELECT vnt.IdVente, vnt.IdClient, vnt.IdMagasin, vnt.DateAchat, vnt.URLTicket
FROM VENTES vnt
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE mag.CodePostalMagasin >= 5000 AND mag.CodePostalMagasin <= 9999;
PROMPT ✅ Ventes (CP 5000-9999) inserees dans DB2.

INSERT INTO DB2_LIGNES_VENTES
SELECT lgn.*
FROM LIGNES_VENTES lgn
JOIN VENTES vnt ON lgn.IdVente = vnt.IdVente
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE mag.CodePostalMagasin >= 5000 AND mag.CodePostalMagasin <= 9999;
PROMPT ✅ Details ventes (CP 5000-9999) inseres dans DB2.

COMMIT;

SELECT 'DB2 - Clients :' AS Info, COUNT(*) AS Nb FROM DB2_CLIENTS
UNION ALL
SELECT 'DB2 - Articles :', COUNT(*) FROM DB2_ARTICLES
UNION ALL
SELECT 'DB2 - Magasins (5000-9999) :', COUNT(*) FROM DB2_MAGASINS
UNION ALL
SELECT 'DB2 - Ventes :', COUNT(*) FROM DB2_VENTES
UNION ALL
SELECT 'DB2 - Details ventes :', COUNT(*) FROM DB2_LIGNES_VENTES;

PROMPT ✅ BASE 2 (CP 5000-9999) creee et remplie avec succes !
