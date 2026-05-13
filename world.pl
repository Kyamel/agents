:- module(world, [
    initial_state/1,
    available_moves/3,
    apply_move/4,
    winner/2,
    visible_state_for/3
]).

% -----------------------------
% Mapa
% -----------------------------

edge(a, b).
edge(b, c).
edge(c, d).
edge(c, e).
edge(d, f).
edge(e, exit_1).
edge(f, exit_2).

connected(X, Y) :- edge(X, Y).
connected(X, Y) :- edge(Y, X).

exit(exit_1).
exit(exit_2).

% -----------------------------
% Estado inicial
% -----------------------------

initial_state(_{
    turn: 0,
    max_turns: 20,
    thief_position: a,
    detective_position: f,
    last_known_thief_position: a,
    history: []
}).

% -----------------------------
% Movimentos
% -----------------------------

available_moves(thief, State, Moves) :-
    Pos = State.thief_position,
    findall(To, connected(Pos, To), Moves).

available_moves(detective, State, Moves) :-
    Pos = State.detective_position,
    findall(To, connected(Pos, To), Moves).

apply_move(thief, move(To), State, NewState) :-
    available_moves(thief, State, Moves),
    memberchk(To, Moves),
    NewState = State.put(thief_position, To).

apply_move(detective, move(To), State, NewState) :-
    available_moves(detective, State, Moves),
    memberchk(To, Moves),
    NewState = State.put(detective_position, To).

% Movimento inválido: fica parado.
apply_move(thief, _, State, State).
apply_move(detective, _, State, State).

% -----------------------------
% Estado visível para agentes
% -----------------------------

visible_state_for(thief, State, Visible) :-
    available_moves(thief, State, Moves),
    Visible = _{
        role: "thief",
        turn: State.turn,
        my_position: State.thief_position,
        detective_position: State.detective_position,
        exits: [exit_1, exit_2],
        available_moves: Moves
    }.

visible_state_for(detective, State, Visible) :-
    available_moves(detective, State, Moves),
    Visible = _{
        role: "detective",
        turn: State.turn,
        my_position: State.detective_position,
        last_known_thief_position: State.last_known_thief_position,
        available_moves: Moves
    }.

% -----------------------------
% Vitória
% -----------------------------

winner(State, thief) :-
    exit(State.thief_position), !.

winner(State, detective) :-
    State.thief_position == State.detective_position, !.

winner(State, draw) :-
    State.turn >= State.max_turns, !.
