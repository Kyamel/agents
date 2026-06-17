:- module(main, [
    main/0,
    main_foreground/0
]).

:- use_module('./db/db').
:- use_module('./http/server').
:- use_module('./engine/engine').

%!  main is det.
%
%   Inicializa o banco e sobe o servidor HTTP em threads de fundo, entao em uso
%   interativo (`?- main.`) o top-level continua disponivel. Config em config.pl.
main :-
    db:init,
    server:start,
    engine:start_pool.

% Igual a main/0, mas bloqueia a thread principal para uso nao-interativo
% (`swipl -g main_foreground src/main.pl`).
main_foreground :-
    main,
    thread_get_message(_).

% Sobe a aplicacao automaticamente ao carregar este arquivo
% (`swipl src/main.pl`).
:- initialization(main).
