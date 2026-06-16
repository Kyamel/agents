:- module(match_runner, [
    available_scenarios/1,
    valid_scenario/1,
    scenario_engine_arg/2,
    scenario_text/2,
    disguise_count/1
]).

:- use_module(library(filesex)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module('../config').

:- dynamic engine_dir_fact/1.

% Resolve o diretorio do engine em tempo de carga, antes que `source_file/2`
% se torne indisponivel ou ambiguo.
:- prolog_load_context(directory, EngineDir),
   retractall(engine_dir_fact(_)),
   assertz(engine_dir_fact(EngineDir)).

engine_dir(Dir) :- engine_dir_fact(Dir).

project_root(Root) :-
    engine_dir(EngineDir),
    directory_file_path(SrcDir, engine, EngineDir),
    directory_file_path(Root, src, SrcDir).

%!  disguise_count(-Q) is det.
%
%   Quantidade de disfarces disponiveis ao ladrao (config).
disguise_count(Q) :- config:engine_disguises(Q).

%!  available_scenarios(-Scenarios) is det.
%
%   Lista os cenarios .prolog no diretorio configurado em `scenario_dir/1`,
%   ordenados por nome. Cada item e scenario(Value, Label), onde Value e o
%   caminho do arquivo no mesmo formato de `engine_scenario/1` (com ".prolog",
%   ex.: "./scenarios/mapa1.prolog") e Label e o nome sem extensao ("mapa1").
available_scenarios(Scenarios) :-
    config:scenario_dir(Dir),
    to_atom(Dir, DirAtom),
    (   exists_directory(DirAtom)
    ->  directory_files(DirAtom, Entries)
    ;   Entries = []
    ),
    findall(scenario(Value, Label),
            ( member(Entry, Entries),
              file_name_extension(Base, prolog, Entry),
              atom_string(Base, Label),
              directory_file_path(DirAtom, Entry, Path),
              atom_string(Path, Value)
            ),
            Unsorted),
    sort(2, @=<, Unsorted, Scenarios).

%!  valid_scenario(+Value) is semidet.
%
%   Verdadeiro se `Value` corresponde a um cenario disponivel em `scenario_dir`.
%   Usado para validar a escolha vinda do formulario antes de executar.
valid_scenario(Value) :-
    available_scenarios(Scenarios),
    memberchk(scenario(Value, _), Scenarios).

% A engine (loadCenario/1) exige um atomo e concatena ".prolog" antes de
% consultar. Por isso removemos a extensao do caminho configurado e resolvemos
% para um caminho absoluto (relativo a raiz do projeto) como atomo.
scenario_engine_arg(Scenario, Arg) :-
    to_atom(Scenario, PathAtom),
    strip_leading_dot(PathAtom, Rel),
    file_name_extension(RelNoExt, prolog, Rel),
    project_root(Root),
    directory_file_path(Root, RelNoExt, Arg).

%!  scenario_text(+Scenario, -Label) is det.
%
%   Nome amigavel do cenario para a UI/JSON: o nome do arquivo sem o diretorio
%   nem a extensao ".prolog" (ex.: "./scenarios/mapa1.prolog" -> "mapa1").
scenario_text(Scenario, Label) :-
    to_atom(Scenario, PathAtom),
    file_base_name(PathAtom, Base),
    ( file_name_extension(Name, prolog, Base) -> true ; Name = Base ),
    atom_string(Name, Label).

%!  strip_leading_dot(+Path, -Rel) is det.
%
%   Remove o prefixo "./" de um caminho, se houver, para que possa ser
%   resolvido com directory_file_path/3 a partir da raiz do projeto.
strip_leading_dot(Path, Rel) :-
    ( atom_concat('./', Rel, Path) -> true ; Rel = Path ).

%!  to_atom(+Value, -Atom) is det.
%
%   Normaliza string ou atomo para atomo.
to_atom(Value, Value) :- atom(Value), !.
to_atom(Value, Atom) :- string(Value), atom_string(Atom, Value).
