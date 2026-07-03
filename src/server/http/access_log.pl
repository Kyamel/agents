:- module(access_log, []).

:- use_module(library(broadcast)).

% Log de acesso: uma linha por requisicao (metodo, rota, status, latencia, bytes,
% IP), no estilo de servidores node/fastapi. Nao toca nas rotas: engancha nos
% broadcasts que o http_wrapper emite em volta de TODA requisicao.
%
%   http(request_start(Id, Request))
%   http(request_finished(Id, Code, Status, CPU, Bytes))
%
% Basta carregar este modulo (server.pl faz o use_module) para ativar.

:- dynamic pending/2.

:- listen(http(request_start(Id, Request)), on_start(Id, Request)).
:- listen(http(request_finished(Id, Code, _Status, _CPU, Bytes)),
          on_finish(Id, Code, Bytes)).

% Guarda inicio + metodo/rota/ip por Id (mesma thread trata start e finish).
on_start(Id, Request) :-
    get_time(Start),
    request_method(Request, Method),
    request_path(Request, Path),
    request_peer(Request, Peer),
    assertz(pending(Id, req(Start, Method, Path, Peer))).

on_finish(Id, Code, Bytes) :-
    retract(pending(Id, req(Start, Method, Path, Peer))),
    !,
    get_time(End),
    Ms is (End - Start) * 1000,
    stamp(Now),
    format(user_output, "~w  ~w ~w  ~w  ~1f ms  ~w B  ~w~n",
           [Now, Method, Path, Code, Ms, Bytes, Peer]),
    flush_output(user_output).
on_finish(_Id, _Code, _Bytes).

request_method(Request, Method) :-
    memberchk(method(M), Request),
    !,
    upcase_atom(M, Method).
request_method(_Request, '-').

request_path(Request, Path) :-
    memberchk(request_uri(Path), Request),
    !.
request_path(Request, Path) :-
    memberchk(path(Path), Request),
    !.
request_path(_Request, '-').

request_peer(Request, IP) :-
    memberchk(peer(Peer), Request),
    !,
    peer_ip(Peer, IP).
request_peer(_Request, '-').

peer_ip(ip(A, B, C, D), IP) :-
    !,
    format(atom(IP), "~w.~w.~w.~w", [A, B, C, D]).
peer_ip(Peer, IP) :-
    term_to_atom(Peer, IP).

stamp(Now) :-
    get_time(T),
    format_time(atom(Now), '%T', T).
