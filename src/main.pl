:- module(main, [
    main/0
]).

:- use_module('./config/env').
:- use_module('./db/sqlite_store').
:- use_module('./http/server').

%!  main is det.
%
%   Inicializa configuração, banco e servidor HTTP, mantendo o processo em
%   foreground.
main :-
    env:load_dotenv('.env'),
    sqlite_store:init,
    server:start,
    keep_foreground.

%!  keep_foreground is det.
%
%   Bloqueia a thread principal para impedir que o processo finalize após o
%   boot.
%keep_foreground :-
    % Blocks the main thread so the process does not exit after startup.
    %thread_get_message(_).

%:- initialization(main, main).
