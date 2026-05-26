:- module(web_session, [
    current_user/2,
    current_user_or_anon/2,
    require_user/2,
    revoke_web_session/1,
    send_session_redirect/2,
    send_logout_redirect/1
]).

:- use_module('../../db/sqlite_store').
:- use_module('../../auth/session_token').

%!  session_cookie_name(-Name) is det.
%
%   Nome do cookie usado para sessoes da interface web.
session_cookie_name(agents_session).

%!  current_user(+Request, -User) is semidet.
%
%   Resolve o usuario logado a partir do cookie de sessao da requisicao.
current_user(Request, User) :-
    session_token_from_request(Request, Token),
    session_token:token_hash(Token, TokenHash),
    sqlite_store:find_user_id_by_session_token_hash(TokenHash, UserId),
    sqlite_store:find_user_by_id(UserId, User).

%!  current_user_or_anon(+Request, -User) is det.
%
%   Igual a current_user/2, mas devolve o atomo `anon` quando nao ha sessao.
current_user_or_anon(Request, User) :-
    (   current_user(Request, Found)
    ->  User = Found
    ;   User = anon
    ).

%!  require_user(+Request, -User) is det.
%
%   Garante uma sessao valida; caso contrario redireciona para o login.
require_user(Request, User) :-
    (   current_user(Request, User)
    ->  true
    ;   throw(http_reply(see_other('/login?notice=login_required')))
    ).

%!  session_token_from_request(+Request, -Token) is semidet.
%
%   Extrai o token de sessao em texto puro do cabecalho Cookie.
session_token_from_request(Request, Token) :-
    memberchk(cookie(Cookies), Request),
    session_cookie_name(Name),
    memberchk(Name=Value, Cookies),
    cookie_value_string(Value, Token),
    Token \== "".

%!  cookie_value_string(+Value, -Str) is det.
%
%   Normaliza o valor de um cookie para string.
cookie_value_string(Value, Str) :-
    (   string(Value)
    ->  Str = Value
    ;   atom(Value)
    ->  atom_string(Value, Str)
    ;   term_string(Value, Str)
    ).

%!  revoke_web_session(+Request) is det.
%
%   Revoga (best-effort) a sessao associada ao cookie da requisicao.
revoke_web_session(Request) :-
    (   session_token_from_request(Request, Token)
    ->  session_token:token_hash(Token, TokenHash),
        catch(sqlite_store:revoke_auth_session(TokenHash), _, true)
    ;   true
    ).

%!  send_session_redirect(+Token, +Location) is det.
%
%   Emite resposta 303 que grava o cookie de sessao e redireciona.
send_session_redirect(Token, Location) :-
    session_cookie_name(Name),
    format("Status: 303 See Other~n"),
    format("Location: ~w~n", [Location]),
    format("Set-Cookie: ~w=~w; Path=/; HttpOnly; SameSite=Lax~n", [Name, Token]),
    format("Content-Type: text/html; charset=UTF-8~n~n"),
    format("<p>Redirecionando...</p>~n").

%!  send_logout_redirect(+Location) is det.
%
%   Emite resposta 303 que apaga o cookie de sessao e redireciona.
send_logout_redirect(Location) :-
    session_cookie_name(Name),
    format("Status: 303 See Other~n"),
    format("Location: ~w~n", [Location]),
    format("Set-Cookie: ~w=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0~n", [Name]),
    format("Content-Type: text/html; charset=UTF-8~n~n"),
    format("<p>Redirecionando...</p>~n").
