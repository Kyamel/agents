:- module(main, [
    main/0,
    main_foreground/0
]).

:- use_module('./db/sqlite_store').
:- use_module('./http/server').
:- use_module('./engine/match_queue').

%!  main is det.
%
%   Inicializa o banco e sobe o servidor HTTP. O servidor roda em threads de
%   fundo, portanto em uso interativo (`?- main.`) o top-level do Prolog
%   continua disponivel. A configuracao fica em `src/config.pl`.
main :-
    sqlite_store:init,
    server:start,
    match_queue:start_pool.

%!  main_foreground is det.
%
%   Igual a main/0, mas bloqueia a thread pgitrincipal para que o processo nao
%   finalize apos o boot. Util em execucao nao-interativa, por exemplo:
%   `swipl -g main_foreground src/main.pl`.
main_foreground :-
    main,
    thread_get_message(_).

% Sobe a aplicacao automaticamente ao carregar este arquivo
% (`swipl src/main.pl`), mantendo o top-level interativo logo em seguida.
:- initialization(main).
