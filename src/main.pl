:- module(main, [
    main/0,
    main_foreground/0
]).

:- use_module('./config/env').
:- use_module('./db/sqlite_store').
:- use_module('./http/server').

%!  main is det.
%
%   Carrega o `.env`, inicializa o banco e sobe o servidor HTTP. O servidor
%   roda em threads de fundo, portanto em uso interativo (`?- main.`) o
%   top-level do Prolog continua disponivel.
main :-
    env:load_dotenv('.env'),
    sqlite_store:init,
    server:start.

%!  main_foreground is det.
%
%   Igual a main/0, mas bloqueia a thread principal para que o processo nao
%   finalize apos o boot. Util em execucao nao-interativa, por exemplo:
%   `swipl -g main_foreground src/main.pl`.
main_foreground :-
    main,
    thread_get_message(_).

% Sobe a aplicacao automaticamente ao carregar este arquivo
% (`swipl src/main.pl`), mantendo o top-level interativo logo em seguida.
:- initialization(main).
