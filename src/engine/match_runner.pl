:- module(match_runner, [
    run_match/4,
    run_match/5,
    available_scenarios/1,
    valid_scenario/1
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
    scenario_name(ScenarioName),
    run_match(ThiefAgent, DetectiveAgent, ScenarioName, Result, ReplayJson).

%!  run_match(+ThiefAgent, +DetectiveAgent, +Scenario, -Result, -ReplayJson) is det.
%
%   Como run_match/4, mas usando o cenario `Scenario` informado (caminho do
%   arquivo .prolog, ex.: "./scenarios/mapa1.prolog") em vez do padrao
%   configurado.
run_match(ThiefAgent, DetectiveAgent, Scenario, Result, ReplayJson) :-
    with_mutex(match_runner_engine,
               run_match_locked(ThiefAgent, DetectiveAgent, Scenario, Result, ReplayJson)).

run_match_locked(ThiefAgent, DetectiveAgent, ScenarioName, Result, ReplayJson) :-
    ensure_interactor_loaded,
    scenario_text(ScenarioName, ScenarioLabel),
    scenario_engine_arg(ScenarioName, ScenarioArg),
    agent_cache:materialize_agent(ThiefAgent, ThiefPath),
    agent_cache:materialize_agent(DetectiveAgent, DetectivePath),
    prepare_agent_modules(ThiefPath, DetectivePath),
    disguise_count(Qdis),
    reset_engine_dynamics,
    capture_engine_run(ScenarioArg, Qdis, ThiefPath, DetectivePath,
                       RawWinner, InitialState, Lines),
    map_winner(RawWinner, Winner),
    parse_replay(Lines, Turns, Events),
    setup_dict(InitialState, ScenarioLabel, Setup),
    length(Turns, FinalTurn),
    Replay = _{
        scenario: ScenarioLabel,
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
        scenario: ScenarioLabel,
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

project_root(Root) :-
    engine_dir(EngineDir),
    directory_file_path(SrcDir, engine, EngineDir),
    directory_file_path(Root, src, SrcDir).

scenario_name(Name) :-
    config:engine_scenario(Name).

%!  available_scenarios(-Scenarios) is det.
%
%   Lista os cenarios .prolog no diretorio configurado em `scenario_dir/1`,
%   ordenados por nome. Cada item e scenario(Value, Label), onde Value e o
%   caminho do arquivo no mesmo formato de `engine_scenario/1` (com ".prolog",
%   ex.: "./scenarios/mapa1.prolog") e Label e o nome sem extensao ("mapa1").
available_scenarios(Scenarios) :-
    config:scenario_dir(Dir),
    to_atom(Dir, DirAtom),
    (   exists_directory(DirAtom)
    ->  directory_files(DirAtom, Entries)
    ;   Entries = []
    ),
    findall(scenario(Value, Label),
            ( member(Entry, Entries),
              file_name_extension(Base, prolog, Entry),
              atom_string(Base, Label),
              directory_file_path(DirAtom, Entry, Path),
              atom_string(Path, Value)
            ),
            Unsorted),
    sort(2, @=<, Unsorted, Scenarios).

%!  valid_scenario(+Value) is semidet.
%
%   Verdadeiro se `Value` corresponde a um cenario disponivel em `scenario_dir`.
%   Usado para validar a escolha vinda do formulario antes de executar.
valid_scenario(Value) :-
    available_scenarios(Scenarios),
    memberchk(scenario(Value, _), Scenarios).

% A engine (loadCenario/1) exige um atomo e concatena ".prolog" antes de
% consultar. Por isso removemos a extensao do caminho configurado e resolvemos
% para um caminho absoluto (relativo a raiz do projeto) como atomo.
scenario_engine_arg(Scenario, Arg) :-
    to_atom(Scenario, PathAtom),
    strip_leading_dot(PathAtom, Rel),
    file_name_extension(RelNoExt, prolog, Rel),
    project_root(Root),
    directory_file_path(Root, RelNoExt, Arg).

%!  scenario_text(+Scenario, -Label) is det.
%
%   Nome amigavel do cenario para a UI/JSON: o nome do arquivo sem o diretorio
%   nem a extensao ".prolog" (ex.: "./scenarios/mapa1.prolog" -> "mapa1").
scenario_text(Scenario, Label) :-
    to_atom(Scenario, PathAtom),
    file_base_name(PathAtom, Base),
    ( file_name_extension(Name, prolog, Base) -> true ; Name = Base ),
    atom_string(Name, Label).

%!  strip_leading_dot(+Path, -Rel) is det.
%
%   Remove o prefixo "./" de um caminho, se houver, para que possa ser
%   resolvido com directory_file_path/3 a partir da raiz do projeto.
strip_leading_dot(Path, Rel) :-
    ( atom_concat('./', Rel, Path) -> true ; Rel = Path ).

%!  to_atom(+Value, -Atom) is det.
%
%   Normaliza string ou atomo para atomo.
to_atom(Value, Value) :- atom(Value), !.
to_atom(Value, Atom) :- string(Value), atom_string(Atom, Value).

disguise_count(Q) :- config:engine_disguises(Q).

% Predicados que todo agente exporta e que a engine chama sem qualificacao de
% modulo (logo, resolvidos em `user`).
agent_predicate(ladrao_preload/7).
agent_predicate(ladrao_action/3).
agent_predicate(detetive_preload/5).
agent_predicate(detetive_action/3).

% A engine carrega os agentes com use_module/1, que importa esses predicados
% para o modulo `user`. Como o processo do servidor roda varias partidas no
% mesmo `user`, trocar de detetive (ou ladrao) entre partidas faz o use_module
% do novo agente colidir com o anterior:
%   "No permission to import detetive_action/3 into user (already imported ...)".
% Antes de cada partida removemos de `user` os imports dos predicados de agente,
% para que o use_module da engine reimporte os predicados do agente atual sem
% conflito. (Nao usamos unload_file/1: ele deixa o import em `user` pendurado
% apontando para o modulo removido e o use_module seguinte nao o reimporta.)
% O estado dinamico interno de cada agente e reiniciado pelo proprio preload.
prepare_agent_modules(_ThiefPath, _DetectivePath) :-
    forall(agent_predicate(Name/Arity),
           catch(abolish(user:Name/Arity), _, true)).

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
    attach_events(Records, Entries),
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

%!  attach_events(+Records, -Entries) is det.
%
%   Reassocia cada evento de roubo a entrada de log da acao `roubar`
%   correspondente, casando pelo item roubado (cada item e roubado uma unica
%   vez na partida). Isso independe de QUANDO a engine imprime o evento: desde a
%   alteracao que atrasa o evento em um turno do ladrao (atrasarEventoRoubo/1 no
%   Interactor), a linha `>>>> Evento` nao vem mais junto da acao que a gerou,
%   entao confiar na ordem de impressao deslocava o turno e descartava o roubo
%   final (cujo evento nao tem linha de log depois dele).
attach_events(Records, Entries) :-
    records_split(Records, Logs, Events),
    maplist(blank_entry, Logs, Entries0),
    foldl(assign_event, Events, Entries0, Entries).

%!  records_split(+Records, -Logs, -Events) is det.
%
%   Separa as linhas classificadas em logs de acao e eventos de roubo,
%   preservando a ordem de cada grupo.
records_split([], [], []).
records_split([evento(E)|Rest], Logs, [E|Events]) :-
    !,
    records_split(Rest, Logs, Events).
records_split([log(N, Role, Action, Status)|Rest],
              [log(N, Role, Action, Status)|Logs], Events) :-
    records_split(Rest, Logs, Events).

blank_entry(log(N, Role, Action, Status), entry(N, Role, Action, Status, [])).

%!  assign_event(+Event, +Entries0, -Entries) is det.
%
%   Anexa um evento de roubo a entrada `roubar(Item)` do ladrao. Se nao houver
%   acao correspondente (nao deveria ocorrer), emite aviso e descarta o evento.
assign_event(roubo(Item, City, Revealed), Entries0, Entries) :-
    add_event_to_rob(Entries0, Item, roubo(Item, City, Revealed), Entries),
    !.
assign_event(Event, Entries, Entries) :-
    print_message(warning,
        format("match_runner: evento sem acao de roubo correspondente: ~q",
               [Event])).

%!  add_event_to_rob(+Entries0, +Item, +Event, -Entries) is semidet.
%
%   Encontra a entrada do ladrao cuja acao e `roubar(Item)` e anexa o evento.
add_event_to_rob([entry(N, thief, roubar(Item), Status, Evs)|Rest], Item, Event,
                 [entry(N, thief, roubar(Item), Status, [Event|Evs])|Rest]) :-
    !.
add_event_to_rob([Entry|Rest], Item, Event, [Entry|Rest1]) :-
    add_event_to_rob(Rest, Item, Event, Rest1).

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
