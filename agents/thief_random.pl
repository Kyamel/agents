:- module(thief_random, [
    thief_action/2
]).

:- use_module(library(random)).

thief_action(State, move(To)) :-
    Moves = State.available_moves,
    random_member(To, Moves).
