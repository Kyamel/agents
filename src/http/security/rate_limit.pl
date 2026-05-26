:- module(rate_limit, [
    enforce_ip_rate_limit/1,
    request_ip/2,
    reset_rate_limit_state/0
]).

:- use_module(library(http/http_header)).
:- use_module(library(http/http_dispatch)).
:- use_module('../../config/env').

:- dynamic bucket/4.
% bucket(IP, WindowStartEpochSec, Count, WindowSec).

%!  reset_rate_limit_state is det.
%
%   Limpa todo o estado em memória de rate-limit.
reset_rate_limit_state :-
    retractall(bucket(_, _, _, _)).

%!  enforce_ip_rate_limit(+Request) is det.
%
%   Consome um token do bucket associado ao IP da requisição.
enforce_ip_rate_limit(Request) :-
    env:env_int('RATE_LIMIT_WINDOW_SEC', 60, WindowSec),
    env:env_int('RATE_LIMIT_MAX', 120, MaxPerWindow),
    request_ip(Request, IP),
    now_epoch_sec(Now),
    take_token(IP, Now, WindowSec, MaxPerWindow).

%!  request_ip(+Request, -IP) is det.
%
%   Extrai IP do `x-forwarded-for` (quando habilitado) ou do peer da conexão.
request_ip(Request, IP) :-
    env:env_bool('TRUST_PROXY', false, true),
    memberchk(x_forwarded_for(Xff), Request),
    atom_string(Xff, XffStr),
    split_string(XffStr, ",", " ", [First|_]),
    First \= "",
    !,
    IP = First.
request_ip(Request, IP) :-
    memberchk(peer(Peer), Request),
    !,
    term_string(Peer, IP).
request_ip(_, "unknown").

%!  now_epoch_sec(-Now) is det.
%
%   Devolve timestamp atual em segundos Unix.
now_epoch_sec(Now) :-
    get_time(T),
    Now is floor(T).

%!  take_token(+IP, +Now, +WindowSec, +MaxPerWindow) is det.
%
%   Aplica lógica de rate-limit sob mutex para um IP.
take_token(IP, Now, WindowSec, MaxPerWindow) :-
    with_mutex(rate_limit, take_token_locked(IP, Now, WindowSec, MaxPerWindow)).

%!  take_token_locked(+IP, +Now, +WindowSec, +MaxPerWindow) is det.
%
%   Atualiza bucket do IP e lança erro HTTP 429 quando excede limite.
take_token_locked(IP, Now, WindowSec, MaxPerWindow) :-
    (   retract(bucket(IP, WindowStart, Count, WindowSec))
    ->  Age is Now - WindowStart,
        (   Age < WindowSec
        ->  (   Count < MaxPerWindow
            ->  NextCount is Count + 1,
                assertz(bucket(IP, WindowStart, NextCount, WindowSec))
            ;   assertz(bucket(IP, WindowStart, Count, WindowSec)),
                throw(http_reply(too_many_requests('rate_limit_exceeded')))
            )
        ;   assertz(bucket(IP, Now, 1, WindowSec))
        )
    ;   assertz(bucket(IP, Now, 1, WindowSec))
    ).
