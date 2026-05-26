:- module(agent_cache, [
    materialize_agent/2,
    forget_agent/1,
    agent_cache_path/2
]).

:- use_module(library(filesex)).
:- use_module(library(error)).
:- use_module('../config/env').

% Cache em disco do `source_text` armazenado no banco. O DB eh sempre o
% source-of-truth; o filesystem eh read-only e regravado a cada partida.
% Existe apenas porque a engine do professor (`Interactor.prolog`) chama
% `use_module(Path)`, que exige um caminho de arquivo.

%!  materialize_agent(+Agent, -AbsPath) is det.
%
%   Escreve `uploads/agents/<id>.pl` a partir do `source_text` do Agent
%   (dict vindo de `sqlite_store:get_agent/2`) e devolve o caminho
%   absoluto. Sempre sobrescreve para refletir o DB.
materialize_agent(Agent, AbsPath) :-
    must_be(dict, Agent),
    get_dict(id, Agent, AgentId),
    get_dict(source_text, Agent, SourceText),
    must_be(string, SourceText),
    agent_cache_path(AgentId, AbsPath),
    file_directory_name(AbsPath, Dir),
    make_directory_path(Dir),
    setup_call_cleanup(
        open(AbsPath, write, Out, [encoding(utf8)]),
        format(Out, '~s~n', [SourceText]),
        close(Out)
    ).

%!  forget_agent(+AgentId) is det.
%
%   Remove o arquivo cacheado do agente, quando existir. Tolera ausencia
%   do arquivo (idempotente).
forget_agent(AgentId) :-
    agent_cache_path(AgentId, AbsPath),
    (   exists_file(AbsPath)
    ->  catch(delete_file(AbsPath), _, true)
    ;   true
    ).

%!  agent_cache_path(+AgentId, -AbsPath) is det.
%
%   Resolve o caminho absoluto do arquivo cache de um agente. O
%   diretorio raiz eh configuravel via env `AGENT_CACHE_DIR`.
agent_cache_path(AgentId, AbsPath) :-
    cache_dir(Dir),
    id_atom(AgentId, IdAtom),
    file_name_extension(IdAtom, pl, FileName),
    directory_file_path(Dir, FileName, Rel),
    absolute_file_name(Rel, AbsPath).

cache_dir(Dir) :-
    env:env_string('AGENT_CACHE_DIR', "./uploads/agents", S),
    atom_string(Dir, S).

id_atom(Id, Atom) :-
    (   atom(Id) -> Atom = Id
    ;   string(Id) -> atom_string(Atom, Id)
    ;   type_error(agent_id, Id)
    ).
