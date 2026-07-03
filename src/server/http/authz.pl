:- module(authz, [
    require_bearer_token/2
]).

:- use_module(library(http/http_header)).
:- use_module('../../infra/tokens').
:- use_module('../../db/db').

% Valida `Authorization: Bearer ...` e retorna o UserId da sessao; senao 401.
require_bearer_token(Request, UserId) :-
    memberchk(authorization(Auth), Request),
    atom_string(Auth, AuthStr),
    split_string(AuthStr, " ", "", [Scheme, Token]),
    string_lower(Scheme, "bearer"),
    Token \= "",
    tokens:token_hash(Token, TokenHash),
    db:find_user_id_by_session_token_hash(TokenHash, UserId),
    !.
require_bearer_token(_, _) :-
    throw(http_reply(authorise(bearer))).
