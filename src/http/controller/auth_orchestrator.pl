:- module(auth_orchestrator, [
    signup/3,
    login/3,
    signup_from_request/3,
    login_from_request/3,
    verify_from_request/3
]).

:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module('../../config/env').
:- use_module('../../db/sqlite_store').
:- use_module('../../auth/password').
:- use_module('../../auth/verify_email', []).
:- use_module('../../auth/session_token', []).
:- use_module('../../auth/mail').
:- use_module('./json_request').

% -----------------------------
% Servicos (reutilizados pela API JSON e pelas paginas web)
% -----------------------------

%!  signup(+EmailRaw, +Password, -Outcome) is det.
%
%   Cria um usuario e dispara o email de verificacao. `Outcome` e
%   `email_exists` ou `created(UserId, MailStatus)`.
signup(EmailRaw, Password, Outcome) :-
    normalize_email(EmailRaw, Email),
    (   sqlite_store:find_user_by_email(Email, _)
    ->  Outcome = email_exists
    ;   password:hash_password(Password, PasswordHash),
        sqlite_store:create_user(Email, PasswordHash, UserId, _CreatedAt),
        verify_email:issue_verification_token(UserId, PlainToken, TokenHash),
        env:env_int('EMAIL_VERIFY_TTL_MIN', 30, TtlMin),
        verify_email:expiry_iso(TtlMin, ExpiresAt),
        sqlite_store:save_email_verification(TokenHash, UserId, ExpiresAt, ExpiresAt),
        env:env_required_string('APP_BASE_URL', BaseUrl),
        format(string(VerifyUrl), '~s/api/v1/auth/verify?token=~s', [BaseUrl, PlainToken]),
        mail:send_verification_email(Email, VerifyUrl, MailStatus),
        Outcome = created(UserId, MailStatus)
    ).

%!  login(+EmailRaw, +Password, -Outcome) is det.
%
%   Autentica um usuario e emite uma sessao. `Outcome` e `invalid_credentials`,
%   `email_not_verified` ou `ok(Token, UserId, ExpiresAt)`.
login(EmailRaw, Password, Outcome) :-
    normalize_email(EmailRaw, Email),
    (   sqlite_store:find_user_by_email(Email, User)
    ->  (   password:verify_password(Password, User.password_hash)
        ->  (   User.is_verified == true
            ->  issue_session(User.id, Token, ExpiresAt),
                Outcome = ok(Token, User.id, ExpiresAt)
            ;   Outcome = email_not_verified
            )
        ;   Outcome = invalid_credentials
        )
    ;   Outcome = invalid_credentials
    ).

%!  issue_session(+UserId, -Token, -ExpiresAt) is det.
%
%   Emite e persiste um token de sessao para o usuario.
issue_session(UserId, Token, ExpiresAt) :-
    env:env_int('AUTH_SESSION_TTL_MIN', 10080, TtlMin),
    session_token:issue_session_token(Token, TokenHash),
    session_token:expiry_iso(TtlMin, ExpiresAt),
    session_token:now_iso(CreatedAt),
    sqlite_store:save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt).

% -----------------------------
% Adaptadores HTTP (API JSON)
% -----------------------------

%!  signup_from_request(+Request, -Status, -Payload) is det.
%
%   Processa cadastro a partir de um corpo JSON e devolve status/payload HTTP.
signup_from_request(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    signup(Email, Password, Outcome),
    signup_payload(Outcome, Status, Payload).

%!  signup_payload(+Outcome, -Status, -Payload) is det.
%
%   Mapeia o resultado de signup/3 para resposta HTTP.
signup_payload(email_exists, 409, _{error: "email_already_exists"}).
signup_payload(created(UserId, MailStatus0), 201, Payload) :-
    mail_status_string(MailStatus0, MailStatus),
    Payload = _{
        status: "created",
        user_id: UserId,
        email_delivery: MailStatus,
        message: "check your inbox to verify your email"
    }.

%!  mail_status_string(+Status, -String) is det.
%
%   Converte o status de envio de email para string de resposta.
mail_status_string(sent, "sent").
mail_status_string(console, "console").
mail_status_string(failed, "failed").

%!  login_from_request(+Request, -Status, -Payload) is det.
%
%   Processa login a partir de um corpo JSON e devolve token de sessao.
login_from_request(Request, Status, Payload) :-
    json_request:read_json_body(Request, Body),
    json_request:require_string(Body, email, Email),
    json_request:require_string(Body, password, Password),
    login(Email, Password, Outcome),
    login_payload(Outcome, Status, Payload).

%!  login_payload(+Outcome, -Status, -Payload) is det.
%
%   Mapeia o resultado de login/3 para resposta HTTP.
login_payload(invalid_credentials, 401, _{error: "invalid_credentials"}).
login_payload(email_not_verified, 403, _{error: "email_not_verified"}).
login_payload(ok(Token, UserId, ExpiresAt), 200, Payload) :-
    Payload = _{
        status: "ok",
        token: Token,
        user_id: UserId,
        expires_at: ExpiresAt
    }.

%!  verify_from_request(+Request, -Status, -Payload) is det.
%
%   Consome token de verificacao de email e ativa o usuario.
verify_from_request(Request, Status, Payload) :-
    http_parameters(Request, [token(Token, [string])]),
    verify_email:token_hash(Token, TokenHash),
    (   sqlite_store:consume_email_verification(TokenHash, UserId)
    ->  sqlite_store:mark_user_verified(UserId),
        Status = 200,
        Payload = _{status: "verified", user_id: UserId}
    ;   Status = 400,
        Payload = _{error: "invalid_or_expired_token"}
    ).

% -----------------------------
% Auxiliares
% -----------------------------

%!  normalize_email(+EmailIn, -EmailOut) is det.
%
%   Normaliza email para lowercase.
normalize_email(EmailIn, EmailOut) :-
    string_lower(EmailIn, EmailOut).
