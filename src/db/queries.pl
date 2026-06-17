:- module(db_queries, [
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
    save_agent/6,
    get_agent/2,
    list_agents/1,
    list_agents_page/4,
    delete_agent/1,
    update_agent_source/2,

    save_match/5,
    create_pending_match/4,
    update_match_status/2,
    finalize_match/3,
    mark_match_failed/2,
    list_matches_by_status/2,
    get_match/2,
    list_matches/1,
    list_matches_page/4
]).

:- use_module(connection).

create_user(Username, Email, PasswordHash, UserId, CreatedAt) :-
    ensure_connected,
    timestamp_iso(CreatedAt),
    sql_quote(Username, QUsername),
    sql_quote(Email, QEmail),
    sql_quote(PasswordHash, QPwd),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
           "INSERT INTO users(username, email, password_hash, is_verified, created_at) VALUES(~s, ~s, ~s, 0, ~s);",
           [QUsername, QEmail, QPwd, QCreated]),
    sql_exec(SQL),
    last_insert_id(UserId).

find_user_by_email(Email, User) :-
    ensure_connected,
    sql_quote(Email, QEmail),
    format(string(SQL),
           "SELECT id, username, email, password_hash, is_verified, created_at FROM users WHERE email = ~s LIMIT 1;",
           [QEmail]),
    user_from_query(SQL, User).

find_user_by_id(UserId, User) :-
    ensure_connected,
    sql_literal(UserId, QUserId),
    format(string(SQL),
           "SELECT id, username, email, password_hash, is_verified, created_at FROM users WHERE id = ~s LIMIT 1;",
           [QUserId]),
    user_from_query(SQL, User).

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

% Usuarios criados antes da coluna `username` caem de volta para o email.
user_username(Username0, Email, Username) :-
    norm_optional(Username0, Username1),
    ( Username1 == ""
    -> Username = Email
    ;  Username = Username1
    ).

mark_user_verified(UserId) :-
    ensure_connected,
    sql_literal(UserId, QUserId),
    format(string(SQL), "UPDATE users SET is_verified = 1 WHERE id = ~s;", [QUserId]),
    sql_exec(SQL).

save_email_verification(TokenHash, UserId, ExpiresAt, _CreatedAt) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    sql_literal(UserId, QUser),
    sql_quote(ExpiresAt, QExp),
    format(string(SQL),
           "INSERT OR REPLACE INTO email_verifications(token_hash, user_id, expires_at, used_at) VALUES(~s, ~s, ~s, NULL);",
           [QToken, QUser, QExp]),
    sql_exec(SQL).

%!  consume_email_verification(+TokenHash, -UserId) is semidet.
%
%   So consome o token se ele ainda nao foi usado e nao expirou; marca como
%   usado na mesma chamada (uso unico).
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

save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt) :-
    ensure_connected,
    sql_quote(TokenHash, QToken),
    sql_literal(UserId, QUser),
    sql_quote(ExpiresAt, QExp),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
           "INSERT OR REPLACE INTO auth_sessions(token_hash, user_id, expires_at, created_at, revoked_at) VALUES(~s, ~s, ~s, ~s, NULL);",
           [QToken, QUser, QExp, QCreated]),
    sql_exec(SQL).

%!  find_user_id_by_session_token_hash(+TokenHash, -UserId) is semidet.
%
%   Resolve o usuario apenas de sessao ativa: nao revogada e nao expirada.
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
%   Compatibilidade: agentes criados por chamadores antigos sao publicos.
save_agent(OwnerUserId, Name, Role, SourceText, AgentId) :-
    save_agent(OwnerUserId, Name, Role, SourceText, false, AgentId).

%!  save_agent(+OwnerUserId, +Name, +Role, +SourceText, +IsPrivate, -AgentId) is det.
%
%   O DB e o source-of-truth: `source_text` guarda o codigo Prolog completo do
%   agente, materializado no cache do filesystem so na hora do match.
save_agent(OwnerUserId, Name, Role, SourceText, IsPrivate, AgentId) :-
    ensure_connected,
    timestamp_iso(CreatedAt),
    bool_int(IsPrivate, PrivateInt),
    sql_literal(OwnerUserId, QOwner),
    sql_quote(Name, QName),
    sql_quote(Role, QRole),
    sql_quote(SourceText, QSource),
    sql_quote(CreatedAt, QCreated),
    format(string(SQL),
        "INSERT INTO agents(owner_user_id, name, role, source_text, is_private, created_at) VALUES(~s, ~s, ~s, ~s, ~w, ~s);",
        [QOwner, QName, QRole, QSource, PrivateInt, QCreated]),
    sql_exec(SQL),
    last_insert_id(AgentId).

% Inclui `source_text` (diferente de list_agents/1) para materializar o cache.
get_agent(AgentId, Agent) :-
    ensure_connected,
    sql_literal(AgentId, QAgentId),
    format(string(SQL),
      "SELECT id, owner_user_id, name, role, source_text, is_private, created_at FROM agents WHERE id = ~s LIMIT 1;",
      [QAgentId]),
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, row(Id, Owner, Name, Role, Source, PrivateInt, CreatedAt))),
    bool_int(IsPrivate, PrivateInt),
    Agent = _{
      id: Id,
      owner_user_id: Owner,
      name: Name,
      role: Role,
      source_text: Source,
      is_private: IsPrivate,
      created_at: CreatedAt
    }.

% Metadados em ordem decrescente de criacao; sem `source_text` (listagem leve).
list_agents(Agents) :-
    ensure_connected,
    conn_alias(Alias),
    findall(_{
        id: Id,
        owner_user_id: Owner,
        name: Name,
        role: Role,
        created_at: CreatedAt,
        is_private: IsPrivate
    },
    ( prosqlite:sqlite_query(Alias,
        "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents ORDER BY created_at DESC;",
        row(Id, Owner, Name, Role, CreatedAt, PrivateInt)),
      bool_int(IsPrivate, PrivateInt)
    ),
    Agents).

%!  list_agents_page(+Cursor, +Limit, -Agents, -NextCursor) is det.
%
%   Lista agentes por cursor, em ordem decrescente de criacao. `Cursor` tem
%   formato opaco `created_at|id`, vindo do ultimo item da pagina anterior.
list_agents_page(Cursor, Limit, Agents, NextCursor) :-
    ensure_connected,
    conn_alias(Alias),
    PageLimit is Limit + 1,
    cursor_where(Cursor, Where),
    format(string(SQL),
      "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents ~w ORDER BY created_at DESC, id DESC LIMIT ~w;",
      [Where, PageLimit]),
    findall(_{
        id: Id,
        owner_user_id: Owner,
        name: Name,
        role: Role,
        created_at: CreatedAt,
        is_private: IsPrivate
    },
    ( prosqlite:sqlite_query(Alias, SQL, row(Id, Owner, Name, Role, CreatedAt, PrivateInt)),
      bool_int(IsPrivate, PrivateInt)
    ),
    Rows),
    page_items_and_cursor(Rows, Limit, Agents, NextCursor).

% Remove so do banco; invalidar o cache em disco e do chamador (agent_cache).
delete_agent(AgentId) :-
    ensure_connected,
    sql_literal(AgentId, QId),
    format(string(SQL), "DELETE FROM agents WHERE id = ~s;", [QId]),
    sql_exec(SQL).

% Deixa o cache em disco obsoleto; o chamador regrava na proxima execucao.
update_agent_source(AgentId, SourceText) :-
    ensure_connected,
    sql_literal(AgentId, QId),
    sql_quote(SourceText, QSource),
    format(string(SQL),
        "UPDATE agents SET source_text = ~s WHERE id = ~s;",
        [QSource, QId]),
    sql_exec(SQL).

save_match(ThiefAgentId, DetectiveAgentId, Winner, ReplayJson, MatchId) :-
    ensure_connected,
    timestamp_iso(CreatedAt),
    sql_literal(ThiefAgentId, QT),
    sql_literal(DetectiveAgentId, QD),
    sql_quote(Winner, QW),
    sql_quote(ReplayJson, QR),
    sql_quote(CreatedAt, QC),
    format(string(SQL),
      "INSERT INTO matches(thief_agent_id, detective_agent_id, winner, replay_json, created_at) VALUES(~s, ~s, ~s, ~s, ~s);",
      [QT, QD, QW, QR, QC]),
    sql_exec(SQL),
    last_insert_id(MatchId).

%!  create_pending_match(+ThiefAgentId, +DetectiveAgentId, +Scenario, -MatchId) is det.
%
%   Cria a linha da partida JA no enfileiramento (`status='queued'`, sem
%   resultado); `winner`/`replay_json` sao preenchidos por finalize_match/3
%   quando o subprocesso termina. O MatchId e usado tambem como id de job em
%   memoria e na URL /matches/<id>.
create_pending_match(ThiefAgentId, DetectiveAgentId, Scenario, MatchId) :-
    ensure_connected,
    timestamp_iso(CreatedAt),
    sql_literal(ThiefAgentId, QT),
    sql_literal(DetectiveAgentId, QD),
    sql_quote(Scenario, QS),
    sql_quote(CreatedAt, QC),
    format(string(SQL),
      "INSERT INTO matches(thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at) VALUES(~s, ~s, ~s, '', '', 'queued', ~s, NULL, NULL);",
      [QT, QD, QS, QC]),
    sql_exec(SQL),
    last_insert_id(MatchId).

% Ao passar para "running", grava tambem `started_at`.
update_match_status(MatchId, Status) :-
    ensure_connected,
    sql_literal(MatchId, QId),
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

finalize_match(MatchId, Winner, ReplayJson) :-
    ensure_connected,
    timestamp_iso(Now),
    sql_literal(MatchId, QId),
    sql_quote(Winner, QW),
    sql_quote(ReplayJson, QR),
    sql_quote(Now, QF),
    format(string(SQL),
      "UPDATE matches SET winner = ~s, replay_json = ~s, status = 'done', finished_at = ~s WHERE id = ~s;",
      [QW, QR, QF, QId]),
    sql_exec(SQL).

mark_match_failed(MatchId, Status) :-
    ensure_connected,
    timestamp_iso(Now),
    sql_literal(MatchId, QId),
    sql_quote(Status, QStatus),
    sql_quote(Now, QF),
    format(string(SQL),
      "UPDATE matches SET status = ~s, finished_at = ~s WHERE id = ~s;",
      [QStatus, QF, QId]),
    sql_exec(SQL).

% Usado para re-enfileirar pendentes apos restart, dai a ordem crescente.
list_matches_by_status(Statuses, Matches) :-
    ensure_connected,
    conn_alias(Alias),
    maplist(sql_quote, Statuses, Quoted),
    atomic_list_concat(Quoted, ',', InList),
    format(string(SQL),
      "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches WHERE status IN (~w) ORDER BY created_at ASC;",
      [InList]),
    findall(Match, ( prosqlite:sqlite_query(Alias, SQL, Row), match_row_dict(Row, Match) ), Matches).

get_match(MatchId, Match) :-
    ensure_connected,
    sql_literal(MatchId, QId),
    format(string(SQL),
      "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches WHERE id = ~s LIMIT 1;",
      [QId]),
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, Row)),
    match_row_dict(Row, Match).

list_matches(Matches) :-
    ensure_connected,
    conn_alias(Alias),
    findall(Match,
      ( prosqlite:sqlite_query(Alias,
          "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at FROM matches ORDER BY created_at DESC;",
          Row),
        match_row_dict(Row, Match) ),
      Matches).

%!  list_matches_page(+Cursor, +Limit, -Matches, -NextCursor) is det.
%
%   Lista resumos de partidas por cursor. Nao inclui `replay_json`; o replay
%   completo fica no detalhe /api/v1/matches/<id>.
list_matches_page(Cursor, Limit, Matches, NextCursor) :-
    ensure_connected,
    conn_alias(Alias),
    PageLimit is Limit + 1,
    cursor_where(Cursor, Where),
    format(string(SQL),
      "SELECT id, thief_agent_id, detective_agent_id, scenario, winner, status, created_at, started_at, finished_at FROM matches ~w ORDER BY created_at DESC, id DESC LIMIT ~w;",
      [Where, PageLimit]),
    findall(Match,
      ( prosqlite:sqlite_query(Alias, SQL, Row),
        match_summary_row_dict(Row, Match) ),
      Rows),
    page_items_and_cursor(Rows, Limit, Matches, NextCursor).

cursor_where("", "") :- !.
cursor_where(Cursor, Where) :-
    cursor_parts(Cursor, CreatedAt, Id),
    !,
    sql_quote(CreatedAt, QCreatedAt),
    sql_quote(Id, QId),
    format(string(Where),
           "WHERE (created_at < ~s OR (created_at = ~s AND id < ~s))",
           [QCreatedAt, QCreatedAt, QId]).
cursor_where(_Invalid, "").

cursor_parts(Cursor, CreatedAt, Id) :-
    split_string(Cursor, "|", "", [CreatedAt, Id]),
    CreatedAt \== "",
    Id \== "".

page_items_and_cursor(Rows, Limit, Items, NextCursor) :-
    length(Prefix, Limit),
    append(Prefix, [_Extra|_], Rows),
    !,
    Items = Prefix,
    last(Prefix, Last),
    row_cursor(Last, NextCursor).
page_items_and_cursor(Rows, _Limit, Rows, "").

row_cursor(Row, Cursor) :-
    format(string(Cursor), "~w|~w", [Row.created_at, Row.id]).

last_insert_id(Id) :-
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, "SELECT last_insert_rowid();", row(Id))).

%!  match_row_dict(+Row, -Match) is det.
%
%   Normaliza colunas que podem vir NULL (partidas antigas, anteriores ao fluxo
%   assincrono) ou como atomo (driver prosqlite): `status` ausente vira "done"
%   (modelo antigo, ja concluida); demais textos opcionais viram "".
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

match_summary_row_dict(row(Id, Thief, Detective, Scenario, Winner, Status,
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
        status: StatusT,
        created_at: CreatedAt,
        started_at: StartedT,
        finished_at: FinishedT
    }.

norm_status(Raw, "done") :- ( Raw == '$null$' ; Raw == '' ; Raw == "" ), !.
norm_status(Raw, Status) :- to_text(Raw, Status).

norm_optional(Raw, "") :- Raw == '$null$', !.
norm_optional(Raw, Text) :- to_text(Raw, Text).

to_text(Raw, Raw) :- string(Raw), !.
to_text(Raw, S) :- atom(Raw), !, atom_string(Raw, S).
to_text(Raw, S) :- format(string(S), "~w", [Raw]).

% Em ambas as direcoes: NULL do banco tambem conta como false.
bool_int(true, 1).
bool_int(false, 0).
bool_int(false, '$null$').
