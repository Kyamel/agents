:- module(web_session, [
    current_user/2,
    current_user_or_anon/2,
    require_user/2,
    revoke_web_session/1,
    send_session_redirect/2,
    send_logout_redirect/1
]).

:- use_module('../../db/db').
:- use_module('../../infra/tokens').

session_cookie_name(agents_session).

% Resolve o usuario logado a partir do cookie de sessao da requisicao.
current_user(Request, User) :-
    session_token_from_request(Request, Token),
    tokens:token_hash(Token, TokenHash),
    db:find_user_id_by_session_token_hash(TokenHash, UserId),
    db:find_user_by_id(UserId, User).

current_user_or_anon(Request, User) :-
    current_user(Request, User),
    !.
current_user_or_anon(_Request, anon).

% Garante uma sessao valida; senao redireciona para o login.
require_user(Request, User) :-
    current_user(Request, User),
    !.
require_user(_Request, _User) :-
    throw(http_reply(see_other('/login?notice=login_required'))).

% Token em texto puro vindo do cabecalho Cookie.
session_token_from_request(Request, Token) :-
    memberchk(cookie(Cookies), Request),
    session_cookie_name(Name),
    memberchk(Name=Value, Cookies),
    cookie_value_string(Value, Token),
    Token \== "".

cookie_value_string(Value, Value) :-
    string(Value),
    !.
cookie_value_string(Value, Str) :-
    atom(Value),
    !,
    atom_string(Value, Str).
cookie_value_string(Value, Str) :-
    term_string(Value, Str).

% Best-effort: ignora falha/ausencia de sessao.
revoke_web_session(Request) :-
    session_token_from_request(Request, Token),
    !,
    tokens:token_hash(Token, TokenHash),
    catch(db:revoke_auth_session(TokenHash), _, true).
revoke_web_session(_Request).

% 303 que grava o cookie de sessao (HttpOnly) e redireciona.
send_session_redirect(Token, Location) :-
    session_cookie_name(Name),
    format("Status: 303 See Other~n"),
    format("Location: ~w~n", [Location]),
    format("Set-Cookie: ~w=~w; Path=/; HttpOnly; SameSite=Lax~n", [Name, Token]),
    format("Content-Type: text/html; charset=UTF-8~n~n"),
    format("<p>Redirecionando...</p>~n").

% 303 que apaga o cookie de sessao (Max-Age=0) e redireciona.
send_logout_redirect(Location) :-
    session_cookie_name(Name),
    format("Status: 303 See Other~n"),
    format("Location: ~w~n", [Location]),
    format("Set-Cookie: ~w=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0~n", [Name]),
    format("Content-Type: text/html; charset=UTF-8~n~n"),
    format("<p>Redirecionando...</p>~n").
