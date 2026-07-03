:- module(db, [
    init/0
]).

% Fachada da camada de persistência: reexporta os repositórios por recurso para
% uso via `db:...`. Cada repositório (agents/users/auth/matches) é escrito sobre
% o toolkit repo.pl; conexão e migrações/DDL ficam em connection.pl/schema.pl.

:- use_module(connection).
:- use_module(schema).
:- reexport(agents_repo).
:- reexport(users_repo).
:- reexport(auth_repo).
:- reexport(matches_repo).

%!  init is det.
%
%   Inicializa dependência `prosqlite`, conexão e migrações de schema.
init :-
    ensure_prosqlite,
    ensure_connected,
    migrate.
