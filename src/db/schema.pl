:- module(db_schema, [
    migrate/0
]).

:- use_module(connection).

%!  migrate is det.
%
%   Cria as tabelas (idempotente) e aplica as migracoes de colunas.
migrate :-
    sql_exec("CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        is_verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS email_verifications (
        token_hash TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        expires_at TEXT NOT NULL,
        used_at TEXT
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS auth_sessions (
        token_hash TEXT PRIMARY KEY,
        user_id INTEGER NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        revoked_at TEXT
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS agents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        owner_user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        source_text TEXT NOT NULL,
        is_private INTEGER NOT NULL DEFAULT 0,
        deleted_at TEXT,
        created_at TEXT NOT NULL
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        thief_agent_id INTEGER NOT NULL,
        detective_agent_id INTEGER NOT NULL,
        scenario TEXT,
        winner TEXT,
        replay_json TEXT,
        status TEXT,
        created_at TEXT NOT NULL,
        started_at TEXT,
        finished_at TEXT
    );"),
    migrate_users_columns,
    migrate_agents_columns,
    migrate_matches_columns.

migrate_users_columns :-
    catch(sql_exec("ALTER TABLE users ADD COLUMN username TEXT;"), _, true),
    catch(sql_exec("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'user';"), _, true).

migrate_agents_columns :-
    catch(sql_exec("ALTER TABLE agents ADD COLUMN is_private INTEGER NOT NULL DEFAULT 0;"), _, true),
    catch(sql_exec("ALTER TABLE agents ADD COLUMN deleted_at TEXT;"), _, true).

% Colunas do fluxo assincrono (fila + subprocessos) em bancos antigos, quando
% `matches` so tinha o resultado final. `ADD COLUMN` falha se ela já existe,
% dai o `catch` por coluna para manter a migracao idempotente.
migrate_matches_columns :-
    forall(member(Def, ["scenario TEXT", "status TEXT",
                        "started_at TEXT", "finished_at TEXT"]),
           ( format(string(SQL), "ALTER TABLE matches ADD COLUMN ~s;", [Def]),
             catch(sql_exec(SQL), _, true) )).
