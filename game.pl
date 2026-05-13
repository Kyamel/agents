:- module(game, [
    run_match/3
]).

:- use_module(world).

% Agentes padrão embutidos por enquanto.
:- use_module(agents/thief_random).
:- use_module(agents/detective_random).

run_match(ThiefAgent, DetectiveAgent, Result) :-
    world:initial_state(InitialState),
    loop(ThiefAgent, DetectiveAgent, InitialState, FinalState, Winner),

    Result = _{
        thief_agent_id: ThiefAgent.id,
        detective_agent_id: DetectiveAgent.id,
        winner: Winner,
        final_turn: FinalState.turn,
        final_state: FinalState,
        replay: FinalState.history
    }.

loop(_ThiefAgent, _DetectiveAgent, State, State, Winner) :-
    world:winner(State, Winner), !.

loop(ThiefAgent, DetectiveAgent, State, FinalState, Winner) :-
    take_turn(ThiefAgent, DetectiveAgent, State, NextState),
    loop(ThiefAgent, DetectiveAgent, NextState, FinalState, Winner).

take_turn(ThiefAgent, DetectiveAgent, State, NewState) :-
    State0 = State,

    call_agent(thief, ThiefAgent, State0, ThiefAction),
    world:apply_move(thief, ThiefAction, State0, State1),

    call_agent(detective, DetectiveAgent, State1, DetectiveAction),
    world:apply_move(detective, DetectiveAction, State1, State2),

    NewTurn is State2.turn + 1,

    TurnLog = _{
        turn: NewTurn,
        thief_action: ThiefAction,
        detective_action: DetectiveAction,
        thief_position: State2.thief_position,
        detective_position: State2.detective_position
    },

    OldHistory = State2.history,
    append(OldHistory, [TurnLog], NewHistory),

    NewState = State2.put(_{
        turn: NewTurn,
        history: NewHistory,
        last_known_thief_position: State2.thief_position
    }).

call_agent(thief, _Agent, State, Action) :-
    world:visible_state_for(thief, State, VisibleState),
    catch(
        thief_random:thief_action(VisibleState, Action),
        _Error,
        Action = stay
    ).

call_agent(detective, _Agent, State, Action) :-
    world:visible_state_for(detective, State, VisibleState),
    catch(
        detective_random:detective_action(VisibleState, Action),
        _Error,
        Action = stay
    ).
