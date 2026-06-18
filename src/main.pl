:- module(main, [
    main/0,
    main_foreground/0
]).

:- use_module('./db/db').
:- use_module('./server/server').
:- use_module('./engine/engine').

:- dynamic app_started/0.

%!  main is det.
%
%   Inicializa o banco e sobe o servidor HTTP em threads de fundo, então em uso
%   interativo (`?- main.`) o top-level continua disponivel. Config em config.pl.
main :-
    with_mutex(app_bootstrap, ensure_started).

ensure_started :-
    app_started,
    !.
ensure_started :-
    db:init,
    server:start,
    engine:start_pool,
    assertz(app_started).

% Igual a main/0, mas bloqueia a thread principal para uso nao-interativo
% (`swipl -g main_foreground src/main.pl`).
main_foreground :-
    main,
    thread_get_message(_).

% Sobe a aplicacao automaticamente ao carregar este arquivo
% (`swipl src/main.pl`).
:- initialization(main).
