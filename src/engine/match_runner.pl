:- module(match_runner, [
    run_match/4
]).

:- use_module(library(http/json)).
:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../config').
:- use_module('./agent_cache').

% Camada fina sobre a engine do professor (Interactor.prolog). Mantém a mesma
% assinatura `run_match/4` esperada pelas rotas em src/http, traduzindo agentes
% carregados do banco SQL e o resultado da engine para o formato consumido pela
% UI/API.

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
    capture_engine_run(ScenarioArg, Qdis, ThiefPath, DetectivePath,
                       RawWinner, InitialState, Lines),
    map_winner(RawWinner, Winner),
    parse_replay(Lines, Turns, Events),
    setup_dict(InitialState, ScenarioName, Setup),
    length(Turns, FinalTurn),
    Replay = _{
        scenario: ScenarioName,
        winner: Winner,
        final_turn: FinalTurn,
        setup: Setup,
        turns: Turns,
        events: Events
    },
    atom_json_dict(ReplayJson, Replay, [width(0)]),
    Result = _{
        thief_agent_id: ThiefAgent.id,
        detective_agent_id: DetectiveAgent.id,
        winner: Winner,
        final_turn: FinalTurn,
        scenario: ScenarioName,
        replay: Replay
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
    config:engine_scenario(Name).

% A engine concatena ".prolog" e chama consult/1, entao passamos o caminho
% absoluto SEM extensao para que o consult resolva o arquivo correto.
scenario_engine_arg(Name, Arg) :-
    engine_dir(Dir),
    directory_file_path(Dir, Name, Arg).

disguise_count(Q) :- config:engine_disguises(Q).

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

%!  capture_engine_run(+Scenario, +Qdis, +ThiefPath, +DetectivePath, -Winner, -InitialState, -Lines) is det.
%
%   Roda a engine capturando o stdout. Alem do vencedor, devolve o estado
%   inicial (5o argumento de gameStart/6, antes descartado) para extrair os
%   metadados da partida via introspecao. Falhas viram excecao para a rota.
capture_engine_run(Scenario, Qdis, ThiefPath, DetectivePath, Winner, InitialState, Lines) :-
    with_output_to(string(Output),
        run_engine(Scenario, Qdis, ThiefPath, DetectivePath, InitialState, Winner)),
    split_string(Output, "\n", "", Lines).

%!  run_engine(+Scenario, +Qdis, +ThiefPath, +DetectivePath, -InitialState, -Winner) is det.
%
%   Executa a engine uma vez; falha da engine vira `engine_failure`.
run_engine(Scenario, Qdis, ThiefPath, DetectivePath, InitialState, Winner) :-
    user:gameStart(Scenario, Qdis, ThiefPath, DetectivePath, InitialState, Winner),
    !.
run_engine(_Scenario, _Qdis, _ThiefPath, _DetectivePath, _InitialState, _Winner) :-
    throw(error(engine_failure(gameStart), _)).

%!  map_winner(+EngineWinner, -Winner) is det.
%
%   Traduz o vencedor da engine (atomo) para o vocabulario da UI/API.
map_winner(ladrao, "thief") :- !.
map_winner(detetive, "detective") :- !.
map_winner(empate, "draw") :- !.
map_winner(Other, "draw") :-
    print_message(warning, format("match_runner: unknown engine winner ~q", [Other])).

% -----------------------------
% Parsing do log da engine (introspecao por leitura de termos)
% -----------------------------
%
% A engine so expoe o que acontece via `write/1` no stdout, em duas formas:
%   "<N> ladrao: <AcaoTermo>[<OBS>]"      (logar/4, OBS = OK | Ilegal)
%   "<N> detetive: <AcaoTermo>[<OBS>]"
%   "  >>>> Evento roubo(Item,Cidade,Pistas)"  (emitirEvento/3)
%
% Em vez de fatiar strings, lemos cada acao/evento DE VOLTA para um termo
% Prolog (term_string/2) e inspecionamos functor/argumentos. Isso captura
% todos os eventos possiveis sem tocar em Interactor.prolog, inclusive os
% roubos que o parser antigo descartava.

%!  parse_replay(+Lines, -Turns, -Events) is det.
%
%   Constroi a lista de turnos (visao turno-a-turno) e a linha do tempo
%   plana de eventos do jogo a partir das linhas capturadas.
parse_replay(Lines, Turns, Events) :-
    convlist(classify_line, Lines, Records),
    attach_events(Records, [], Entries),
    build_turns(Entries, Turns),
    timeline(Entries, Events).

%!  classify_line(+Line, -Record) is semidet.
%
%   Reconhece uma linha de evento ou de log; demais linhas sao descartadas.
classify_line(Line, evento(Term)) :-
    normalize_space(string(Trimmed), Line),
    string_concat(">>>> Evento ", TermStr, Trimmed),
    !,
    safe_term(TermStr, Term).
classify_line(Line, log(Turn, Role, Action, Status)) :-
    split_status(Line, Body, Status),
    parse_log_body(Body, Turn, Role, Action).

%!  split_status(+Line, -Body, -Status) is semidet.
%
%   Separa o sufixo "[OK]"/"[Ilegal]" do corpo da linha de log.
split_status(Line, Body, "OK") :-
    string_concat(Body, "[OK]", Line),
    !.
split_status(Line, Body, "Ilegal") :-
    string_concat(Body, "[Ilegal]", Line).

%!  parse_log_body(+Body, -Turn, -Role, -Action) is semidet.
%
%   Extrai turno, papel e acao (como termo) de "<N> <papel>: <acao>".
parse_log_body(Body, Turn, Role, Action) :-
    sub_string(Body, Before, _, After, ": "),
    !,
    sub_string(Body, 0, Before, _, Prefix),
    sub_string(Body, _, After, 0, ActionStr),
    split_string(Prefix, " ", "", [TurnStr, RoleStr]),
    number_string(Turn, TurnStr),
    role_atom(RoleStr, Role),
    safe_term(ActionStr, Action).

role_atom("ladrao", thief).
role_atom("detetive", detective).

%!  safe_term(+Str, -Term) is det.
%
%   Le de volta o termo escrito pela engine; mantem o texto cru se nao
%   for parseavel (atomos com aspas, etc.).
safe_term(Str, Term) :-
    catch(term_string(Term, Str), _, fail),
    !.
safe_term(Str, Str).

%!  attach_events(+Records, +Pending, -Entries) is det.
%
%   Eventos sao escritos imediatamente antes da linha de log da acao que os
%   gerou (sempre o ladrao). Acumulamos os eventos pendentes e os anexamos a
%   proxima entrada de log.
attach_events([], _Pending, []).
attach_events([evento(E)|Rest], Pending, Entries) :-
    !,
    attach_events(Rest, [E|Pending], Entries).
attach_events([log(N, Role, Action, Status)|Rest], Pending,
              [entry(N, Role, Action, Status, Events)|Entries]) :-
    reverse(Pending, Events),
    attach_events(Rest, [], Entries).

% Agrupa entradas consecutivas thief/detective do mesmo turno. A engine emite
% o log do ladrao antes do detetive em cada turno, com o mesmo numero N.
build_turns([], []).
build_turns([entry(N, thief, TA, TS, TE), entry(N, detective, DA, DS, DE)|Rest],
            [Turn|Turns]) :-
    !,
    turn_dict(N, entry(thief, TA, TS, TE), entry(detective, DA, DS, DE), Turn),
    build_turns(Rest, Turns).
build_turns([entry(N, thief, TA, TS, TE)|Rest], [Turn|Turns]) :-
    !,
    turn_dict(N, entry(thief, TA, TS, TE), none, Turn),
    build_turns(Rest, Turns).
build_turns([entry(N, detective, DA, DS, DE)|Rest], [Turn|Turns]) :-
    turn_dict(N, none, entry(detective, DA, DS, DE), Turn),
    build_turns(Rest, Turns).

%!  turn_dict(+Turn, +ThiefEntry, +DetectiveEntry, -Dict) is det.
%
%   Monta o dict de um turno. Mantem as chaves antigas (thief_action, ...)
%   por compatibilidade e acrescenta a lista de eventos do turno.
turn_dict(N, Thief, Detective, Turn) :-
    role_fields(Thief, TAction, TStatus, TPos),
    role_fields(Detective, DAction, DStatus, DPos),
    entry_events(Thief, TEvents),
    entry_events(Detective, DEvents),
    append(TEvents, DEvents, RawEvents),
    maplist(event_dict, RawEvents, Events),
    Turn = _{
        turn: N,
        thief_action: TAction,
        thief_status: TStatus,
        thief_position: TPos,
        detective_action: DAction,
        detective_status: DStatus,
        detective_position: DPos,
        events: Events
    }.

%!  role_fields(+Entry, -ActionText, -Status, -Position) is det.
role_fields(none, "-", "", "-") :- !.
role_fields(entry(_Role, Action, Status, _Events), Text, Status, Pos) :-
    action_text(Action, Text),
    action_position(Action, Pos).

%!  entry_events(+Entry, -Events) is det.
entry_events(none, []) :- !.
entry_events(entry(_Role, _Action, _Status, Events), Events).

%!  action_text(+Action, -Text) is det.
action_text(Action, Action) :-
    string(Action),
    !.
action_text(Action, Text) :-
    term_string(Action, Text).

%!  action_position(+Action, -Position) is det.
%
%   So "move(_,Destino)" revela a posicao do agente; demais acoes caem no traco.
action_position(move(_From, To), Pos) :-
    !,
    term_text(To, Pos).
action_position(_Action, "-").

%!  event_dict(+EventTerm, -Dict) is det.
%
%   Estrutura um evento da engine. Hoje o unico evento emitido e o roubo,
%   que carrega item, cidade e os atributos revelados (pistas ao detetive).
event_dict(roubo(Item, City, Revealed), Dict) :-
    is_list(Revealed),
    !,
    term_text(Item, ItemText),
    term_text(City, CityText),
    maplist(term_text, Revealed, RevealedText),
    Dict = _{
        type: "robbery",
        item: ItemText,
        city: CityText,
        revealed: RevealedText
    }.
event_dict(Other, _{type: "unknown", detail: Text}) :-
    term_text(Other, Text).

%!  timeline(+Entries, -Events) is det.
%
%   Lista plana de todos os eventos do jogo, na ordem de ocorrencia, cada um
%   anotado com o turno e o agente responsavel.
timeline(Entries, Events) :-
    foldl(entry_timeline, Entries, [], Reversed),
    reverse(Reversed, Events).

entry_timeline(entry(N, Role, _Action, _Status, Raw), Acc0, Acc) :-
    foldl(timeline_event(N, Role), Raw, Acc0, Acc).

timeline_event(N, Role, RawEvent, Acc, [Full|Acc]) :-
    event_dict(RawEvent, Base),
    Full = Base.put(_{turn: N, by: Role}).

% -----------------------------
% Estado inicial (introspecao do termo gSt/7 da engine)
% -----------------------------

%!  setup_dict(+InitialState, +Scenario, -Setup) is det.
%
%   Extrai os metadados da partida do estado inicial gSt/7 sem tocar na
%   engine: cidades de partida, alvo do ladrao, aparencia, disfarces e limite
%   de turnos. Cai num dict minimo se o formato do estado nao for o esperado.
setup_dict(gSt(Thief, Detective, Target, _Locks, _BOs, _Caught, MaxTurns),
           Scenario, Setup) :-
    Thief = thief(loc(ThiefCity), ThiefId, Appearance, _Obj, _Items, Disguises),
    Detective = detective(loc(DetCity), _Mandate, _Clues),
    !,
    term_text(ThiefCity, ThiefCityText),
    term_text(DetCity, DetCityText),
    term_text(Target, TargetText),
    appearance_attrs(Appearance, AppearanceText),
    Setup = _{
        scenario: Scenario,
        thief_id: ThiefId,
        thief_start: ThiefCityText,
        detective_start: DetCityText,
        target: TargetText,
        disguises: Disguises,
        max_turns: MaxTurns,
        appearance: AppearanceText
    }.
setup_dict(_Other, Scenario, _{scenario: Scenario}).

%!  appearance_attrs(+Appearance, -Attrs) is det.
appearance_attrs(aparencia(List), Attrs) :-
    is_list(List),
    !,
    maplist(term_text, List, Attrs).
appearance_attrs(_Other, []).

%!  term_text(+Term, -Text) is det.
%
%   Converte um termo da engine para um valor seguro p/ JSON: numeros sao
%   preservados, atomos viram string, compostos sao serializados.
term_text(Term, Term) :-
    number(Term),
    !.
term_text(Term, Text) :-
    atom(Term),
    !,
    atom_string(Term, Text).
term_text(Term, Term) :-
    string(Term),
    !.
term_text(Term, Text) :-
    term_string(Term, Text).

% Eager-load do Interactor.prolog no carregamento deste modulo. Sem isso o
% `check/0` reclama de gameStart/6 porque o consult seria lazy. Erros sao
% engolidos para nao quebrar o build se a engine estiver ausente.
:- catch(ensure_interactor_loaded, _, true).
