:- module(match_runner, [
    run_match/4
]).

:- use_module(library(http/json)).
:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../config/env').
:- use_module('./agent_cache').

% Camada fina sobre a engine do professor (Interactor.prolog). Mantém a mesma
% assinatura `run_match/4` esperada pelas rotas em src/http e pelo controller
% de matches, traduzindo agentes carregados do banco SQL e o resultado da
% engine para o formato consumido pela UI/API.

:- dynamic interactor_loaded/0.
:- dynamic engine_dir_fact/1.

% Resolve o diretorio do engine em tempo de carga, antes que `source_file/2`
% se torne indisponivel ou ambiguo.
:- prolog_load_context(directory, EngineDir),
   retractall(engine_dir_fact(_)),
   assertz(engine_dir_fact(EngineDir)).

%!  run_match(+ThiefAgent, +DetectiveAgent, -Result, -ReplayJson) is det.
%
%   Executa uma partida com a engine do professor. A engine usa muito estado
%   global (predicados consultados, dynamic facts), portanto a execucao eh
%   serializada por um mutex.
run_match(ThiefAgent, DetectiveAgent, Result, ReplayJson) :-
    with_mutex(match_runner_engine,
               run_match_locked(ThiefAgent, DetectiveAgent, Result, ReplayJson)).

run_match_locked(ThiefAgent, DetectiveAgent, Result, ReplayJson) :-
    ensure_interactor_loaded,
    scenario_name(ScenarioName),
    scenario_engine_arg(ScenarioName, ScenarioArg),
    agent_cache:materialize_agent(ThiefAgent, ThiefPath),
    agent_cache:materialize_agent(DetectiveAgent, DetectivePath),
    disguise_count(Qdis),
    reset_engine_dynamics,
    capture_engine_run(ScenarioArg, Qdis, ThiefPath, DetectivePath, RawWinner, Lines),
    parse_replay(Lines, Turns),
    map_winner(RawWinner, Winner),
    atom_json_dict(ReplayJson, Turns, []),
    length(Turns, FinalTurn),
    Result = _{
        thief_agent_id: ThiefAgent.id,
        detective_agent_id: DetectiveAgent.id,
        winner: Winner,
        final_turn: FinalTurn,
        scenario: ScenarioName,
        replay: Turns
    }.

% -----------------------------
% Bootstrap do engine
% -----------------------------

ensure_interactor_loaded :- interactor_loaded, !.
ensure_interactor_loaded :-
    engine_dir(Dir),
    directory_file_path(Dir, 'Interactor.prolog', Path),
    user:consult(Path),
    assertz(interactor_loaded).

engine_dir(Dir) :- engine_dir_fact(Dir).

scenario_name(Name) :-
    env:env_string('ENGINE_SCENARIO', "mapa1", S),
    atom_string(Name, S).

% A engine concatena ".prolog" e chama consult/1, entao passamos o caminho
% absoluto SEM extensao para que o consult resolva o arquivo correto.
scenario_engine_arg(Name, Arg) :-
    engine_dir(Dir),
    directory_file_path(Dir, Name, Arg).

disguise_count(Q) :- env:env_int('ENGINE_QDIS', 3, Q).

% A engine acumula facts dinamicos entre partidas (roubado/2, fechado/1,
% pistas/3) e cada cenario consultado deixa cidade/conectado/item/tesouro
% residuais. Limpamos antes de cada partida para garantir reprodutibilidade.
reset_engine_dynamics :-
    forall(member(Head, [
        user:roubado(_,_),
        user:fechado(_),
        user:pistas(_,_,_),
        user:item(_,_,_),
        user:tesouro(_,_,_),
        user:cidade(_),
        user:conectado(_,_),
        user:procurado(_,_,_),
        user:max_turnos(_)
    ]),
    catch(retractall(Head), _, true)).

% -----------------------------
% Captura de saida e mapeamento de vencedor
% -----------------------------

% Falhas/excecoes da engine sao propagadas para que a rota chamadora
% mostre erro ao usuario em vez de salvar uma partida invalida.
capture_engine_run(Scenario, Qdis, ThiefPath, DetectivePath, Winner, Lines) :-
    State = state(_),
    with_output_to(string(Output),
        run_engine(Scenario, Qdis, ThiefPath, DetectivePath, State)),
    arg(1, State, Winner),
    split_string(Output, "\n", "", Lines).

% Executa a engine e guarda o vencedor; falha da engine vira excecao.
run_engine(Scenario, Qdis, ThiefPath, DetectivePath, State) :-
    user:gameStart(Scenario, Qdis, ThiefPath, DetectivePath, _, W),
    !,
    nb_setarg(1, State, W).
run_engine(_Scenario, _Qdis, _ThiefPath, _DetectivePath, _State) :-
    throw(error(engine_failure(gameStart), _)).

map_winner(ladrao, "thief") :- !.
map_winner(detetive, "detective") :- !.
map_winner(empate, "draw") :- !.
map_winner(Other, "draw") :-
    print_message(warning, format("match_runner: unknown engine winner ~q", [Other])).

% -----------------------------
% Parsing do log da engine
% -----------------------------
%
% A engine emite duas linhas por turno via `logar/4`:
%   "<N> ladrao: <Action>[<OBS>]"
%   "<N> detetive: <Action>[<OBS>]"
% onde OBS eh "OK" ou "Ilegal". Eventos do detetive entram como
% "  >>>> Evento <termo>" e sao ignorados pelo parser.

parse_replay(Lines, Turns) :-
    convlist(parse_log_line, Lines, Entries),
    build_turns(Entries, Turns).

parse_log_line(Line, log(Turn, Role, Action, Status)) :-
    (   string_concat(Body, "[OK]", Line), StatusCandidate = "OK"
    ;   string_concat(Body, "[Ilegal]", Line), StatusCandidate = "Ilegal"
    ),
    !,
    string_codes(Body, Codes),
    prefix_parse(Turn, Role, ActionRaw, Codes),
    normalize_space(string(Action), ActionRaw),
    Status = StatusCandidate.

prefix_parse(Turn, Role, ActionStr, Codes) :-
    digits_split(Codes, DigitCodes, [0' |Rest1]),
    DigitCodes \= [],
    number_codes(Turn, DigitCodes),
    take_until_codes(Rest1, 0':, RoleCodes, [0':|Rest2]),
    string_codes(RoleStr, RoleCodes),
    role_atom(RoleStr, Role),
    skip_ws_codes(Rest2, Rest3),
    string_codes(ActionStr, Rest3).

digits_split([C|Cs], [C|Ds], Rest) :- code_type(C, digit), !, digits_split(Cs, Ds, Rest).
digits_split(Cs, [], Cs).

take_until_codes([C|Cs], Stop, [], [C|Cs]) :- C == Stop, !.
take_until_codes([C|Cs], Stop, [C|Acc], Rest) :- take_until_codes(Cs, Stop, Acc, Rest).
take_until_codes([], _, [], []).

skip_ws_codes([0' |Cs], R) :- !, skip_ws_codes(Cs, R).
skip_ws_codes(Cs, Cs).

role_atom("ladrao", thief).
role_atom("detetive", detective).

% Agrupa entradas consecutivas thief/detective do mesmo turno. A engine emite
% o log do ladrao antes do detetive em cada turno, com o mesmo numero N.
build_turns([], []).
build_turns([log(N, thief, TA, TS), log(N, detective, DA, DS) | Rest],
            [Turn|Turns]) :-
    !,
    move_dest(TA, ThiefPos),
    move_dest(DA, DetPos),
    Turn = _{
        turn: N,
        thief_action: TA,
        thief_status: TS,
        thief_position: ThiefPos,
        detective_action: DA,
        detective_status: DS,
        detective_position: DetPos
    },
    build_turns(Rest, Turns).
build_turns([log(N, thief, TA, TS) | Rest], [Turn|Turns]) :-
    !,
    move_dest(TA, ThiefPos),
    Turn = _{
        turn: N,
        thief_action: TA,
        thief_status: TS,
        thief_position: ThiefPos,
        detective_action: "-",
        detective_status: "",
        detective_position: "-"
    },
    build_turns(Rest, Turns).
build_turns([log(N, detective, DA, DS) | Rest], [Turn|Turns]) :-
    move_dest(DA, DetPos),
    Turn = _{
        turn: N,
        thief_action: "-",
        thief_status: "",
        thief_position: "-",
        detective_action: DA,
        detective_status: DS,
        detective_position: DetPos
    },
    build_turns(Rest, Turns).

% Extrai destino de uma acao "move(X,Y)" para preencher a posicao do agente
% no replay. Demais acoes nao revelam posicao, entao caem no traco.
move_dest(Action, Dest) :-
    string_concat("move(", Rest, Action),
    !,
    split_string(Rest, ",)", " )", Parts),
    Parts = [_From, ToRaw | _],
    string_concat(ToRaw, "", Dest0),
    Dest0 \= "",
    !,
    Dest = Dest0.
move_dest(_, "-").

% Eager-load do Interactor.prolog no carregamento deste modulo. Sem isso o
% `check/0` reclama de gameStart/6 porque o consult seria lazy. Erros sao
% engolidos para nao quebrar o build se a engine estiver ausente.
:- catch(ensure_interactor_loaded, _, true).
