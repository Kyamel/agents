:- module(scopes, [
    is_admin/1,
    has_scope/2,
    user_scopes/2,
    is_admin_email/1,
    sync_admin_roles/0,
    promote_if_admin/1
]).

:- use_module('../config').
:- use_module('../db/db').

% Camada de autorizacao baseada em papel. O papel mora na coluna `users.role`;
% os scopes sao derivados dele. Admin e designado pela lista admin_emails/1 do
% config, sincronizada no boot (sync_admin_roles/0) e no cadastro
% (promote_if_admin/1).

user_scopes(User, Scopes) :-
    ( is_admin(User) -> Scopes = ['agent:delete:any'] ; Scopes = [] ).

has_scope(User, Scope) :-
    user_scopes(User, Scopes),
    memberchk(Scope, Scopes).

is_admin(User) :-
    is_dict(User),
    get_dict(role, User, Role),
    normalize_text(Role, "admin").

% =============================
% Designacao via config (admin_emails)
% =============================

is_admin_email(Email) :-
    config:admin_emails(Emails),
    normalize_text(Email, E),
    member(Listed, Emails),
    normalize_text(Listed, E),
    !.

%!  sync_admin_roles is det.
%
%   Torna o config a fonte da verdade: rebaixa todos os admins e repromove
%   apenas os emails listados. Idempotente; roda no boot.
sync_admin_roles :-
    config:admin_emails(Emails),
    db:reset_admins,
    forall(member(Email, Emails),
           db:set_user_role_by_email(Email, "admin")).

%!  promote_if_admin(+Email) is det.
%
%   Promove imediatamente o usuário recém-cadastrado caso seu e-mail esteja
%   na lista de administradores. Caso contrário, não realiza nenhuma ação.
promote_if_admin(Email) :-
    is_admin_email(Email),
    !,
    db:set_user_role_by_email(Email, "admin").
promote_if_admin(_).

% Converte Value para string e retorna sua representação em letras minúsculas.
normalize_text(Value, Lower) :-
    value_string(Value, String),
    string_lower(String, Lower).

value_string(Value, Value) :-
    string(Value),
    !.
value_string(Value, String) :-
    atom(Value),
    !,
    atom_string(Value, String).
value_string(Value, String) :-
    format(string(String), "~w", [Value]).