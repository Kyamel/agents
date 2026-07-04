:- module(match_map_data, [
    map_data/3,
    replay_frames/4,
    frame_events/2
]).

:- use_module(library(apply)).
:- use_module(library(lists)).
:- use_module('../../engine/engine').
:- use_module('../../engine/match_replay', [term_text/2]).

%!  map_data(+Scenario, +Replay, -Data) is det.
%
%   Projeta o replay no formato final consumido pelo mapa. O navegador recebe
%   frames prontos e fica responsavel apenas por apresentacao e playback.
map_data(Scenario, Replay, Data) :-
    replay_field(Replay, setup, _{}, Setup),
    replay_field(Replay, turns, [], Turns),
    graph_for(Scenario, Cities, Edges),
    map_objective(Scenario, Setup, Objective),
    map_loot(Scenario, Loot),
    map_thief_identity(Scenario, Setup, ThiefIdentity),
    replay_frames(Setup, Turns, Objective, Frames0),
    map_mandate_names(Scenario, Frames0, Frames),
    Data = _{
        cities: Cities,
        edges: Edges,
        loot: Loot,
        objective: Objective,
        'thiefIdentity': ThiefIdentity,
        frames: Frames
    }.

replay_field(Dict, Key, _Default, Value) :-
    get_dict(Key, Dict, Value),
    !.
replay_field(_Dict, _Key, Default, Default).

graph_for(Scenario, Cities, Edges) :-
    catch(engine:scenario_graph(Scenario, Cities, Edges), _, fail),
    !.
graph_for(_Scenario, [], []).

map_objective(Scenario, Setup, Objective) :-
    get_dict(target, Setup, Target),
    engine:scenario_treasure(Scenario, Target, City0, Requirements0),
    !,
    term_text(Target, Name),
    term_text(City0, City),
    maplist(term_text, Requirements0, Requirements),
    Objective = _{
        name: Name,
        city: City,
        requirements: Requirements
    }.
map_objective(_, _, _{name: null, city: null, requirements: []}).

map_loot(Scenario, LootDicts) :-
    scenario_loot_safe(Scenario, Loot),
    maplist(loot_dict, Loot, LootDicts).

scenario_loot_safe(Scenario, Loot) :-
    catch(engine:scenario_loot(Scenario, Loot), _, fail),
    !.
scenario_loot_safe(_Scenario, []).

map_thief_identity(Scenario, Setup, Identity) :-
    get_dict(thief_id, Setup, Id0),
    catch(engine:scenario_suspect(Scenario, Id0, Name0), _, fail),
    !,
    term_text(Id0, Id),
    term_text(Name0, Name),
    Identity = _{id: Id, name: Name}.
map_thief_identity(_Scenario, _Setup, null).

map_mandate_names(Scenario, Frames0, Frames) :-
    maplist(map_frame_mandate_name(Scenario), Frames0, Frames).

map_frame_mandate_name(_Scenario, Frame, Frame) :-
    Frame.mandate == null,
    !.
map_frame_mandate_name(Scenario, Frame0, Frame) :-
    Mandate0 = Frame0.mandate,
    catch(engine:scenario_suspect(
              Scenario,
              Mandate0.suspect,
              SuspectName0
          ), _, fail),
    !,
    term_text(SuspectName0, SuspectName),
    Mandate = Mandate0.put('suspectName', SuspectName),
    Frame = Frame0.put(mandate, Mandate).
map_frame_mandate_name(_Scenario, Frame, Frame).

loot_dict(loot(Kind0, Name0, City0, Requirements0), Dict) :-
    term_text(Kind0, Kind),
    term_text(Name0, Name),
    term_text(City0, City),
    maplist(term_text, Requirements0, Requirements),
    Dict = _{
        kind: Kind,
        name: Name,
        city: City,
        requirements: Requirements
    }.

%!  replay_frames(+Setup, +Turns, +Objective, -Frames) is det.
%
%   Resolve todo o estado acumulado do replay. `Turns` historicamente pode vir
%   em qualquer ordem; a UI sempre o apresentou do maior numero para o menor.
replay_frames(Setup, Turns0, Objective, [InitialFrame|TurnFrames]) :-
    initial_state(Setup, State0),
    frame_from_state(
        "Início",
        Objective,
        [],
        "",
        [],
        State0,
        InitialFrame
    ),
    predsort(compare_turn_desc, Turns0, Turns),
    turn_frames(Turns, Objective, State0, TurnFrames),
    !.

compare_turn_desc(Order, Left, Right) :-
    get_dict(turn, Left, LeftTurn),
    get_dict(turn, Right, RightTurn),
    compare(Order, RightTurn, LeftTurn).

initial_state(Setup, State) :-
    replay_field(Setup, thief_start, null, Thief),
    replay_field(Setup, detective_start, null, Detective),
    replay_field(Setup, lock_mode, "accumulate", LockMode),
    replay_field(Setup, appearance, [], Appearance0),
    initial_appearance(Appearance0, Appearance),
    initial_path(Thief, ThiefPath),
    initial_path(Detective, DetectivePath),
    State = _{
        thief: Thief,
        detective: Detective,
        thief_path: ThiefPath,
        detective_path: DetectivePath,
        blocked: [],
        lock_mode: LockMode,
        collected: [],
        appearance: Appearance,
        revealed: [],
        mandate: null
    }.

initial_path(City, [City]) :-
    valid_city(City),
    !.
initial_path(_, []).

turn_frames([], _Objective, _State, []).
turn_frames([Turn|Turns], Objective, State0, [Frame|Frames]) :-
    apply_turn(Turn, Objective, State0, State, Frame),
    turn_frames(Turns, Objective, State, Frames).

apply_turn(Turn, Objective, State0, State, Frame) :-
    replay_field(Turn, thief_position, "-", ThiefPosition),
    replay_field(Turn, detective_position, "-", DetectivePosition),
    advance_position(
        ThiefPosition,
        State0.thief,
        State0.thief_path,
        Thief,
        ThiefPath
    ),
    advance_position(
        DetectivePosition,
        State0.detective,
        State0.detective_path,
        Detective,
        DetectivePath
    ),
    replay_field(Turn, thief_action, "", ThiefAction),
    replay_field(Turn, detective_action, "", DetectiveAction),
    replay_field(Turn, thief_status, "", ThiefStatus),
    replay_field(Turn, detective_status, "", DetectiveStatus),
    replay_field(Turn, events, [], RawEvents),
    robbery_details(RawEvents, StolenItems, RobberyCities, Robberies),
    lock_effect(DetectiveAction, DetectiveStatus, LockEffect, LockCity),
    update_blocked(
        State0.blocked,
        LockEffect,
        LockCity,
        State0.lock_mode,
        Blocked
    ),
    append_unique(State0.collected, StolenItems, Collected),
    disguise_effect(ThiefAction, ThiefStatus, DisguiseEffect),
    apply_disguise(State0.appearance, DisguiseEffect, Appearance),
    robbery_revealed(Robberies, RevealedNow),
    append_unique(State0.revealed, RevealedNow, Revealed),
    mandate_effect(DetectiveAction, DetectiveStatus, MandateEffect),
    apply_mandate(State0.mandate, MandateEffect, Mandate),
    State = State0.put(_{
        thief: Thief,
        detective: Detective,
        thief_path: ThiefPath,
        detective_path: DetectivePath,
        blocked: Blocked,
        collected: Collected,
        appearance: Appearance,
        revealed: Revealed,
        mandate: Mandate
    }),
    get_dict(turn, Turn, Number),
    turn_events(
        Number,
        Turn,
        Robberies,
        DisguiseEffect,
        MandateEffect,
        Detective,
        Mandate,
        Events
    ),
    events_text(Events, EventText),
    format(string(Label), "Turno ~w", [Number]),
    frame_from_state(
        Label,
        Objective,
        RobberyCities,
        EventText,
        Events,
        State,
        Frame
    ).

advance_position(New, Current0, Path0, Current, Path) :-
    valid_city(New),
    !,
    Current = New,
    append_if_changed(Path0, Current0, New, Path).
advance_position(_, Current, Path, Current, Path).

append_if_changed(Path, Current, Current, Path) :-
    !.
append_if_changed(Path0, _Current, New, Path) :-
    append(Path0, [New], Path).

valid_city(City) :-
    City \== null,
    City \== "",
    City \== "-".

frame_from_state(
    Label,
    Objective,
    RobberyCities,
    EventText,
    Events,
    State,
    Frame
) :-
    objective_ready(Objective, State.collected, ObjectiveReady),
    Frame = _{
        label: Label,
        t: State.thief,
        d: State.detective,
        'tPath': State.thief_path,
        'dPath': State.detective_path,
        blocked: State.blocked,
        'objectiveCity': Objective.city,
        'objectiveReady': ObjectiveReady,
        'robberyCities': RobberyCities,
        'eventText': EventText,
        events: Events,
        appearance: State.appearance,
        revealed: State.revealed,
        collected: State.collected,
        mandate: State.mandate
    }.

%!  frame_events(+Frames, -Events) is det.
%
%   Achata a timeline estruturada guardada em cada frame.
frame_events(Frames, Events) :-
    maplist(frame_event_list, Frames, Nested),
    append(Nested, Events).

frame_event_list(Frame, Events) :-
    replay_field(Frame, events, [], Events).

objective_ready(Objective, Collected, true) :-
    valid_city(Objective.city),
    forall(member(Requirement, Objective.requirements),
           memberchk(Requirement, Collected)),
    !.
objective_ready(_, _, false).

robbery_details(Events, Items, Cities, Robberies) :-
    include(robbery_event, Events, Robberies),
    findall(Item,
            ( member(Event, Robberies),
              get_dict(item, Event, Item)
            ),
            Items),
    findall(City,
            ( member(Event, Robberies),
              get_dict(city, Event, City)
            ),
            Cities).

robbery_event(Event) :-
    get_dict(type, Event, "robbery").

robbery_revealed(Robberies, Revealed) :-
    findall(Value,
            ( member(Robbery, Robberies),
              replay_field(Robbery, revealed, [], Values),
              member(Value, Values)
            ),
            Revealed).

append_unique(Existing, Values, Result) :-
    foldl(append_unique_value, Values, Existing, Result).

append_unique_value(Value, Values, Values) :-
    memberchk(Value, Values),
    !.
append_unique_value(Value, Values0, Values) :-
    append(Values0, [Value], Values).

initial_appearance(Attributes, Appearance) :-
    maplist(initial_attribute, Attributes, Appearance).

initial_attribute(Attribute0, _{original: Attribute, current: Attribute}) :-
    term_text(Attribute0, Attribute).

disguise_effect(Action, Status, apply(Changes)) :-
    status_ok(Status),
    action_term(Action, disfarce(RawChanges)),
    is_list(RawChanges),
    !,
    maplist(disguise_change, RawChanges, Changes).
disguise_effect(Action, Status, remove) :-
    status_ok(Status),
    action_term(Action, despir_disfarce),
    !.
disguise_effect(_, _, none).

disguise_change(trocar(Original0, Current0), replace(Original, Current)) :-
    !,
    term_text(Original0, Original),
    term_text(Current0, Current).
disguise_change(omitir(Original0), omit(Original)) :-
    !,
    term_text(Original0, Original).
disguise_change(adicionar(Current0), add(Current)) :-
    !,
    term_text(Current0, Current).
disguise_change(_, unknown).

apply_disguise(Appearance, none, Appearance).
apply_disguise(Appearance0, remove, Appearance) :-
    findall(_{original: Original, current: Original},
            ( member(Attribute, Appearance0),
              Original = Attribute.original,
              Original \== null
            ),
            Appearance).
apply_disguise(Appearance0, apply(Changes), Appearance) :-
    include(add_change, Changes, AddChanges),
    maplist(added_attribute, AddChanges, Additions),
    exclude(add_change, Changes, AttributeChanges),
    foldl(apply_attribute_change, AttributeChanges, Appearance0, Changed),
    append(Additions, Changed, Appearance).

add_change(add(_)).

added_attribute(add(Current), _{original: null, current: Current}).

apply_attribute_change(replace(Original, Current), Appearance0, Appearance) :-
    !,
    replace_current(Appearance0, Original, Current, Appearance).
apply_attribute_change(omit(Original), Appearance0, Appearance) :-
    !,
    replace_current(Appearance0, Original, null, Appearance).
apply_attribute_change(_, Appearance, Appearance).

replace_current([], _Original, _Current, []).
replace_current([Attribute|Rest], Original, Current, [Changed|Rest]) :-
    Attribute.current == Original,
    !,
    Changed = Attribute.put(current, Current).
replace_current([Attribute|Rest0], Original, Current, [Attribute|Rest]) :-
    replace_current(Rest0, Original, Current, Rest).

mandate_effect(Action, Status, set(Mandate)) :-
    status_ok(Status),
    action_term(Action, pedir_mandato(Suspect0, Clues0)),
    is_list(Clues0),
    !,
    term_text(Suspect0, Suspect),
    maplist(term_text, Clues0, Clues),
    Mandate = _{suspect: Suspect, clues: Clues}.
mandate_effect(_, _, none).

apply_mandate(Mandate, none, Mandate).
apply_mandate(_Previous, set(Mandate), Mandate).

lock_effect(Action, Status, close, City) :-
    status_ok(Status),
    action_term(Action, fechar(City0)),
    !,
    term_text(City0, City).
lock_effect(Action, Status, open, City) :-
    status_ok(Status),
    action_term(Action, liberar(City0)),
    !,
    term_text(City0, City).
lock_effect(_, _, none, null).

update_blocked(Blocked, none, _City, _Mode, Blocked) :-
    !.
update_blocked(_Blocked, close, City, Mode, [City]) :-
    single_lock_mode(Mode),
    !.
update_blocked(Blocked, close, City, _Mode, Blocked) :-
    memberchk(City, Blocked),
    !.
update_blocked(Blocked0, close, City, _Mode, Blocked) :-
    append(Blocked0, [City], Blocked).
update_blocked(Blocked0, open, City, _Mode, Blocked) :-
    exclude(==(City), Blocked0, Blocked).

single_lock_mode("single").
single_lock_mode(single).

turn_events(
    Number,
    Turn,
    Robberies,
    DisguiseEffect,
    MandateEffect,
    DetectiveCity,
    Mandate,
    Events
) :-
    maplist(robbery_timeline_event(Number), Robberies, RobberyEvents),
    disguise_timeline_event(Number, Turn, DisguiseEffect, DisguiseEvents),
    mandate_timeline_event(Number, MandateEffect, Mandate, MandateEvents),
    inspection_timeline_event(
        Number,
        Turn,
        DetectiveCity,
        Mandate,
        InspectionEvents
    ),
    append(
        [RobberyEvents, DisguiseEvents, MandateEvents, InspectionEvents],
        Events
    ).

events_text(Events, Text) :-
    maplist(event_text, Events, Texts),
    atomics_to_string(Texts, "\n", Text).

event_text(Event, Text) :-
    get_dict(text, Event, Text).

robbery_timeline_event(Number, Robbery, Event) :-
    single_robbery_text(Robbery, Text),
    replay_field(Robbery, revealed, [], Revealed),
    Event = _{
        type: "robbery",
        agent: "thief",
        turn: Number,
        item: Robbery.item,
        city: Robbery.city,
        revealed: Revealed,
        text: Text
    }.

single_robbery_text(Robbery, Text) :-
    replay_field(Robbery, revealed, [], Revealed),
    maplist(value_string, Revealed, RevealedText),
    atomics_to_string(RevealedText, ", ", RevealedList),
    value_string(Robbery.item, Item),
    value_string(Robbery.city, City),
    format(string(Text), "roubo(~s, ~s, [~s])", [Item, City, RevealedList]).

disguise_event_text(Turn, Effect, Text) :-
    Effect \== none,
    !,
    replay_field(Turn, thief_action, "", Action0),
    value_string(Action0, Action),
    string_concat("Disfarce: ", Action, Text).
disguise_event_text(_, _, "").

disguise_timeline_event(Number, Turn, Effect, [Event]) :-
    disguise_event_text(Turn, Effect, Text),
    Text \== "",
    !,
    replay_field(Turn, thief_action, "", Action),
    Event = _{
        type: "disguise",
        agent: "thief",
        turn: Number,
        action: Action,
        text: Text
    }.
disguise_timeline_event(_, _, _, []).

mandate_event_text(set(_), Mandate, Text) :-
    !,
    mandate_term_text(Mandate, TermText),
    string_concat("Mandato emitido: ", TermText, Text).
mandate_event_text(_, _, "").

mandate_timeline_event(Number, set(_), Mandate, [Event]) :-
    !,
    mandate_event_text(set(Mandate), Mandate, Text),
    Event = _{
        type: "mandate",
        agent: "detective",
        turn: Number,
        suspect: Mandate.suspect,
        clues: Mandate.clues,
        text: Text
    }.
mandate_timeline_event(_, _, _, []).

inspection_event_text(Turn, DetectiveCity, Mandate, Text) :-
    replay_field(Turn, detective_action, "", Action),
    replay_field(Turn, detective_status, "", Status),
    status_ok(Status),
    action_term(Action, inspecionar),
    !,
    value_string(DetectiveCity, City),
    inspection_mandate_text(Mandate, MandateText),
    format(string(Text), "Inspeção em ~s — ~s", [City, MandateText]).
inspection_event_text(_, _, _, "").

inspection_timeline_event(
    Number,
    Turn,
    DetectiveCity,
    Mandate,
    [Event]
) :-
    inspection_event_text(Turn, DetectiveCity, Mandate, Text),
    Text \== "",
    !,
    Event = _{
        type: "inspection",
        agent: "detective",
        turn: Number,
        city: DetectiveCity,
        mandate: Mandate,
        text: Text
    }.
inspection_timeline_event(_, _, _, _, []).

inspection_mandate_text(null, "sem mandato ativo") :-
    !.
inspection_mandate_text(Mandate, Text) :-
    mandate_term_text(Mandate, TermText),
    string_concat("mandato ativo: ", TermText, Text).

mandate_term_text(null, "nenhum") :-
    !.
mandate_term_text(Mandate, Text) :-
    value_string(Mandate.suspect, Suspect),
    maplist(value_string, Mandate.clues, Clues),
    atomics_to_string(Clues, ", ", ClueList),
    format(string(Text), "pedir_mandato(~s, [~s])", [Suspect, ClueList]).

value_string(Value, Text) :-
    term_text(Value, TermText),
    ( string(TermText) ->
        Text = TermText
    ; number_string(TermText, Text)
    ).

status_ok("OK").
status_ok('OK').

action_term(Term, Term) :-
    compound(Term),
    !.
action_term(Text, Term) :-
    string(Text),
    catch(term_string(Term, Text), _, fail),
    !.
action_term(Atom, Term) :-
    atom(Atom),
    catch(atom_to_term(Atom, Term, _), _, fail).
