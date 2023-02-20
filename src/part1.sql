CREATE TABLE IF NOT EXISTS peers
(
    nickname VARCHAR PRIMARY KEY,
    birthday DATE NOT NULL
);


CREATE TABLE IF NOT EXISTS tasks
(
    title       VARCHAR PRIMARY KEY,
    parent_task VARCHAR DEFAULT NULL REFERENCES tasks (title),
    max_xp      INTEGER
);


CREATE TABLE IF NOT EXISTS checks
(
    id   BIGSERIAL PRIMARY KEY,
    peer VARCHAR NOT NULL REFERENCES peers (nickname),
    task VARCHAR NOT NULL REFERENCES tasks (title),
    date DATE    NOT NULL
);


CREATE TYPE CHECK_STATUS AS ENUM ('Start', 'Success', 'Failure');

CREATE TABLE IF NOT EXISTS p2p
(
    id            BIGSERIAL PRIMARY KEY,
    check_id      BIGINT REFERENCES checks (id),
    checking_peer VARCHAR REFERENCES peers (nickname),
    state         CHECK_STATUS NOT NULL,
    time          TIME         NOT NULL,
    UNIQUE (check_id, checking_peer)
);


--Нужно как то проверять, что бы вертер ссылался только на успешные p2p проверки
CREATE TABLE IF NOT EXISTS verter
(
    id       BIGSERIAL PRIMARY KEY,
    check_id BIGINT REFERENCES checks (id),
    state    CHECK_STATUS NOT NULL,
    time     TIME         NOT NULL,
    UNIQUE (check_id, state)
);


CREATE TABLE IF NOT EXISTS transferred_points
(
    id            BIGSERIAL PRIMARY KEY,
    checking_peer VARCHAR NOT NULL REFERENCES peers (nickname),
    checked_peer  VARCHAR NOT NULL REFERENCES peers (nickname),
    points_amount INTEGER DEFAULT 1 CHECK ( points_amount > 0 )
--     UNIQUE (checking_peer, checked_peer)
);


CREATE TABLE IF NOT EXISTS friends
(
    id     BIGSERIAL PRIMARY KEY,
    peer_1 VARCHAR REFERENCES peers (nickname),
    peer_2 VARCHAR REFERENCES peers (nickname),
    UNIQUE (peer_1, peer_2)
);


--подумать как можно вставить два пира одновоременно и проверить каждого
CREATE TABLE IF NOT EXISTS recommendations
(
    id               BIGSERIAL PRIMARY KEY,
    peer             VARCHAR NOT NULL REFERENCES peers (nickname),
    recommended_peer VARCHAR NOT NULL REFERENCES peers (nickname)
);


--первое поле должно относится к удачным проверкам
--кол-во экспы не должно превышать максимальное
CREATE TABLE IF NOT EXISTS xp
(
    id        BIGSERIAL PRIMARY KEY,
    check_id  BIGINT REFERENCES checks (id) UNIQUE,
    xp_amount INTEGER CHECK ( xp_amount > 0 )
);

CREATE OR REPLACE FUNCTION fnc_xp_insert_and_update() RETURNS TRIGGER
LANGUAGE plpgsql
AS
$$
    BEGIN
        IF ((
            SELECT count(state)
            FROM p2p
            WHERE p2p.check_id = NEW.check_id
            AND p2p.state = 'Success'
            ) = 0)
            THEN RAISE EXCEPTION 'Проверка из таблица p2p не находится в состоянии Success';
        ELSEIF ((
            SELECT tasks.max_xp - NEW.xp_amount
            FROM tasks
                JOIN checks c on tasks.title = c.task
            WHERE c.id = NEW.id
                ) < 0)
            THEN RAISE EXCEPTION 'Количество xp превышает максимально допустимое';
        ELSE
            RETURN NEW;
        END IF;
    END;
$$;

CREATE TRIGGER trg_xp_multi
    BEFORE INSERT OR UPDATE
    ON xp
    FOR EACH ROW
    EXECUTE FUNCTION fnc_xp_insert_and_update();

-- INSERT INTO peers (nickname, birthday)
--     VALUES ('Karim', '2003-05-31');
-- INSERT INTO peers (nickname, birthday)
--     VALUES ('Artem', '2002-05-31');
-- INSERT INTO tasks (title, parent_task, max_xp)
--     VALUES ('42info', null, 20000);
-- INSERT INTO checks (peer, task, date)
--     VALUES ('Karim', '42info', '2022-01-01');
-- INSERT INTO p2p (check_id, checking_peer, state, time)
--     VALUES (1, 'Artem', 'Failure', '21:30');
-- INSERT INTO xp (check_id, xp_amount)
--     VALUES (1, 20000);

CREATE TABLE IF NOT EXISTS time_tracking
(
    id    BIGSERIAL PRIMARY KEY,
    peer  VARCHAR NOT NULL REFERENCES peers (nickname),
    date  DATE    NOT NULL,
    time  TIME    NOT NULL,
    state INTEGER CHECK ( state IN (1, 2) )
);

