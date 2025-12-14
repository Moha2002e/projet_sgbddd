/**
3.4 Fragmentation dans une base de données distribuée - PARTIE 1 (DB1)
La première base de données contiendra uniquement les informations concernant les ventes 
s’étant effectuées dans un magasin dont le code postal est compris entre 0 et 4999.
*/
SET SERVEROUTPUT ON;

BEGIN
    FOR t IN (SELECT table_name FROM user_tables 
              WHERE table_name LIKE 'DB1_%') LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS';
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('✅ Tables DB1 nettoyees.');
END;
/

CREATE TABLE DB1_CLIENTS (
    IdClient NUMBER PRIMARY KEY,
    NomClient VARCHAR2(100),
    PrenomClient VARCHAR2(100),
    EmailClient VARCHAR2(200) UNIQUE
);

CREATE TABLE DB1_ARTICLES (
    IdArticle NUMBER,
    LibelleArticle VARCHAR2(200),
    Console VARCHAR2(50),
    PRIMARY KEY (IdArticle, Console)
);

CREATE TABLE DB1_MAGASINS (
    IdMagasin NUMBER PRIMARY KEY,
    NomMagasin VARCHAR2(100),
    CodePostalMagasin NUMBER,
    CONSTRAINT CK_DB1_MAGASINS_CP CHECK (CodePostalMagasin >= 0 AND CodePostalMagasin <= 4999)
);

CREATE TABLE DB1_VENTES (
    IdVente NUMBER PRIMARY KEY,
    IdClient NUMBER REFERENCES DB1_CLIENTS(IdClient),
    IdMagasin NUMBER REFERENCES DB1_MAGASINS(IdMagasin),
    DateAchat DATE,
    URLTicket VARCHAR2(500),
    TICKET_BLOB BLOB
);

CREATE TABLE DB1_LIGNES_VENTES (
    IdLigneVente NUMBER PRIMARY KEY,
    IdVente NUMBER REFERENCES DB1_VENTES(IdVente) ON DELETE CASCADE,
    IdArticle NUMBER,
    Console VARCHAR2(50),
    Prix NUMBER(10,2),
    Quantite NUMBER,
    FOREIGN KEY (IdArticle, Console) REFERENCES DB1_ARTICLES(IdArticle, Console)
);

PROMPT ✅ Tables DB1 creees.

INSERT INTO DB1_CLIENTS SELECT * FROM CLIENTS;
PROMPT ✅ Clients repliques dans DB1.

INSERT INTO DB1_ARTICLES SELECT * FROM ARTICLES;
PROMPT ✅ Articles repliques dans DB1.

INSERT INTO DB1_MAGASINS 
SELECT * FROM MAGASINS 
WHERE CodePostalMagasin >= 0 AND CodePostalMagasin <= 4999;
PROMPT ✅ Magasins (CP 0-4999) inseres dans DB1.

INSERT INTO DB1_VENTES (IdVente, IdClient, IdMagasin, DateAchat, URLTicket, TICKET_BLOB)
SELECT vnt.IdVente, vnt.IdClient, vnt.IdMagasin, vnt.DateAchat, vnt.URLTicket, vnt.TICKET_BLOB
FROM VENTES vnt
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE mag.CodePostalMagasin >= 0 AND mag.CodePostalMagasin <= 4999;
PROMPT ✅ Ventes (CP 0-4999) inserees dans DB1.

INSERT INTO DB1_LIGNES_VENTES
SELECT lgn.*
FROM LIGNES_VENTES lgn
JOIN VENTES vnt ON lgn.IdVente = vnt.IdVente
JOIN MAGASINS mag ON vnt.IdMagasin = mag.IdMagasin
WHERE mag.CodePostalMagasin >= 0 AND mag.CodePostalMagasin <= 4999;
PROMPT ✅ Details ventes (CP 0-4999) inseres dans DB1.

COMMIT;

SELECT 'DB1 - Clients :' AS Info, COUNT(*) AS Nb FROM DB1_CLIENTS
UNION ALL
SELECT 'DB1 - Articles :', COUNT(*) FROM DB1_ARTICLES
UNION ALL
SELECT 'DB1 - Magasins (0-4999) :', COUNT(*) FROM DB1_MAGASINS
UNION ALL
SELECT 'DB1 - Ventes :', COUNT(*) FROM DB1_VENTES
UNION ALL
SELECT 'DB1 - Details ventes :', COUNT(*) FROM DB1_LIGNES_VENTES;

PROMPT ✅ BASE 1 (CP 0-4999) creee et remplie avec succes !
