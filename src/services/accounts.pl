:- module(accounts, [
    signup/4,
    login/3,
    verify_email_token/2,
    issue_session/3,
    normalize_username/2
]).

:- use_module('../config').
:- use_module('../db/db').
:- use_module('../infra/tokens').
:- use_module('../emails/verification_email').
:- use_module('./scopes').

% Servico de contas: cadastro, login, verificacao de email e emissao de sessao.
% Contem a regra de negocio e devolve outcomes; nao escreve resposta HTTP.

hash_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

% Com Hash ligado, crypto_password_hash/2 valida a senha contra ele.
verify_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

%!  signup(+Username, +EmailRaw, +Password, -Outcome) is det.
%
%   Cria um usuario e dispara o email de verificacao. `Outcome` e
%   `invalid_username`, `email_exists` ou `created(UserId, MailStatus)`.
signup(UsernameRaw, EmailRaw, Password, Outcome) :-
    normalize_username(UsernameRaw, Username),
    signup_validated(Username, EmailRaw, Password, Outcome).

signup_validated(Username, _EmailRaw, _Password, invalid_username) :-
    \+ valid_username(Username),
    !.
signup_validated(Username, EmailRaw, Password, Outcome) :-
    string_lower(EmailRaw, Email),
    do_signup(Username, Email, Password, Outcome).

valid_username(Username) :-
    string(Username),
    string_length(Username, Length),
    between(3, 60, Length),
    string_codes(Username, Codes),
    forall(member(Code, Codes), valid_username_code(Code)).

valid_username_code(Code) :- code_type(Code, alnum), !.
valid_username_code(32).  % espaco
valid_username_code(95).  % _
valid_username_code(45).  % -
valid_username_code(46).  % .

normalize_username(Raw, Normalized) :-
    string(Raw),
    !,
    string_codes(Raw, Codes),
    trim_edge_whitespace(Codes, Trimmed),
    string_codes(Normalized, Trimmed).
normalize_username(_Raw, "").

trim_edge_whitespace(Codes, Trimmed) :-
    drop_leading_whitespace(Codes, LeftTrimmed),
    reverse(LeftTrimmed, Reversed),
    drop_leading_whitespace(Reversed, RightTrimmedReversed),
    reverse(RightTrimmedReversed, Trimmed).

drop_leading_whitespace([Code|Codes], Trimmed) :-
    code_type(Code, space),
    !,
    drop_leading_whitespace(Codes, Trimmed).
drop_leading_whitespace(Codes, Codes).

do_signup(_, Email, _, email_exists) :-
    db:find_user_by_email(Email, _),
    !.
do_signup(Username, Email, Password, created(UserId, MailStatus)) :-
    hash_password(Password, PasswordHash),
    db:create_user(Username, Email, PasswordHash, UserId, _CreatedAt),
    scopes:promote_if_admin(Email),
    tokens:issue_token(PlainToken, TokenHash),
    config:email_verify_ttl_minutes(TtlMin),
    tokens:expiry_iso(TtlMin, ExpiresAt),
    db:save_email_verification(TokenHash, UserId, ExpiresAt, ExpiresAt),
    config:app_base_url(BaseUrl),
    format(string(VerifyUrl), '~s/auth/verify?token=~s', [BaseUrl, PlainToken]),
    verification_email:send_verification_email(Email, VerifyUrl, MailStatus).

%!  login(+EmailRaw, +Password, -Outcome) is det.
%
%   Autentica um usuario e emite uma sessao. `Outcome` e `invalid_credentials`,
%   `email_not_verified` ou `ok(Token, UserId, ExpiresAt)`.
login(EmailRaw, Password, Outcome) :-
    string_lower(EmailRaw, Email),
    find_user_or_anon(Email, UserOrAnon),
    authenticate(UserOrAnon, Password, Outcome).

find_user_or_anon(Email, User) :-
    db:find_user_by_email(Email, User),
    !.
find_user_or_anon(_, anon).

authenticate(anon, _, invalid_credentials) :- !.
authenticate(User, Password, invalid_credentials) :-
    \+ verify_password(Password, User.password_hash),
    !.
authenticate(User, _, email_not_verified) :-
    User.is_verified \== true,
    !.
authenticate(User, _, ok(Token, UserId, ExpiresAt)) :-
    UserId = User.id,
    issue_session(UserId, Token, ExpiresAt).

issue_session(UserId, Token, ExpiresAt) :-
    config:auth_session_ttl_minutes(TtlMin),
    tokens:issue_token(Token, TokenHash),
    tokens:expiry_iso(TtlMin, ExpiresAt),
    tokens:now_iso(CreatedAt),
    db:save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt).

%!  verify_email_token(+PlainToken, -Outcome) is det.
%
%   Consome token de verificacao de email e ativa o usuario. `Outcome` e
%   `verified(UserId)` ou `invalid_or_expired_token`.
verify_email_token(PlainToken, Outcome) :-
    tokens:token_hash(PlainToken, TokenHash),
    consume_and_mark(TokenHash, Outcome).

consume_and_mark(TokenHash, verified(UserId)) :-
    db:consume_email_verification(TokenHash, UserId),
    !,
    db:mark_user_verified(UserId).
consume_and_mark(_, invalid_or_expired_token).
