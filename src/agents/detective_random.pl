:- module(detective_random, [
    detective_action/2
]).

:- use_module(library(random)).

detective_action(State, move(To)) :-
    Moves = State.available_moves,
    random_member(To, Moves).
