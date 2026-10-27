-- ============================================================
-- PROJETO: GESTÃO DO 29º TROFÉU ALEXANDRE PUSSIELDI - 2025
-- SGBD: POSTGRESQL
-- MODELO ALINHADO AOS DADOS OBSERVADOS NO PORTAL FAEAL
-- ============================================================

-- ATENÇÃO: os comandos abaixo removem as tabelas do projeto para permitir
-- a reexecução integral do arquivo em um banco de testes.
DROP TABLE IF EXISTS RESULTADO CASCADE;
DROP TABLE IF EXISTS INSCRICAO CASCADE;
DROP TABLE IF EXISTS SERIE CASCADE;
DROP TABLE IF EXISTS EQUIPE_REVEZAMENTO CASCADE;
DROP TABLE IF EXISTS PROVA CASCADE;
DROP TABLE IF EXISTS ATLETA CASCADE;
DROP TABLE IF EXISTS CATEGORIA CASCADE;
DROP TABLE IF EXISTS CLUBE CASCADE;
DROP TABLE IF EXISTS ETAPA CASCADE;
DROP TABLE IF EXISTS EVENTO CASCADE;

-- ============================================================
-- 1. ESTRUTURA (DDL)
-- ============================================================

CREATE TABLE EVENTO (
    id_evento SERIAL PRIMARY KEY,
    nome_evento VARCHAR(150) NOT NULL,
    edicao INTEGER NOT NULL CHECK (edicao > 0),
    local_evento VARCHAR(150) NOT NULL,
    tipo_piscina VARCHAR(10) NOT NULL CHECK (tipo_piscina IN ('25M', '50M')),
    data_inicio DATE NOT NULL,
    data_fim DATE NOT NULL,
    taxa_individual NUMERIC(10, 2) CHECK (taxa_individual >= 0),
    taxa_revezamento NUMERIC(10, 2) CHECK (taxa_revezamento >= 0),
    CONSTRAINT uk_evento_edicao UNIQUE (nome_evento, edicao),
    CONSTRAINT ck_evento_periodo CHECK (data_fim >= data_inicio)
);

CREATE TABLE ETAPA (
    id_etapa SERIAL PRIMARY KEY,
    id_evento INTEGER NOT NULL,
    numero_etapa INTEGER NOT NULL CHECK (numero_etapa > 0),
    data_etapa DATE NOT NULL,
    horario_aquecimento TIME,
    horario_inicio TIME,
    CONSTRAINT fk_etapa_evento FOREIGN KEY (id_evento)
        REFERENCES EVENTO (id_evento) ON DELETE CASCADE,
    CONSTRAINT uk_etapa_numero UNIQUE (id_evento, numero_etapa),
    CONSTRAINT ck_etapa_horario CHECK (
        horario_inicio IS NULL
        OR horario_aquecimento IS NULL
        OR horario_inicio >= horario_aquecimento
    )
);

CREATE TABLE CLUBE (
    id_clube SERIAL PRIMARY KEY,
    sigla_clube VARCHAR(30) NOT NULL UNIQUE,
    nome_clube VARCHAR(150) NOT NULL,
    uf CHAR(2) NOT NULL CHECK (uf = UPPER(uf))
);

-- A categoria pertence à edição do evento. Assim, os anos de nascimento
-- podem mudar em outra edição sem alterar permanentemente o cadastro do atleta.
CREATE TABLE CATEGORIA (
    id_categoria SERIAL PRIMARY KEY,
    id_evento INTEGER NOT NULL,
    nome_categoria VARCHAR(50) NOT NULL,
    sigla_categoria VARCHAR(10) NOT NULL,
    ano_nascimento_inicio INTEGER NOT NULL,
    ano_nascimento_fim INTEGER NOT NULL,
    CONSTRAINT fk_categoria_evento FOREIGN KEY (id_evento)
        REFERENCES EVENTO (id_evento) ON DELETE CASCADE,
    CONSTRAINT uk_categoria_evento_nome UNIQUE (id_evento, nome_categoria),
    CONSTRAINT uk_categoria_evento_sigla UNIQUE (id_evento, sigla_categoria),
    CONSTRAINT ck_categoria_anos CHECK (
        ano_nascimento_fim >= ano_nascimento_inicio
    )
);

CREATE TABLE ATLETA (
    id_atleta SERIAL PRIMARY KEY,
    registro_cbda INTEGER NOT NULL UNIQUE CHECK (registro_cbda > 0),
    nome_atleta VARCHAR(150) NOT NULL,
    ano_nascimento INTEGER NOT NULL CHECK (ano_nascimento BETWEEN 1900 AND 2100),
    genero VARCHAR(20) NOT NULL CHECK (genero IN ('Feminino', 'Masculino')),
    id_clube INTEGER NOT NULL,
    CONSTRAINT fk_atleta_clube FOREIGN KEY (id_clube)
        REFERENCES CLUBE (id_clube) ON DELETE RESTRICT
);

-- O portal apresenta revezamentos como equipes, por exemplo "AABB RECIFE A".
-- Essas equipes não são atletas e, por isso, recebem uma tabela própria.
CREATE TABLE EQUIPE_REVEZAMENTO (
    id_equipe_revezamento SERIAL PRIMARY KEY,
    id_clube INTEGER NOT NULL,
    nome_equipe VARCHAR(100) NOT NULL,
    CONSTRAINT fk_equipe_clube FOREIGN KEY (id_clube)
        REFERENCES CLUBE (id_clube) ON DELETE RESTRICT,
    CONSTRAINT uk_equipe_clube_nome UNIQUE (id_clube, nome_equipe)
);

CREATE TABLE PROVA (
    id_prova SERIAL PRIMARY KEY,
    numero_prova INTEGER NOT NULL CHECK (numero_prova > 0),
    distancia INTEGER NOT NULL CHECK (distancia > 0),
    estilo VARCHAR(30) NOT NULL,
    genero VARCHAR(20) NOT NULL CHECK (genero IN ('Feminino', 'Masculino', 'Misto')),
    tipo_prova VARCHAR(30) NOT NULL CHECK (tipo_prova IN ('Individual', 'Revezamento')),
    status_prova VARCHAR(20) NOT NULL CHECK (status_prova IN ('FINAL', 'CONCLUÍDA')),
    id_etapa INTEGER NOT NULL,
    id_categoria INTEGER NOT NULL,
    CONSTRAINT fk_prova_etapa FOREIGN KEY (id_etapa)
        REFERENCES ETAPA (id_etapa) ON DELETE CASCADE,
    CONSTRAINT fk_prova_categoria FOREIGN KEY (id_categoria)
        REFERENCES CATEGORIA (id_categoria) ON DELETE RESTRICT,
    CONSTRAINT uk_prova_etapa UNIQUE (id_etapa, numero_prova)
);

CREATE TABLE SERIE (
    id_serie SERIAL PRIMARY KEY,
    id_prova INTEGER NOT NULL,
    numero_serie INTEGER NOT NULL CHECK (numero_serie > 0),
    fase VARCHAR(30) NOT NULL DEFAULT 'FINAL',
    horario_serie TIME,
    CONSTRAINT fk_serie_prova FOREIGN KEY (id_prova)
        REFERENCES PROVA (id_prova) ON DELETE CASCADE,
    CONSTRAINT uk_serie_prova_numero UNIQUE (id_prova, numero_serie)
);

CREATE TABLE INSCRICAO (
    id_inscricao SERIAL PRIMARY KEY,
    id_atleta INTEGER,
    id_equipe_revezamento INTEGER,
    id_prova INTEGER NOT NULL,
    id_serie INTEGER,
    raia INTEGER CHECK (raia > 0),
    tempo_balizamento INTERVAL,
    data_inscricao DATE NOT NULL,
    CONSTRAINT fk_inscricao_atleta FOREIGN KEY (id_atleta)
        REFERENCES ATLETA (id_atleta) ON DELETE CASCADE,
    CONSTRAINT fk_inscricao_equipe FOREIGN KEY (id_equipe_revezamento)
        REFERENCES EQUIPE_REVEZAMENTO (id_equipe_revezamento) ON DELETE CASCADE,
    CONSTRAINT fk_inscricao_prova FOREIGN KEY (id_prova)
        REFERENCES PROVA (id_prova) ON DELETE CASCADE,
    CONSTRAINT fk_inscricao_serie FOREIGN KEY (id_serie)
        REFERENCES SERIE (id_serie) ON DELETE SET NULL,
    CONSTRAINT ck_inscricao_participante CHECK (
        (id_atleta IS NOT NULL AND id_equipe_revezamento IS NULL)
        OR (id_atleta IS NULL AND id_equipe_revezamento IS NOT NULL)
    ),
    CONSTRAINT ck_inscricao_tempo CHECK (
        tempo_balizamento IS NULL OR tempo_balizamento >= INTERVAL '0 seconds'
    )
);

CREATE UNIQUE INDEX uk_inscricao_atleta_prova
    ON INSCRICAO (id_atleta, id_prova)
    WHERE id_atleta IS NOT NULL;

CREATE UNIQUE INDEX uk_inscricao_equipe_prova
    ON INSCRICAO (id_equipe_revezamento, id_prova)
    WHERE id_equipe_revezamento IS NOT NULL;

-- A PK compartilhada impõe a cardinalidade INSCRICAO 1 : 0..1 RESULTADO.
CREATE TABLE RESULTADO (
    id_inscricao INTEGER PRIMARY KEY,
    colocacao INTEGER CHECK (colocacao > 0),
    tempo_obtido INTERVAL,
    indice_tecnico NUMERIC(8, 2) NOT NULL DEFAULT 0 CHECK (indice_tecnico >= 0),
    pontuacao NUMERIC(7, 2) NOT NULL DEFAULT 0 CHECK (pontuacao >= 0),
    status_resultado VARCHAR(20) NOT NULL DEFAULT 'CLASSIFICADO'
        CHECK (status_resultado IN ('CLASSIFICADO', 'DQL', 'N/C')),
    CONSTRAINT fk_resultado_inscricao FOREIGN KEY (id_inscricao)
        REFERENCES INSCRICAO (id_inscricao) ON DELETE CASCADE,
    CONSTRAINT ck_resultado_tempo CHECK (
        tempo_obtido IS NULL OR tempo_obtido >= INTERVAL '0 seconds'
    ),
    CONSTRAINT ck_resultado_classificado CHECK (
        status_resultado <> 'CLASSIFICADO'
        OR (colocacao IS NOT NULL AND tempo_obtido IS NOT NULL)
    )
);

-- ============================================================
-- 2. DADOS DE EXEMPLO (DML)
-- ============================================================

INSERT INTO EVENTO (
    nome_evento, edicao, local_evento, tipo_piscina,
    data_inicio, data_fim, taxa_individual, taxa_revezamento
) VALUES (
    'Troféu Alexandre Azambuja Pussieldi', 29,
    'UFAL - Maceió/AL', '25M',
    DATE '2025-03-27', DATE '2025-03-29', 40.00, 160.00
);

INSERT INTO ETAPA (
    id_evento, numero_etapa, data_etapa, horario_aquecimento, horario_inicio
) VALUES
    (1, 1, DATE '2025-03-27', TIME '07:30', TIME '09:00'),
    (1, 2, DATE '2025-03-28', TIME '07:45', TIME '09:00'),
    (1, 3, DATE '2025-03-29', TIME '07:45', TIME '09:00');

INSERT INTO CLUBE (sigla_clube, nome_clube, uf) VALUES
    ('AABB-RECIFE', 'ASS ATL BANCO DO BRASIL-RECIFE', 'PE'),
    ('CEPE/BA', 'CLUBE DOS EMPREGADOS DA PETROBRÁS', 'BA'),
    ('FENIX/NADART/AL', 'FENIX/NADART/AL', 'AL'),
    ('AADC/AL', 'AADC - ASSOCIAÇÃO ATLÉTICA DIEGO CALADO', 'AL'),
    ('MASSAYO/STYLO/AL', 'ESPORTE CLUBE MASSAYO', 'AL');

INSERT INTO CATEGORIA (
    id_evento, nome_categoria, sigla_categoria,
    ano_nascimento_inicio, ano_nascimento_fim
) VALUES
    (1, 'Pré-Mirim', 'PM', 2017, 2018),
    (1, 'Mirim 1', 'M1', 2016, 2016),
    (1, 'Mirim 2', 'M2', 2015, 2015);

INSERT INTO ATLETA (
    registro_cbda, nome_atleta, ano_nascimento, genero, id_clube
) VALUES
    (395721, 'FRANCISCO CLEMENTE DUARTE', 2017, 'Masculino', 4),
    (410678, 'ESTER MANUELA GOMES', 2015, 'Feminino', 5),
    (376510, 'DIEGO GAMA RODRIGUES', 2015, 'Masculino', 3),
    (381020, 'MARIA ISIS BARBOSA', 2015, 'Feminino', 5);

INSERT INTO EQUIPE_REVEZAMENTO (id_clube, nome_equipe) VALUES
    (1, 'AABB RECIFE A');

INSERT INTO PROVA (
    numero_prova, distancia, estilo, genero, tipo_prova,
    status_prova, id_etapa, id_categoria
) VALUES
    (5,  50, 'Livre',     'Feminino',  'Individual',  'CONCLUÍDA', 1, 1),
    (6,  50, 'Livre',     'Masculino', 'Individual',  'CONCLUÍDA', 1, 1),
    (9,  50, 'Costas',    'Feminino',  'Individual',  'CONCLUÍDA', 1, 3),
    (12, 50, 'Borboleta', 'Masculino', 'Individual',  'CONCLUÍDA', 1, 1),
    (27, 50, 'Livre',     'Feminino',  'Individual',  'CONCLUÍDA', 2, 3),
    (28, 50, 'Livre',     'Masculino', 'Individual',  'CONCLUÍDA', 2, 3),
    (29, 200, 'Medley',   'Misto',     'Revezamento', 'CONCLUÍDA', 2, 3);

INSERT INTO SERIE (id_prova, numero_serie, fase) VALUES
    (2, 1, 'FINAL'),
    (4, 1, 'FINAL'),
    (3, 1, 'FINAL'),
    (5, 1, 'FINAL'),
    (6, 1, 'FINAL'),
    (7, 1, 'FINAL');

-- NULL representa corretamente a ausência de balizamento mostrada no portal
-- como 99:99.99, que não é um tempo válido.
INSERT INTO INSCRICAO (
    id_atleta, id_equipe_revezamento, id_prova, id_serie,
    raia, tempo_balizamento, data_inscricao
) VALUES
    (1, NULL, 2, 1, 4, NULL,                              DATE '2025-03-15'),
    (1, NULL, 4, 2, 4, NULL,                              DATE '2025-03-15'),
    (2, NULL, 3, 3, 4, INTERVAL '1 minute 3.23 seconds',  DATE '2025-03-15'),
    (2, NULL, 5, 4, 5, INTERVAL '46.08 seconds',          DATE '2025-03-15'),
    (3, NULL, 6, 5, 4, INTERVAL '35.87 seconds',          DATE '2025-03-15'),
    (NULL, 1, 7, 6, 2, INTERVAL '3 minutes 36.20 seconds', DATE '2025-03-15');

INSERT INTO RESULTADO (
    id_inscricao, colocacao, tempo_obtido,
    indice_tecnico, pontuacao, status_resultado
) VALUES
    (5, 1, INTERVAL '34.40 seconds', 250.00, 25.00, 'CLASSIFICADO'),
    (4, 2, INTERVAL '45.10 seconds', 220.00, 22.00, 'CLASSIFICADO'),
    (6, 1, INTERVAL '3 minutes 36.80 seconds', 0.00, 50.00, 'CLASSIFICADO');

-- ============================================================
-- 3. CONSULTA FINAL
-- ============================================================

SELECT
    COALESCE(a.nome_atleta, er.nome_equipe) AS participante,
    CASE
        WHEN a.id_atleta IS NOT NULL THEN 'Atleta'
        ELSE 'Equipe de revezamento'
    END AS tipo_participante,
    a.ano_nascimento,
    c.sigla_clube AS clube,
    cat.nome_categoria AS categoria,
    p.numero_prova,
    CONCAT(p.distancia, 'm ', p.estilo, ' ', p.genero) AS prova,
    s.numero_serie,
    i.raia,
    i.tempo_balizamento,
    r.colocacao,
    r.status_resultado,
    r.tempo_obtido,
    r.indice_tecnico,
    r.pontuacao
FROM INSCRICAO AS i
LEFT JOIN ATLETA AS a
    ON a.id_atleta = i.id_atleta
LEFT JOIN EQUIPE_REVEZAMENTO AS er
    ON er.id_equipe_revezamento = i.id_equipe_revezamento
INNER JOIN CLUBE AS c
    ON c.id_clube = COALESCE(a.id_clube, er.id_clube)
INNER JOIN PROVA AS p
    ON p.id_prova = i.id_prova
INNER JOIN CATEGORIA AS cat
    ON cat.id_categoria = p.id_categoria
LEFT JOIN SERIE AS s
    ON s.id_serie = i.id_serie
LEFT JOIN RESULTADO AS r
    ON r.id_inscricao = i.id_inscricao
ORDER BY
    participante,
    p.numero_prova;
