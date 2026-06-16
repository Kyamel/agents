:- module(match_replay, [
    engine_output_to_replay/5,
    map_winner/2,
    parse_replay/3,
    setup_dict/3,
    term_text/2
]).

:- use_module(library(lists)).
:- use_module(library(apply)).

% A engine so expoe o que acontece via `write/1` no stdout, em duas formas:
%   "<N> ladrao: <AcaoTermo>[<OBS>]"      (logar/4, OBS = OK | Ilegal)
%   "<N> detetive: <AcaoTermo>[<OBS>]"
%   "  >>>> Evento roubo(Item,Cidade,Pistas)"  (emitirEvento/3)

%!  engine_output_to_replay(+Lines, +ScenarioLabel, +InitialState, +RawWinner, -Replay) is det.
%
%   Ponto de entrada: a partir das linhas capturadas do stdout da engine, do
%   rotulo do cenario, do estado inicial (gSt/7) e do vencedor cru, monta o dict
%   de replay consumido pela UI/API (mesma forma do antigo `Replay` em
%   match_runner). O `winner` ja vem traduzido para o vocabulario da UI.
engine_output_to_replay(Lines, ScenarioLabel, InitialState, RawWinner, Replay) :-
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
    }.

%!  map_winner(+EngineWinner, -Winner) is det.
%
%   Traduz o vencedor da engine (atomo) para o vocabulario da UI/API.
map_winner(ladrao, "thief") :- !.
map_winner(detetive, "detective") :- !.
map_winner(empate, "draw") :- !.
map_winner(Other, "draw") :-
    print_message(warning, format("match_replay: unknown engine winner ~q", [Other])).

%!  parse_replay(+Lines, -Turns, -Events) is det.
%
%   Constroi a lista de turnos (visao turno-a-turno) e a linha do tempo plana de
%   eventos do jogo a partir das linhas capturadas.
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
%   Le de volta o termo escrito pela engine; mantem o texto cru se nao for
%   parseavel (atomos com aspas, etc.).
safe_term(Str, Term) :-
    catch(term_string(Term, Str), _, fail),
    !.
safe_term(Str, Str).

%!  attach_events(+Records, -Entries) is det.
%
%   Reassocia cada evento de roubo a entrada de log da acao `roubar`
%   correspondente, casando pelo item roubado (cada item e roubado uma unica vez
%   na partida). Isso independe de QUANDO a engine imprime o evento.
attach_events(Records, Entries) :-
    records_split(Records, Logs, Events),
    maplist(blank_entry, Logs, Entries0),
    foldl(assign_event, Events, Entries0, Entries).

%!  records_split(+Records, -Logs, -Events) is det.
records_split([], [], []).
records_split([evento(E)|Rest], Logs, [E|Events]) :-
    !,
    records_split(Rest, Logs, Events).
records_split([log(N, Role, Action, Status)|Rest],
              [log(N, Role, Action, Status)|Logs], Events) :-
    records_split(Rest, Logs, Events).

blank_entry(log(N, Role, Action, Status), entry(N, Role, Action, Status, [])).

%!  assign_event(+Event, +Entries0, -Entries) is det.
assign_event(roubo(Item, City, Revealed), Entries0, Entries) :-
    add_event_to_rob(Entries0, Item, roubo(Item, City, Revealed), Entries),
    !.
assign_event(Event, Entries, Entries) :-
    print_message(warning,
        format("match_replay: evento sem acao de roubo correspondente: ~q",
               [Event])).

%!  add_event_to_rob(+Entries0, +Item, +Event, -Entries) is semidet.
add_event_to_rob([entry(N, thief, roubar(Item), Status, Evs)|Rest], Item, Event,
                 [entry(N, thief, roubar(Item), Status, [Event|Evs])|Rest]) :-
    !.
add_event_to_rob([Entry|Rest], Item, Event, [Entry|Rest1]) :-
    add_event_to_rob(Rest, Item, Event, Rest1).

% Agrupa entradas consecutivas thief/detective do mesmo turno. A engine emite o
% log do ladrao antes do detetive em cada turno, com o mesmo numero N.
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
%   Monta o dict de um turno. Mantem as chaves antigas (thief_action, ...) por
%   compatibilidade e acrescenta a lista de eventos do turno.
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
%   Estrutura um evento da engine. Hoje o unico evento emitido e o roubo, que
%   carrega item, cidade e os atributos revelados (pistas ao detetive).
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

%!  setup_dict(+InitialState, +Scenario, -Setup) is det.
%
%   Extrai os metadados da partida do estado inicial gSt/7 sem tocar na engine:
%   cidades de partida, alvo do ladrao, aparencia, disfarces e limite de turnos.
%   Cai num dict minimo se o formato do estado nao for o esperado.
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
