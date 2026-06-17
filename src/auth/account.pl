:- module(account, [
    signup/4,
    login/3,
    verify_email_token/2,
    issue_session/3
]).

:- use_module('../config').
:- use_module('../db/db').
:- use_module('./verify_email', []).
:- use_module('./session_token', []).
:- use_module('./mail').

hash_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

% Com Hash ligado, crypto_password_hash/2 valida a senha contra ele.
verify_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

%!  signup(+Username, +EmailRaw, +Password, -Outcome) is det.
%
%   Cria um usuario e dispara o email de verificacao. `Outcome` e
%   `email_exists` ou `created(UserId, MailStatus)`.
signup(Username, EmailRaw, Password, Outcome) :-
    string_lower(EmailRaw, Email),
    do_signup(Username, Email, Password, Outcome).

do_signup(_, Email, _, email_exists) :-
    db:find_user_by_email(Email, _),
    !.
do_signup(Username, Email, Password, created(UserId, MailStatus)) :-
    hash_password(Password, PasswordHash),
    db:create_user(Username, Email, PasswordHash, UserId, _CreatedAt),
    verify_email:issue_verification_token(UserId, PlainToken, TokenHash),
    config:email_verify_ttl_minutes(TtlMin),
    verify_email:expiry_iso(TtlMin, ExpiresAt),
    db:save_email_verification(TokenHash, UserId, ExpiresAt, ExpiresAt),
    config:app_base_url(BaseUrl),
    format(string(VerifyUrl), '~s/auth/verify?token=~s', [BaseUrl, PlainToken]),
    mail:send_verification_email(Email, VerifyUrl, MailStatus).

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
    session_token:issue_session_token(Token, TokenHash),
    session_token:expiry_iso(TtlMin, ExpiresAt),
    session_token:now_iso(CreatedAt),
    db:save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt).

%!  verify_email_token(+PlainToken, -Outcome) is det.
%
%   Consome token de verificacao de email e ativa o usuario. `Outcome` e
%   `verified(UserId)` ou `invalid_or_expired_token`.
verify_email_token(PlainToken, Outcome) :-
    verify_email:token_hash(PlainToken, TokenHash),
    consume_and_mark(TokenHash, Outcome).

consume_and_mark(TokenHash, verified(UserId)) :-
    db:consume_email_verification(TokenHash, UserId),
    !,
    db:mark_user_verified(UserId).
consume_and_mark(_, invalid_or_expired_token).
