:- module(auth_repo, [
    save_email_verification/4,
    consume_email_verification/2,
    save_auth_session/4,
    find_user_id_by_session_token_hash/2,
    revoke_auth_session/1
]).

:- use_module(repo).

% Repositorio de autenticacao (tabelas email_verifications e auth_sessions),
% sobre o toolkit repo.pl. Guarda hashes de token, expiracoes e revogacoes.
% Reexportado por db.pl.

save_email_verification(TokenHash, UserId, ExpiresAt, _CreatedAt) :-
    repo:quote(TokenHash, QToken),
    repo:lit(UserId, QUser),
    repo:quote(ExpiresAt, QExp),
    format(string(SQL),
        "INSERT OR REPLACE INTO email_verifications(token_hash, user_id, expires_at, used_at) VALUES(~s, ~s, ~s, NULL);",
        [QToken, QUser, QExp]),
    repo:exec(SQL).

%!  consume_email_verification(+TokenHash, -UserId) is semidet.
%
%   So consome se o token nao foi usado e nao expirou; marca como usado na mesma
%   chamada (uso unico).
consume_email_verification(TokenHash, UserId) :-
    repo:quote(TokenHash, QToken),
    format(string(SQL),
        "SELECT user_id, expires_at, used_at FROM email_verifications WHERE token_hash = ~s LIMIT 1;",
        [QToken]),
    repo:get_one(SQL, [user_id-int, expires_at-text, used_at-optional], Row),
    Row.used_at == "",
    repo:now_iso(Now),
    Row.expires_at @> Now,
    UserId = Row.user_id,
    repo:quote(Now, QNow),
    format(string(UpdateSQL),
        "UPDATE email_verifications SET used_at = ~s WHERE token_hash = ~s;",
        [QNow, QToken]),
    repo:exec(UpdateSQL).

save_auth_session(TokenHash, UserId, ExpiresAt, CreatedAt) :-
    repo:quote(TokenHash, QToken),
    repo:lit(UserId, QUser),
    repo:quote(ExpiresAt, QExp),
    repo:quote(CreatedAt, QCreated),
    format(string(SQL),
        "INSERT OR REPLACE INTO auth_sessions(token_hash, user_id, expires_at, created_at, revoked_at) \c
VALUES(~s, ~s, ~s, ~s, NULL);",
        [QToken, QUser, QExp, QCreated]),
    repo:exec(SQL).

%!  find_user_id_by_session_token_hash(+TokenHash, -UserId) is semidet.
%
%   Resolve o usuario apenas de sessao ativa: nao revogada e nao expirada.
find_user_id_by_session_token_hash(TokenHash, UserId) :-
    repo:quote(TokenHash, QToken),
    format(string(SQL),
        "SELECT user_id, expires_at, revoked_at FROM auth_sessions WHERE token_hash = ~s LIMIT 1;",
        [QToken]),
    repo:get_one(SQL, [user_id-int, expires_at-text, revoked_at-optional], Row),
    Row.revoked_at == "",
    repo:now_iso(Now),
    Row.expires_at @> Now,
    UserId = Row.user_id.

revoke_auth_session(TokenHash) :-
    repo:quote(TokenHash, QToken),
    repo:now_iso(Now),
    repo:quote(Now, QNow),
    format(string(SQL),
        "UPDATE auth_sessions SET revoked_at = ~s WHERE token_hash = ~s;",
        [QNow, QToken]),
    repo:exec(SQL).
