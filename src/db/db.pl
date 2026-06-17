:- module(db, [
    init/0
]).

% Fachada da camada de persistência: reexporta os predicados de query
% de `queries.pl` para uso via `db:...`, enquanto a implementação fica
% dividida entre conexão, migrações/DDL e CRUD.

:- use_module(connection).
:- use_module(schema).
:- reexport(queries).

%!  init is det.
%
%   Inicializa dependência `prosqlite`, conexão e migrações de schema.
init :-
    ensure_prosqlite,
    ensure_connected,
    migrate.
