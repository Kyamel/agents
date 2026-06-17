:- module(match_worker, [main/0]).

:- use_module(library(http/json)).
:- use_module(library(lists)).
:- use_module('./match_replay').

% Entry headless de UMA partida, executada como subprocesso `swipl` proprio.
% Invocacao:
%   swipl -q -g main -t 'halt(1)' src/engine/match_worker.pl -- \
%         <ScenarioArg> <Qdis> <ThiefPath> <DetPath> <OutFile>

% Resolve o diretorio do engine em tempo de carga para localizar o Interactor.
:- prolog_load_context(directory, Dir),
   retractall(worker_engine_dir(_)),
   assertz(worker_engine_dir(Dir)).

:- dynamic worker_engine_dir/1.

%!  main is det.
%
%   Le os argumentos, roda a partida e grava o resultado em OutFile. Qualquer
%   falha vira um JSON de erro em OutFile e codigo de saida 1.
main :-
    current_prolog_flag(argv, Argv),
    parse_args(Argv, Scenario, Qdis, ThiefPath, DetPath, OutFile),
    catch(
        run(Scenario, Qdis, ThiefPath, DetPath, OutFile),
        Error,
        ( write_error(OutFile, Error), halt(1) )
    ).

parse_args([ScenarioA, QdisA, ThiefPath, DetPath, OutFile],
           Scenario, Qdis, ThiefPath, DetPath, OutFile) :-
    !,
    Scenario = ScenarioA,
    atom_number(QdisA, Qdis).
parse_args(Argv, _, _, _, _, _) :-
    throw(error(match_worker_bad_args(Argv), _)).

run(Scenario, Qdis, ThiefPath, DetPath, OutFile) :-
    ensure_interactor_loaded,
    scenario_label(Scenario, Label),
    capture_engine_run(Scenario, Qdis, ThiefPath, DetPath,
                       RawWinner, InitialState, Lines),
    match_replay:engine_output_to_replay(Lines, Label, InitialState, RawWinner, Replay),
    Payload = _{ winner: Replay.winner, replay: Replay },
    write_payload(OutFile, Payload),
    halt(0).

ensure_interactor_loaded :-
    worker_engine_dir(Dir),
    directory_file_path(Dir, 'Interactor.prolog', Path),
    user:consult(Path).

scenario_label(Scenario, Label) :-
    file_base_name(Scenario, Base),
    atom_string(Base, Label).

%!  capture_engine_run(+Scenario, +Qdis, +ThiefPath, +DetPath, -Winner, -InitialState, -Lines) is det.
%
%   Roda a engine capturando o stdout (o log da partida) e devolve o vencedor
%   cru, o estado inicial (gSt/7) e as linhas do log.
capture_engine_run(Scenario, Qdis, ThiefPath, DetPath, Winner, InitialState, Lines) :-
    with_output_to(string(Output),
        run_engine(Scenario, Qdis, ThiefPath, DetPath, InitialState, Winner)),
    split_string(Output, "\n", "", Lines).

run_engine(Scenario, Qdis, ThiefPath, DetPath, InitialState, Winner) :-
    user:gameStart(Scenario, Qdis, ThiefPath, DetPath, InitialState, Winner),
    !.
run_engine(_Scenario, _Qdis, _ThiefPath, _DetPath, _InitialState, _Winner) :-
    throw(error(engine_failure(gameStart), _)).

write_payload(OutFile, Dict) :-
    setup_call_cleanup(
        open(OutFile, write, Out, [encoding(utf8)]),
        json_write_dict(Out, Dict, [width(0)]),
        close(Out)
    ).

%!  write_error(+OutFile, +Error) is det.
%
%   Grava um JSON de erro para o processo pai diagnosticar a falha.
write_error(OutFile, Error) :-
    error_message(Error, Message),
    catch(write_payload(OutFile, _{error: Message}), _, true).

error_message(Error, Message) :-
    catch(message_to_string(Error, Message), _, fail),
    !.
error_message(Error, Message) :-
    term_string(Error, Message).