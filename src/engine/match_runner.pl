:- module(match_runner, [
    available_scenarios/1,
    valid_scenario/1,
    scenario_engine_arg/2,
    scenario_text/2,
    scenario_graph/3,
    scenario_treasure/4,
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

% Valida a escolha vinda do formulario contra os cenarios disponiveis.
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

% Nome amigavel p/ UI/JSON: "./scenarios/mapa1.prolog" -> "mapa1".
scenario_text(Scenario, Label) :-
    to_atom(Scenario, PathAtom),
    file_base_name(PathAtom, Base),
    ( file_name_extension(Name, prolog, Base) -> true ; Name = Base ),
    atom_string(Name, Label).

strip_leading_dot(Path, Rel) :-
    ( atom_concat('./', Rel, Path) -> true ; Rel = Path ).

%!  scenario_graph(+Scenario, -Cities, -Edges) is semidet.
%
%   Extrai o grafo do cenario (lista de cidades e de arestas) lendo os fatos
%   `cidade/1` e `conectado/2` do arquivo .prolog, SEM consultar/executar nada
%   (apenas `read_term/3`), portanto sem efeito colateral no estado global. As
%   arestas sao normalizadas como pares ordenados `[Lo,Hi]` e deduplicadas (o
%   grafo e tratado como nao-direcionado, como a engine faz em `validar/3`).
%   Falha se o cenario for invalido ou o arquivo nao existir/parsear.
scenario_graph(Scenario, Cities, Edges) :-
    scenario_file(Scenario, File),
    exists_file(File),
    catch(read_scenario_terms(File, Terms), _, fail),
    findall(City, member(cidade(City), Terms), Cities0),
    sort(Cities0, Cities),
    findall(Edge,
            ( member(conectado(A, B), Terms), sort_pair(A, B, Edge) ),
            Edges0),
    sort(Edges0, Edges).

%!  scenario_treasure(+Scenario, +Target, -City, -Requirements) is semidet.
%
%   Le a cidade e os requisitos diretos do tesouro sem consultar o cenario.
%   Target pode chegar como string do replay ou como atomo.
scenario_treasure(Scenario, Target, City, Requirements) :-
    scenario_file(Scenario, File),
    exists_file(File),
    catch(read_scenario_terms(File, Terms), _, fail),
    to_atom(Target, TargetAtom),
    member(tesouro(TargetAtom, City, Requirements), Terms),
    !.

% Caminho absoluto do .prolog do cenario, mantendo a extensao (ao contrario
% de scenario_engine_arg/2).
scenario_file(Scenario, File) :-
    to_atom(Scenario, PathAtom),
    strip_leading_dot(PathAtom, Rel),
    project_root(Root),
    directory_file_path(Root, Rel, File).

read_scenario_terms(File, Terms) :-
    setup_call_cleanup(
        open(File, read, In, [encoding(utf8)]),
        read_terms(In, Terms),
        close(In)).

read_terms(In, Terms) :-
    read_term(In, Term, []),
    ( Term == end_of_file
    ->  Terms = []
    ;   Terms = [Term|Rest],
        read_terms(In, Rest)
    ).

sort_pair(A, B, [A, B]) :- A @=< B, !.
sort_pair(A, B, [B, A]).

to_atom(Value, Value) :- atom(Value), !.
to_atom(Value, Atom) :- string(Value), atom_string(Atom, Value).
