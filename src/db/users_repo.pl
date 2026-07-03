:- module(users_repo, [
    create_user/5,
    find_user_by_email/2,
    find_user_by_id/2,
    mark_user_verified/1,
    set_user_role_by_email/2,
    reset_admins/0
]).

:- use_module(repo).

% Repositorio do recurso "usuario" (tabela users), sobre o toolkit repo.pl.
% Reexportado por db.pl.

% username/role NULL ou antigos caem para fallback (email / "user").
user_fields([
    id-raw, username-optional, email-raw, password_hash-raw,
    is_verified-bool, role-optional, created_at-raw
]).

create_user(Username, Email, PasswordHash, UserId, CreatedAt) :-
    repo:now_iso(CreatedAt),
    repo:quote(Username, QUser),
    repo:quote(Email, QEmail),
    repo:quote(PasswordHash, QPwd),
    repo:quote(CreatedAt, QCreated),
    format(string(SQL),
        "INSERT INTO users(username, email, password_hash, is_verified, created_at) VALUES(~s, ~s, ~s, 0, ~s);",
        [QUser, QEmail, QPwd, QCreated]),
    repo:insert(SQL, UserId).

find_user_by_email(Email, User) :-
    repo:quote(Email, QEmail),
    format(string(SQL),
        "SELECT id, username, email, password_hash, is_verified, role, created_at FROM users WHERE email = ~s LIMIT 1;",
        [QEmail]),
    fetch_user(SQL, User).

find_user_by_id(UserId, User) :-
    repo:lit(UserId, QId),
    format(string(SQL),
        "SELECT id, username, email, password_hash, is_verified, role, created_at FROM users WHERE id = ~s LIMIT 1;",
        [QId]),
    fetch_user(SQL, User).

fetch_user(SQL, User) :-
    user_fields(Fields),
    repo:get_one(SQL, Fields, Row),
    apply_fallbacks(Row, User).

apply_fallbacks(Row, User) :-
    username_or_email(Row.username, Row.email, Username),
    role_or_default(Row.role, Role),
    User = Row.put(_{username: Username, role: Role}).

username_or_email("", Email, Email) :- !.
username_or_email(Username, _Email, Username).

role_or_default("", "user") :- !.
role_or_default(Role, Role).

mark_user_verified(UserId) :-
    repo:lit(UserId, QId),
    format(string(SQL), "UPDATE users SET is_verified = 1 WHERE id = ~s;", [QId]),
    repo:exec(SQL).

% Define o papel de quem tiver esse email (no-op se nao existe).
set_user_role_by_email(Email, Role) :-
    repo:quote(Email, QEmail),
    repo:quote(Role, QRole),
    format(string(SQL),
        "UPDATE users SET role = ~s WHERE email = ~s;", [QRole, QEmail]),
    repo:exec(SQL).

% Rebaixa todo admin para `user` (config e a fonte da verdade; ver scopes).
reset_admins :-
    repo:exec("UPDATE users SET role = 'user' WHERE role = 'admin';").
