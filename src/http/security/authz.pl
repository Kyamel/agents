:- module(authz, [
    require_bearer_token/2
]).

:- use_module(library(http/http_header)).
:- use_module('../../auth/session_token').
:- use_module('../../db/sqlite_store').

%!  require_bearer_token(+Request, -UserId) is semidet.
%
%   Valida header `Authorization: Bearer ...` e retorna o `UserId` da sessão.
require_bearer_token(Request, UserId) :-
    memberchk(authorization(Auth), Request),
    atom_string(Auth, AuthStr),
    split_string(AuthStr, " ", "", [Scheme, Token]),
    string_lower(Scheme, "bearer"),
    Token \= "",
    session_token:token_hash(Token, TokenHash),
    sqlite_store:find_user_id_by_session_token_hash(TokenHash, UserId),
    !.
require_bearer_token(_, _) :-
    throw(http_reply(authorise(bearer))).
