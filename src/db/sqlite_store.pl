:- module(sqlite_store, [
    init/0,

    create_user/5,
    find_user_by_email/2,
    find_user_by_id/2,
    mark_user_verified/1,

    save_email_verification/4,
    consume_email_verification/2,
    save_auth_session/4,
    find_user_id_by_session_token_hash/2,
    revoke_auth_session/1,

    save_agent/5,
    get_agent/2,
    list_agents/1,
    delete_agent/1,
    update_agent_source/2,

    save_match/5,
    create_pending_match/4,
    update_match_status/2,
    finalize_match/3,
    mark_match_failed/2,
    list_matches_by_status/2,
    get_match/2,
    list_matches/1
]).

:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(prolog_pack)).
:- use_module(library(uuid)).
:- use_module('../config').

%!  conn_alias(-Alias) is det.
%
%   Alias lógico usado para a conexão SQLite compartilhada.
conn_alias(agents_db).

%!  init is det.
%
%   Inicializa dependência `prosqlite`, conexão e migrações de schema.
init :-
    ensure_prosqlite,
    ensure_connected,
    migrate.

%!  ensure_prosqlite is det.
%
%   Garante que o pacote `prosqlite` está disponível para uso.
ensure_prosqlite :-
    ensure_local_prosqlite_pack,
    ensure_prosqlite_loaded,
    require_prosqlite.

%!  require_prosqlite is semidet.
%
%   Confirma que `prosqlite` foi carregado; lança erro caso contrário.
require_prosqlite :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
require_prosqlite :-
    throw(error(existence_error(package, prosqlite), _)).

%!  ensure_prosqlite_loaded is det.
%
%   Carrega `library(prosqlite)` quando ainda não está no runtime.
ensure_prosqlite_loaded :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
ensure_prosqlite_loaded :-
    catch(use_module(library(prosqlite), []), _, fail),
    !.
ensure_prosqlite_loaded :-
    local_prosqlite_module_file(ModuleFile),
    exists_file(ModuleFile),
    use_module(ModuleFile, []).

%!  ensure_local_prosqlite_pack is det.
%
%   Anexa pacote local `packs/prosqlite` quando presente.
ensure_local_prosqlite_pack :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
ensure_local_prosqlite_pack :-
    local_prosqlite_pack_dir(PackDir),
    exists_directory(PackDir),
    !,
    catch(pack_attach(PackDir, [duplicate(replace)]), _, true).
ensure_local_prosqlite_pack.

%!  local_prosqlite_pack_dir(-PackDir) is det.
%
%   Resolve caminho absoluto do pacote local `prosqlite`.
local_prosqlite_pack_dir(PackDir) :-
    source_file(sqlite_store:init, ThisFile),
    file_directory_name(ThisFile, DbDir),
    file_directory_name(DbDir, SrcDir),
    file_directory_name(SrcDir, ProjectDir),
    directory_file_path(ProjectDir, 'packs/prosqlite', PackDir).

%!  local_prosqlite_module_file(-ModuleFile) is det.
%
%   Resolve caminho absoluto do módulo principal `prosqlite.pl`.
local_prosqlite_module_file(ModuleFile) :-
    local_prosqlite_pack_dir(PackDir),
    directory_file_path(PackDir, 'prolog/prosqlite.pl', ModuleFile).

%!  ensure_connected is det.
%
%   Abre conexão SQLite (se necessário) usando alias configurado.
ensure_connected :-
    ensure_prosqlite,
    conn_alias(Alias),
    ensure_connection_open(Alias).

%!  ensure_connection_open(+Alias) is det.
%
%   Abre a conexão SQLite quando ainda não há uma pronta para o alias.
ensure_connection_open(Alias) :-
    sqlite_connection_ready(Alias),
    !.
ensure_connection_open(Alias) :-
    config:db_path(DbPath),
    file_directory_name(DbPath, Dir),
    make_directory_path(Dir),
    prosqlite:sqlite_connect(DbPath, Alias, [alias(Alias), exists(false), ext('')]).

%!  sqlite_connection_ready(+Alias) is semidet.
%
%   Verifica se a conexão alias já está aberta.
sqlite_connection_ready(Alias) :-
    current_predicate(prosqlite:sqlite_current_connection/1),
    prosqlite:sqlite_current_connection(Alias).

%!  migrate is det.
%
%   Cria tabelas necessárias quando ainda não existem.
migrate :-
    sql_exec("CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        username TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        is_verified INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS email_verifications (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        used_at TEXT
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS auth_sessions (
        token_hash TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        revoked_at TEXT
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS agents (
        id TEXT PRIMARY KEY,
        owner_user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        source_text TEXT NOT NULL,
        created_at TEXT NOT NULL
    );"),
    sql_exec("CREATE TABLE IF NOT EXISTS matches (
        id TEXT PRIMARY KEY,
        thief_agent_id TEXT NOT NULL,
        detective_agent_id TEXT NOT NULL,
        scenario TEXT,
        winner TEXT,
        replay_json TEXT,
        status TEXT,
        created_at TEXT NOT NULL,
        started_at TEXT,
        finished_at TEXT
    );"),
    migrate_users_columns,
    migrate_matches_columns.

%!  migrate_users_columns is det.
%
%   Adiciona colunas novas de usuario em bancos criados antes do perfil ter
%   nome de usuario.
migrate_users_columns :-
    catch(sql_exec("ALTER TABLE users ADD COLUMN username TEXT;"), _, true).

%!  migrate_matches_columns is det.
%
%   Adiciona as colunas do fluxo assincrono (subprocessos + fila) em bancos
%   antigos, criados antes da Fase 1, quando `matches` so tinha o resultado
%   final. `ALTER TABLE ... ADD COLUMN` falha se a coluna ja existe, dai o
%   `catch` para manter a migracao idempotente.
migrate_matches_columns :-
    forall(member(Def, ["scenario TEXT", "status TEXT",
                        "started_at TEXT", "finished_at TEXT"]),
           ( format(string(SQL), "ALTER TABLE matches ADD COLUMN ~s;", [Def]),
             catch(sql_exec(SQL), _, true) )).

%!  sql_exec(+SQL) is det.
%
%   Executa comando SQL descartando linhas de retorno.
sql_exec(SQL) :-
    conn_alias(Alias),
    findall(Row, prosqlite:sqlite_query(Alias, SQL, Row), _Rows).

%!  create_user(+Username, +Email, +PasswordHash, -UserId, -CreatedAt) is det.
%
%   Cria usuário e retorna identificador e timestamp de criação.
create_user(Username, Email, PasswordHash, UserId, CreatedAt) :-
    ensure_connected,
    uuid(UserUuid),
    atom_string(UserUuid, UserId),
    timestamp_iso(CreatedAt),
    sql_quote(Username, QUsername),
    sql_quote(Email, QEmail),
    sql_quote(PasswordHash, QPwd),
    sql_quote(UserId, QId),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
           "INSERT INTO users(id, username, email, password_hash, is_verified, created_at) VALUES(~s, ~s, ~s, ~s, 0, ~s);",
           [QId, QUsername, QEmail, QPwd, QCreated]),
    sql_exec(SQL).

%!  find_user_by_email(+Email, -User) is semidet.
%
%   Busca usuário por email.
find_user_by_email(Email, User) :-
    ensure_connected,
    sql_quote(Email, QEmail),
    format(string(SQL),
           "SELECT id, username, email, password_hash, is_verified, created_at FROM users WHERE email = ~s LIMIT 1;",
           [QEmail]),
    user_from_query(SQL, User).

%!  find_user_by_id(+UserId, -User) is semidet.
%
%   Busca usuário por identificador.
find_user_by_id(UserId, User) :-
    ensure_connected,
    sql_quote(UserId, QUserId),
    format(string(SQL),
           "SELECT id, username, email, password_hash, is_verified, created_at FROM users WHERE id = ~s LIMIT 1;",
           [QUserId]),
    user_from_query(SQL, User).

%!  user_from_query(+SQL, -User) is semidet.
%
%   Materializa um usuário (dict) a partir de query SQL.
user_from_query(SQL, User) :-
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, row(Id, Username0, E, Hash, VerifiedInt, CreatedAt))),
    bool_int(BoolVerified, VerifiedInt),
    user_username(Username0, E, Username),
    User = _{
        id: Id,
        username: Username,
        email: E,
        password_hash: Hash,
        is_verified: BoolVerified,
        created_at: CreatedAt
    }.

user_username(Username0, Email, Username) :-
    norm_optional(Username0, Username1),
    ( Username1 == ""
    -> Username = Email
    ;  Username = Username1
    ).

%!  mark_user_verified(+UserId) is det.
%
%   Marca usuário como verificado.
mark_user_verified(UserId) :-
    ensure_connected,
    sql_quote(UserId, QUserId),
    format(string(SQL), "UPDATE users SET is_verified = 1 WHERE id = ~s;", [QUserId]),
    sql_exec(SQL).

%!  save_email_verification(+TokenHash, +UserId, +ExpiresAt, +CreatedAt) is det.
%
%   Persiste token de verificação de email.
save_email_verification(TokenHash, UserId, ExpiresAt, _CreatedAt) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    sql_quote(UserId, QUser),
    sql_quote(ExpiresAt, QExp),
    format(string(SQL),
           "INSERT OR REPLACE INTO email_verifications(token_hash, user_id, expires_at, used_at) VALUES(~s, ~s, ~s, NULL);",
           [QToken, QUser, QExp]),
    sql_exec(SQL).

%!  consume_email_verification(+TokenHash, -UserId) is semidet.
%
%   Consome token válido/ativo e retorna `UserId` associado.
consume_email_verification(TokenHash, UserId) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    conn_alias(Alias),
    format(string(SelectSQL),
           "SELECT user_id, expires_at, used_at FROM email_verifications WHERE token_hash = ~s LIMIT 1;",
           [QToken]),
    once(prosqlite:sqlite_query(Alias, SelectSQL, row(UserId, ExpiresAt, UsedAt))),
    UsedAt == '$null$',
    timestamp_iso(Now),
    ExpiresAt @> Now,
    sql_quote(Now, QNow),
    format(string(UpdateSQL),
           "UPDATE email_verifications SET used_at = ~s WHERE token_hash = ~s;",
           [QNow, QToken]),
    sql_exec(UpdateSQL).

%!  save_auth_session(+TokenHash, +UserId, +ExpiresAt, +CreatedAt) is det.
%
%   Persiste sessão autenticada.
save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    sql_quote(UserId, QUser),
    sql_quote(ExpiresAt, QExp),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
           "INSERT OR REPLACE INTO auth_sessions(token_hash, user_id, expires_at, created_at, revoked_at) VALUES(~s, ~s, ~s, ~s, NULL);",
           [QToken, QUser, QExp, QCreated]),
    sql_exec(SQL).

%!  find_user_id_by_session_token_hash(+TokenHash, -UserId) is semidet.
%
%   Resolve usuário de sessão ativa (não revogada e não expirada).
find_user_id_by_session_token_hash(TokenHash, UserId) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    conn_alias(Alias),
    format(string(SelectSQL),
           "SELECT user_id, expires_at, revoked_at FROM auth_sessions WHERE token_hash = ~s LIMIT 1;",
           [QToken]),
    once(prosqlite:sqlite_query(Alias, SelectSQL, row(UserId, ExpiresAt, RevokedAt))),
    RevokedAt == '$null$',
    timestamp_iso(Now),
    ExpiresAt @> Now.

%!  revoke_auth_session(+TokenHash) is det.
%
%   Marca uma sessao como revogada, invalidando o token associado.
revoke_auth_session(TokenHash) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    timestamp_iso(Now),
    sql_quote(Now, QNow),
    format(string(SQL),
           "UPDATE auth_sessions SET revoked_at = ~s WHERE token_hash = ~s;",
           [QNow, QToken]),
    sql_exec(SQL).

%!  save_agent(+OwnerUserId, +Name, +Role, +SourceText, -AgentId) is det.
%
%   Persiste agente e retorna `AgentId`. O DB e o source-of-truth; o
%   `source_text` eh o codigo Prolog completo do agente.
save_agent(OwnerUserId, Name, Role, SourceText, AgentId) :-
    ensure_connected,
    uuid(Uuid),
    atom_string(Uuid, AgentId),
    timestamp_iso(CreatedAt),
    sql_quote(AgentId, QId),
    sql_quote(OwnerUserId, QOwner),
    sql_quote(Name, QName),
    sql_quote(Role, QRole),
    sql_quote(SourceText, QSource),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
        "INSERT INTO agents(id, owner_user_id, name, role, source_text, created_at) VALUES(~s, ~s, ~s, ~s, ~s, ~s);",
        [QId, QOwner, QName, QRole, QSource, QCreated]),
    sql_exec(SQL).

%!  get_agent(+AgentId, -Agent) is semidet.
%
%   Busca agente por ID, incluindo o `source_text` (necessario para
%   materializar o agente no cache do filesystem antes do match).
get_agent(AgentId, Agent) :-
    ensure_connected,
    sql_quote(AgentId, QAgentId),
    format(string(SQL),
      "SELECT id, owner_user_id, name, role, source_text, created_at FROM agents WHERE id = ~s LIMIT 1;",
      [QAgentId]),
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, row(Id, Owner, Name, Role, Source, CreatedAt))),
    Agent = _{
      id: Id,
      owner_user_id: Owner,
      name: Name,
      role: Role,
      source_text: Source,
      created_at: CreatedAt
    }.

%!  list_agents(-Agents) is det.
%
%   Lista agentes (metadados) em ordem decrescente de criacao. NAO inclui
%   `source_text` para manter a listagem leve.
list_agents(Agents) :-
    ensure_connected,
    conn_alias(Alias),
    findall(_{
        id: Id,
        owner_user_id: Owner,
        name: Name,
        role: Role,
        created_at: CreatedAt
    },
    prosqlite:sqlite_query(Alias,
      "SELECT id, owner_user_id, name, role, created_at FROM agents ORDER BY created_at DESC;",
      row(Id, Owner, Name, Role, CreatedAt)),
    Agents).

%!  delete_agent(+AgentId) is det.
%
%   Remove o agente do banco. O cache em disco eh responsabilidade do
%   chamador (engine/agent_cache).
delete_agent(AgentId) :-
    ensure_connected,
    sql_quote(AgentId, QId),
    format(string(SQL), "DELETE FROM agents WHERE id = ~s;", [QId]),
    sql_exec(SQL).

%!  update_agent_source(+AgentId, +SourceText) is det.
%
%   Atualiza o codigo do agente. O cache em disco fica obsoleto e deve
%   ser invalidado/regravado pelo chamador na próxima execucao.
update_agent_source(AgentId, SourceText) :-
    ensure_connected,
    sql_quote(AgentId, QId),
    sql_quote(SourceText, QSource),
    format(string(SQL),
        "UPDATE agents SET source_text = ~s WHERE id = ~s;",
        [QSource, QId]),
    sql_exec(SQL).

%!  save_match(+ThiefAgentId, +DetectiveAgentId, +Winner, +ReplayJson, -MatchId) is det.
%
%   Persiste uma partida executada e retorna `MatchId`.
save_match(ThiefAgentId, DetectiveAgentId, Winner, ReplayJson, MatchId) :-
    ensure_connected,
    uuid(Uuid),
    atom_string(Uuid, MatchId),
    timestamp_iso(CreatedAt),
    sql_quote(MatchId, QId),
    sql_quote(ThiefAgentId, QT),
    sql_quote(DetectiveAgentId, QD),
    sql_quote(Winner, QW),
    sql_quote(ReplayJson, QR),
    sql_quote(CreatedAt, QC),
    format(string(SQL),
      "INSERT INTO matches(id, thief_agent_id, detective_agent_id, winner, replay_json, created_at) VALUES(~s, ~s, ~s, ~s, ~s, ~s);",
      [QId, QT, QD, QW, QR, QC]),
    sql_exec(SQL).

%!  create_pending_match(+ThiefAgentId, +DetectiveAgentId, +Scenario, -MatchId) is det.
%
%   Cria a linha da partida JA no enfileiramento, com `status='queued'` e sem
%   resultado. O `winner`/`replay_json` sao preenchidos por `finalize_match/3`
%   quando o subprocesso termina. O MatchId e um atomo (chave usada tambem como
%   id de job em memoria e na URL /matches/<id>).
create_pending_match(ThiefAgentId, DetectiveAgentId, Scenario, MatchId) :-
    ensure_connected,
    uuid(MatchId),
    timestamp_iso(CreatedAt),
    sql_quote(MatchId, QId),
    sql_quote(ThiefAgentId, QT),
    sql_quote(DetectiveAgentId, QD),
    sql_quote(Scenario, QS),
    sql_quote(CreatedAt, QC),
    format(string(SQL),
      "INSERT INTO matches(id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at) VALUES(~s, ~s, ~s, ~s, '', '', 'queued', ~s, NULL, NULL);",
      [QId, QT, QD, QS, QC]),
    sql_exec(SQL).

%!  update_match_status(+MatchId, +Status) is det.
%
%   Atualiza o status da partida. Ao passar para `running`, grava `started_at`.
update_match_status(MatchId, Status) :-
    ensure_connected,
    sql_quote(MatchId, QId),
    sql_quote(Status, QStatus),
    ( Status == "running"
    ->  timestamp_iso(Now),
        sql_quote(Now, QNow),
        format(string(SQL),
               "UPDATE matches SET status = ~s, started_at = ~s WHERE id = ~s;",
               [QStatus, QNow, QId])
    ;   format(string(SQL),
               "UPDATE matches SET status = ~s WHERE id = ~s;",
               [QStatus, QId])
    ),
    sql_exec(SQL).

%!  finalize_match(+MatchId, +Winner, +ReplayJson) is det.
%
%   Grava o resultado final (winner + replay), marca `status='done'` e
%   `finished_at`.
finalize_match(MatchId, Winner, ReplayJson) :-
    ensure_connected,
    timestamp_iso(Now),
    sql_quote(MatchId, QId),
    sql_quote(Winner, QW),
    sql_quote(ReplayJson, QR),
    sql_quote(Now, QF),
    format(string(SQL),
      "UPDATE matches SET winner = ~s, replay_json = ~s, status = 'done', finished_at = ~s WHERE id = ~s;",
      [QW, QR, QF, QId]),
    sql_exec(SQL).

%!  mark_match_failed(+MatchId, +Status) is det.
%
%   Marca uma partida como `error` ou `timeout` e grava `finished_at`.
mark_match_failed(MatchId, Status) :-
    ensure_connected,
    timestamp_iso(Now),
    sql_quote(MatchId, QId),
    sql_quote(Status, QStatus),
    sql_quote(Now, QF),
    format(string(SQL),
      "UPDATE matches SET status = ~s, finished_at = ~s WHERE id = ~s;",
      [QStatus, QF, QId]),
    sql_exec(SQL).

%!  list_matches_by_status(+Statuses, -Matches) is det.
%
%   Lista partidas cujo status esta em `Statuses` (lista de strings), em ordem
%   crescente de criacao. Usado para re-enfileirar pendentes apos restart.
list_matches_by_status(Statuses, Matches) :-
    ensure_connected,
    conn_alias(Alias),
    maplist(sql_quote, Statuses, Quoted),
    atomic_list_concat(Quoted, ',', InList),
    format(string(SQL),
      "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches WHERE status IN (~w) ORDER BY created_at ASC;",
      [InList]),
    findall(Match, ( prosqlite:sqlite_query(Alias, SQL, Row), match_row_dict(Row, Match) ), Matches).

%!  get_match(+MatchId, -Match) is semidet.
%
%   Busca uma partida por ID.
get_match(MatchId, Match) :-
    ensure_connected,
    sql_quote(MatchId, QId),
    format(string(SQL),
      "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches WHERE id = ~s LIMIT 1;",
      [QId]),
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, Row)),
    match_row_dict(Row, Match).

%!  list_matches(-Matches) is det.
%
%   Lista partidas em ordem decrescente de criação.
list_matches(Matches) :-
    ensure_connected,
    conn_alias(Alias),
    findall(Match,
      ( prosqlite:sqlite_query(Alias,
          "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches ORDER BY created_at DESC;",
          Row),
        match_row_dict(Row, Match) ),
      Matches).

%!  match_row_dict(+Row, -Match) is det.
%
%   Materializa o dict de uma partida a partir da linha SQL. Normaliza colunas
%   que podem vir NULL (partidas antigas, anteriores ao fluxo assincrono) ou
%   como atomo (driver prosqlite): `status` ausente vira "done" (partida ja
%   concluida no modelo antigo), demais textos opcionais viram "".
match_row_dict(row(Id, Thief, Detective, Scenario, Winner, Replay, Status,
                   CreatedAt, StartedAt, FinishedAt),
               Match) :-
    norm_status(Status, StatusT),
    norm_optional(Scenario, ScenarioT),
    norm_optional(StartedAt, StartedT),
    norm_optional(FinishedAt, FinishedT),
    Match = _{
        id: Id,
        thief_agent_id: Thief,
        detective_agent_id: Detective,
        scenario: ScenarioT,
        winner: Winner,
        replay_json: Replay,
        status: StatusT,
        created_at: CreatedAt,
        started_at: StartedT,
        finished_at: FinishedT
    }.

%!  norm_status(+Raw, -Status) is det.
norm_status(Raw, "done") :- ( Raw == '$null$' ; Raw == '' ; Raw == "" ), !.
norm_status(Raw, Status) :- to_text(Raw, Status).

%!  norm_optional(+Raw, -Text) is det.
norm_optional(Raw, "") :- Raw == '$null$', !.
norm_optional(Raw, Text) :- to_text(Raw, Text).

%!  to_text(+Raw, -String) is det.
to_text(Raw, Raw) :- string(Raw), !.
to_text(Raw, S) :- atom(Raw), !, atom_string(Raw, S).
to_text(Raw, S) :- format(string(S), "~w", [Raw]).

%!  bool_int(?Bool, ?Int) is nondet.
%
%   Converte representação booleana para inteiro de banco e vice-versa.
bool_int(true, 1).
bool_int(false, 0).
bool_int(false, '$null$').

%!  timestamp_iso(-Iso) is det.
%
%   Retorna timestamp UTC corrente em ISO-8601.
timestamp_iso(Iso) :-
    get_time(Now),
    format_time(string(Iso), '%FT%TZ', Now).

%!  sql_quote(+Input, -Quoted) is det.
%
%   Escapa string para uso seguro em SQL textual.
sql_quote(Input, Quoted) :-
    string_codes(Input, Codes),
    phrase(sql_escaped(Codes), EscapedCodes),
    string_codes(Escaped, EscapedCodes),
    format(string(Quoted), "'~s'", [Escaped]).

%!  sql_escaped(+Codes)// is det.
%
%   DCG para escape de aspas simples na serialização SQL.
sql_escaped([]) --> [].
sql_escaped([39|Rest]) --> "''", sql_escaped(Rest).
sql_escaped([C|Rest]) --> [C], sql_escaped(Rest).

% Eager-load do pacote prosqlite no carregamento deste modulo. Sem isso o
% `check/0` reclama de prosqlite:sqlite_*/N porque o pack so seria atachado
% lazy via init/0. Erros sao engolidos para nao quebrar build se o pack
% estiver ausente; ai a falha vira no momento do uso real.
:- catch(ensure_prosqlite, _, true).
