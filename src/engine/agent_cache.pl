:- module(agent_cache, [
    materialize_agent/2,
    forget_agent/1,
    agent_cache_path/3
]).

:- use_module(library(filesex)).
:- use_module(library(error)).
:- use_module(library(apply)).
:- use_module('../config').

% Cache em disco do `source_text` armazenado no banco. O DB eh sempre o
% source-of-truth; o filesystem eh read-only e regravado a cada partida.
% Existe apenas porque a engine do professor (`Interactor.prolog`) chama
% `use_module(Path)`, que exige um caminho de arquivo.

%!  materialize_agent(+Agent, -AbsPath) is det.
%
%   Escreve `uploads/agents/<id>-<slug>.pl` a partir do `source_text` do
%   Agent (dict vindo de `db:get_agent/2`) e devolve o caminho
%   absoluto. Sempre sobrescreve para refletir o DB.
materialize_agent(Agent, AbsPath) :-
    must_be(dict, Agent),
    get_dict(id, Agent, AgentId),
    get_dict(name, Agent, Name),
    get_dict(source_text, Agent, SourceRaw),
    coerce_string(SourceRaw, SourceText),
    agent_cache_path(AgentId, Name, AbsPath),
    file_directory_name(AbsPath, Dir),
    make_directory_path(Dir),
    setup_call_cleanup(
        open(AbsPath, write, Out, [encoding(utf8)]),
        format(Out, '~s~n', [SourceText]),
        close(Out)
    ).

% prosqlite devolve TEXT como atom por padrao; tolera ambos para nao acoplar
% o consumidor ao detalhe do driver.
coerce_string(X, X)  :- string(X), !.
coerce_string(X, S)  :- atom(X), !, atom_string(X, S).
coerce_string(X, S)  :- format(string(S), '~w', [X]).

%!  forget_agent(+AgentId) is det.
%
%   Remove os arquivos cacheados do agente (`<id>-<slug>.pl`, ou o antigo
%   `<id>.pl`), localizados por prefixo de id -- o id e um UUID unico, entao
%   nao e preciso conhecer o slug. Idempotente.
forget_agent(AgentId) :-
    cache_dir(Dir),
    id_atom(AgentId, IdAtom),
    atomic_list_concat([Dir, '/', IdAtom, '*.pl'], Pattern),
    expand_file_name(Pattern, Files),
    maplist(delete_cached_file, Files).

delete_cached_file(AbsPath) :-
    exists_file(AbsPath),
    !,
    catch(delete_file(AbsPath), _, true).
delete_cached_file(_AbsPath).

% Caminho `<dir>/<id>-<slug>.pl` (dir via env AGENT_CACHE_DIR).
agent_cache_path(AgentId, Name, AbsPath) :-
    cache_dir(Dir),
    id_atom(AgentId, IdAtom),
    cache_basename(IdAtom, Name, Base),
    file_name_extension(Base, pl, FileName),
    directory_file_path(Dir, FileName, Rel),
    absolute_file_name(Rel, AbsPath).

% `<id>-<name>` (nome ja validado como slug); cai em `<id>` se vazio.
cache_basename(IdAtom, Name, Base) :-
    name_atom(Name, NameAtom),
    NameAtom \== '',
    !,
    atomic_list_concat([IdAtom, '-', NameAtom], Base).
cache_basename(IdAtom, _Name, IdAtom).

name_atom(Name, Name) :-
    atom(Name),
    !.
name_atom(Name, Atom) :-
    string(Name),
    !,
    atom_string(Atom, Name).
name_atom(_Name, '').

cache_dir(Dir) :-
    config:agent_cache_dir(S),
    atom_string(Dir, S).

id_atom(Id, Id) :-
    atom(Id),
    !.
id_atom(Id, Atom) :-
    string(Id),
    !,
    atom_string(Atom, Id).
id_atom(Id, _Atom) :-
    type_error(agent_id, Id).
