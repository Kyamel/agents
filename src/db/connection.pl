:- module(db_connection, [
    ensure_connected/0,
    ensure_prosqlite/0,
    conn_alias/1,
    sql_exec/1,
    sql_quote/2,
    sql_literal/2,
    timestamp_iso/1
]).

:- use_module(library(error)).
:- use_module(library(filesex)).
:- use_module(library(prolog_pack)).
:- use_module('../config').

% Alias logico da conexao SQLite compartilhada.
conn_alias(agents_db).


% --- Carregamento do pacote prosqlite ------------------------------------
%
% prosqlite nao vem com o SWI. Tentamos, em ordem: pack local em
% packs/prosqlite, library(prosqlite) ja instalada, e por fim o .pl do pack
% local direto. require_prosqlite/0 falha alto se nada disso funcionar.

ensure_prosqlite :-
    ensure_local_prosqlite_pack,
    ensure_prosqlite_loaded,
    require_prosqlite.

require_prosqlite :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
require_prosqlite :-
    throw(error(existence_error(package, prosqlite), _)).

ensure_prosqlite_loaded :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
ensure_prosqlite_loaded :-
    catch(use_module(library(prosqlite), []), _, fail),
    !.
ensure_prosqlite_loaded :-
    local_prosqlite_module_file(ModuleFile),
    exists_file(ModuleFile),
    use_module(ModuleFile, []).

ensure_local_prosqlite_pack :-
    current_predicate(prosqlite:sqlite_connect/3),
    !.
ensure_local_prosqlite_pack :-
    local_prosqlite_pack_dir(PackDir),
    exists_directory(PackDir),
    !,
    catch(pack_attach(PackDir, [duplicate(replace)]), _, true).
ensure_local_prosqlite_pack.

% Sobe de src/db ate a raiz do projeto para achar packs/prosqlite.
local_prosqlite_pack_dir(PackDir) :-
    source_file(db_connection:conn_alias(_), ThisFile),
    file_directory_name(ThisFile, DbDir),
    file_directory_name(DbDir, SrcDir),
    file_directory_name(SrcDir, ProjectDir),
    directory_file_path(ProjectDir, 'packs/prosqlite', PackDir).

local_prosqlite_module_file(ModuleFile) :-
    local_prosqlite_pack_dir(PackDir),
    directory_file_path(PackDir, 'prolog/prosqlite.pl', ModuleFile).


% --- Conexao -------------------------------------------------------------

ensure_connected :-
    ensure_prosqlite,
    conn_alias(Alias),
    ensure_connection_open(Alias).

ensure_connection_open(Alias) :-
    sqlite_connection_ready(Alias),
    !.
ensure_connection_open(Alias) :-
    config:db_path(DbPath),
    file_directory_name(DbPath, Dir),
    make_directory_path(Dir),
    prosqlite:sqlite_connect(DbPath, Alias, [alias(Alias), exists(false), ext('')]).

sqlite_connection_ready(Alias) :-
    current_predicate(prosqlite:sqlite_current_connection/1),
    prosqlite:sqlite_current_connection(Alias).

% Executa um comando SQL descartando as linhas de retorno.
sql_exec(SQL) :-
    conn_alias(Alias),
    findall(Row, prosqlite:sqlite_query(Alias, SQL, Row), _Rows).


% --- Serializacao --------------------------------------------------------

timestamp_iso(Iso) :-
    get_time(Now),
    format_time(string(Iso), '%FT%TZ', Now).

%!  sql_quote(+Input, -Quoted) is det.
%
%   Unica barreira contra SQL injection: dobra aspas simples e envolve em
%   aspas. Todo valor textual interpolado em SQL passa por aqui.
sql_quote(Input, Quoted) :-
    string_codes(Input, Codes),
    phrase(sql_escaped(Codes), EscapedCodes),
    string_codes(Escaped, EscapedCodes),
    format(string(Quoted), "'~s'", [Escaped]).

sql_literal(Input, Literal) :-
    integer(Input),
    !,
    format(string(Literal), "~d", [Input]).
sql_literal(Input, Literal) :-
    atom(Input),
    !,
    atom_string(Input, String),
    sql_quote(String, Literal).
sql_literal(Input, Literal) :-
    sql_quote(Input, Literal).

sql_escaped([]) --> [].
sql_escaped([39|Rest]) --> "''", sql_escaped(Rest).
sql_escaped([C|Rest]) --> [C], sql_escaped(Rest).

% Eager-load do prosqlite no carregamento do modulo. Sem isso o check/0
% reclama de prosqlite:sqlite_*/N, pois o pack so seria atachado lazy via
% init/0. Erros sao engolidos para nao quebrar o build se o pack faltar.
:- catch(ensure_prosqlite, _, true).
