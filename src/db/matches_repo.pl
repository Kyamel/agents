:- module(matches_repo, [
    save_match/5,
    create_pending_match/4,
    update_match_status/2,
    finalize_match/3,
    mark_match_failed/2,
    list_matches_by_status/2,
    get_match/2,
    list_matches_page/4,
    owner_record/2,
    agent_record/2
]).

:- use_module(repo).

% Repositorio do recurso "partida" (tabela matches), sobre o toolkit repo.pl.
% Colunas opcionais (scenario/started/finished) e status com fallback usam um
% mapeador de dominio via repo:get_*_with/3. Reexportado por db.pl.

match_columns("id, thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at").
summary_columns("id, thief_agent_id, detective_agent_id, scenario, winner, status, created_at, started_at, finished_at").

save_match(ThiefAgentId, DetectiveAgentId, Winner, ReplayJson, MatchId) :-
    repo:now_iso(CreatedAt),
    repo:lit(ThiefAgentId, QT),
    repo:lit(DetectiveAgentId, QD),
    repo:quote(Winner, QW),
    repo:quote(ReplayJson, QR),
    repo:quote(CreatedAt, QC),
    format(string(SQL),
        "INSERT INTO matches(thief_agent_id, detective_agent_id, winner, replay_json, created_at) VALUES(~s, ~s, ~s, ~s, ~s);",
        [QT, QD, QW, QR, QC]),
    repo:insert(SQL, MatchId).

%!  create_pending_match(+ThiefAgentId, +DetectiveAgentId, +Scenario, -MatchId) is det.
%
%   Cria a partida ja enfileirada (status='queued'); winner/replay sao
%   preenchidos por finalize_match/3 quando o subprocesso termina.
create_pending_match(ThiefAgentId, DetectiveAgentId, Scenario, MatchId) :-
    repo:now_iso(CreatedAt),
    repo:lit(ThiefAgentId, QT),
    repo:lit(DetectiveAgentId, QD),
    repo:quote(Scenario, QS),
    repo:quote(CreatedAt, QC),
    format(string(SQL),
        "INSERT INTO matches(thief_agent_id, detective_agent_id, scenario, winner, replay_json, status, created_at, started_at, finished_at) VALUES(~s, ~s, ~s, '', '', 'queued', ~s, NULL, NULL);",
        [QT, QD, QS, QC]),
    repo:insert(SQL, MatchId).

% Ao passar para "running", grava tambem started_at.
update_match_status(MatchId, Status) :-
    Status == "running",
    !,
    repo:lit(MatchId, QId),
    repo:quote(Status, QStatus),
    repo:now_iso(Now),
    repo:quote(Now, QNow),
    format(string(SQL),
        "UPDATE matches SET status = ~s, started_at = ~s WHERE id = ~s;",
        [QStatus, QNow, QId]),
    repo:exec(SQL).
update_match_status(MatchId, Status) :-
    repo:lit(MatchId, QId),
    repo:quote(Status, QStatus),
    format(string(SQL),
        "UPDATE matches SET status = ~s WHERE id = ~s;",
        [QStatus, QId]),
    repo:exec(SQL).

finalize_match(MatchId, Winner, ReplayJson) :-
    repo:now_iso(Now),
    repo:lit(MatchId, QId),
    repo:quote(Winner, QW),
    repo:quote(ReplayJson, QR),
    repo:quote(Now, QF),
    format(string(SQL),
        "UPDATE matches SET winner = ~s, replay_json = ~s, status = 'done', finished_at = ~s WHERE id = ~s;",
        [QW, QR, QF, QId]),
    repo:exec(SQL).

mark_match_failed(MatchId, Status) :-
    repo:now_iso(Now),
    repo:lit(MatchId, QId),
    repo:quote(Status, QStatus),
    repo:quote(Now, QF),
    format(string(SQL),
        "UPDATE matches SET status = ~s, finished_at = ~s WHERE id = ~s;",
        [QStatus, QF, QId]),
    repo:exec(SQL).

% Re-enfileirar pendentes apos restart, dai a ordem crescente.
list_matches_by_status(Statuses, Matches) :-
    maplist(repo:quote, Statuses, Quoted),
    atomic_list_concat(Quoted, ',', InList),
    match_columns(Cols),
    format(string(SQL),
        "SELECT ~w FROM matches WHERE status IN (~w) ORDER BY created_at ASC;",
        [Cols, InList]),
    repo:get_all_with(SQL, matches_repo:match_row_dict, Matches).

get_match(MatchId, Match) :-
    repo:lit(MatchId, QId),
    match_columns(Cols),
    format(string(SQL),
        "SELECT ~w FROM matches WHERE id = ~s LIMIT 1;", [Cols, QId]),
    repo:get_one_with(SQL, matches_repo:match_row_dict, Match).

%!  list_matches_page(+RequestedPage, +PerPage, -Matches, -Pagination) is det.
%
%   Resumos por pagina (sem replay_json; o replay completo fica no detalhe).
list_matches_page(RequestedPage, PerPage, Matches, Pagination) :-
    repo:count_rows("matches", "", TotalItems),
    repo:paginate(RequestedPage, PerPage, TotalItems, Pagination),
    Offset is (Pagination.page - 1) * PerPage,
    summary_columns(Cols),
    format(string(SQL),
        "SELECT ~w FROM matches ORDER BY id ASC LIMIT ~w OFFSET ~w;",
        [Cols, PerPage, Offset]),
    repo:get_all_with(SQL, matches_repo:match_summary_row_dict, Matches).

% Retrospecto (vitorias/derrotas/empates) agregado direto no SQL, sem trazer as
% partidas para o Prolog. Uma partida so conta quando concluida e com vencedor.
% `winner` e gravado como 'thief' | 'detective' | 'draw' (ver engine/match_replay).

%!  agent_record(+AgentId, -Record) is det.   Record = _{wins, losses, draws}.
%
%   Retrospecto de UM agente (em qualquer papel). Com indice em
%   matches(thief/detective_agent_id), varre so as partidas do agente.
agent_record(AgentId, Record) :-
    repo:lit(AgentId, QId),
    completed_clause(Done),
    format(string(SQL),
        "SELECT COUNT(*), \c
                COALESCE(SUM(CASE WHEN (thief_agent_id = ~s AND winner = 'thief') \c
                                    OR (detective_agent_id = ~s AND winner = 'detective') \c
                                  THEN 1 ELSE 0 END), 0), \c
                COALESCE(SUM(CASE WHEN winner = 'draw' THEN 1 ELSE 0 END), 0) \c
           FROM matches \c
          WHERE (thief_agent_id = ~s OR detective_agent_id = ~s) AND ~s;",
        [QId, QId, QId, QId, Done]),
    repo:get_one_with(SQL, matches_repo:record_from_total, Record).

%!  owner_record(+OwnerId, -Record) is det.   Record = _{wins, losses, draws}.
%
%   Retrospecto global do dono = soma sobre TODOS os seus agentes. Uma partida
%   entre dois agentes do mesmo dono conta dos dois lados (como o antigo somatorio
%   por agente): por isso os dois lados (ladrao/detetive) sao agregados e somados.
owner_record(OwnerId, Record) :-
    repo:lit(OwnerId, QOwner),
    completed_clause(Done),
    format(string(SQL),
        "SELECT COALESCE(SUM(w), 0), COALESCE(SUM(l), 0), COALESCE(SUM(d), 0) FROM ( \c
           SELECT SUM(CASE WHEN winner = 'thief' THEN 1 ELSE 0 END) AS w, \c
                  SUM(CASE WHEN winner <> 'draw' AND winner <> 'thief' THEN 1 ELSE 0 END) AS l, \c
                  SUM(CASE WHEN winner = 'draw' THEN 1 ELSE 0 END) AS d \c
             FROM matches \c
            WHERE thief_agent_id IN (SELECT id FROM agents WHERE owner_user_id = ~s AND deleted_at IS NULL) \c
              AND ~s \c
           UNION ALL \c
           SELECT SUM(CASE WHEN winner = 'detective' THEN 1 ELSE 0 END), \c
                  SUM(CASE WHEN winner <> 'draw' AND winner <> 'detective' THEN 1 ELSE 0 END), \c
                  SUM(CASE WHEN winner = 'draw' THEN 1 ELSE 0 END) \c
             FROM matches \c
            WHERE detective_agent_id IN (SELECT id FROM agents WHERE owner_user_id = ~s AND deleted_at IS NULL) \c
              AND ~s \c
         );",
        [QOwner, Done, QOwner, Done]),
    repo:get_one_with(SQL, matches_repo:record_wld, Record).

% Filtro de "partida concluida com vencedor" (status normalizado = done + winner
% presente), espelhando o completed_match do antigo calculo em Prolog.
completed_clause("(status = 'done' OR status = '' OR status IS NULL) \c
                  AND winner IS NOT NULL AND winner <> ''").

record_from_total(row(Total, Wins, Draws), _{wins: Wins, losses: Losses, draws: Draws}) :-
    Losses is Total - Wins - Draws.

record_wld(row(Wins, Losses, Draws), _{wins: Wins, losses: Losses, draws: Draws}).

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

% status ausente (modelo antigo) conta como concluida.
norm_status(Raw, "done") :- Raw == '$null$', !.
norm_status(Raw, "done") :- Raw == '', !.
norm_status(Raw, "done") :- Raw == "", !.
norm_status(Raw, Status) :- repo:text(Raw, Status).

norm_optional('$null$', "") :- !.
norm_optional(Raw, Text) :- repo:text(Raw, Text).
