:- module(match_queue, [
    start_pool/0,
    enqueue_match/4,
    job_snapshot/1,
    job_info/2
]).

:- use_module(library(process)).
:- use_module(library(http/json)).
:- use_module(library(lists)).
:- use_module(library(apply)).
:- use_module(library(filesex)).
:- use_module('../config').
:- use_module('../db/db').
:- use_module('./agent_cache').
:- use_module('./match_runner').

% Fila de execucao de partidas + pool de workers. Cada partida roda num
% subprocesso `swipl` proprio (match_worker.pl), de modo que o processo do
% servidor fica desacoplado da execucao: a request HTTP nunca bloqueia e o
% estado global da engine nao vaza de uma partida para outra.

:- dynamic pool_started/0.
:- dynamic job/2.            % job(MatchId, Dict) -- so jobs ATIVOS (queued|running)

% Resolve o diretorio deste modulo em tempo de carga para achar o match_worker.
:- prolog_load_context(directory, Dir),
   retractall(queue_dir_fact(_)),
   assertz(queue_dir_fact(Dir)).

:- dynamic queue_dir_fact/1.

% =============================
% Bootstrap do pool
% =============================

%!  start_pool is det.
%
%   Cria a fila e os workers (idempotente) e re-enfileira partidas pendentes do
%   banco (durabilidade da fila apos restart).
start_pool :-
    pool_started,
    !.
start_pool :-
    assertz(pool_started),
    worker_count(N),
    message_queue_create(_, [alias(match_jobs)]),
    forall(between(1, N, I),
           ( atom_concat(match_worker_, I, Alias),
             thread_create(worker_loop, _, [alias(Alias), detached(true)]) )),
    format("match_queue: pool com ~w worker(s)~n", [N]),
    recover_pending.

worker_count(N) :-
    config:match_max_workers(N).


%!  recover_pending is det.
%
%   Le do banco as partidas em `queued`/`running` (interrompidas por um restart)
%   e as re-enfileira. As que estavam `running` voltam para `queued` e recomecam
%   do zero (resume mid-match e Fase 2).
recover_pending :-
    db:list_matches_by_status(["queued", "running"], Matches),
    forall(member(M, Matches), requeue_match(M)).

requeue_match(Match) :-
    MatchId = Match.id,
    reset_running_status(Match, MatchId),
    register_job(MatchId, Match.thief_agent_id, Match.detective_agent_id,
                 Match.scenario, "queued"),
    thread_send_message(match_jobs, run(MatchId)).

% Uma partida que estava `running` num restart volta para `queued` (vai recomecar
% do zero); as ja `queued` ficam como estao.
reset_running_status(Match, MatchId) :-
    Match.status == "running",
    !,
    catch(db:update_match_status(MatchId, "queued"), _, true).
reset_running_status(_Match, _MatchId).

% =============================
% Enqueue (chamado pela rota)
% =============================

%!  enqueue_match(+ThiefId, +DetectiveId, +Scenario, -MatchId) is det.
%
%   Cria a linha pendente no banco, registra o job e o envia para a fila. Nao
%   bloqueia: a partida sera executada por um worker quando houver vaga.
enqueue_match(ThiefId, DetectiveId, Scenario, MatchId) :-
    db:create_pending_match(ThiefId, DetectiveId, Scenario, MatchId),
    register_job(MatchId, ThiefId, DetectiveId, Scenario, "queued"),
    thread_send_message(match_jobs, run(MatchId)).

% =============================
% Worker
% =============================

worker_loop :-
    thread_get_message(match_jobs, run(MatchId)),
    catch(run_job(MatchId),
          Error,
          fail_job(MatchId, "error", Error)),
    worker_loop.

%!  run_job(+MatchId) is det.
%
%   Executa uma partida: materializa agentes, dispara o subprocesso, espera com
%   timeout e persiste o resultado.
run_job(MatchId) :-
    db:get_match(MatchId, Match),
    !,
    ThiefId = Match.thief_agent_id,
    DetectiveId = Match.detective_agent_id,
    Scenario = Match.scenario,
    mark_running(MatchId),
    db:get_agent(ThiefId, ThiefAgent),
    db:get_agent(DetectiveId, DetectiveAgent),
    agent_cache:materialize_agent(ThiefAgent, ThiefPath),
    agent_cache:materialize_agent(DetectiveAgent, DetectivePath),
    match_runner:scenario_engine_arg(Scenario, ScenarioArg),
    match_runner:disguise_count(Qdis),
    output_file(MatchId, OutFile),
    run_subprocess(MatchId, ScenarioArg, Qdis, ThiefPath, DetectivePath, OutFile, Status),
    finish_job(MatchId, Status, OutFile).
run_job(MatchId) :-
    % Linha sumiu do banco (apagada?); descarta o job silenciosamente.
    forget_job(MatchId).

%!  run_subprocess(+MatchId, +ScenarioArg, +Qdis, +ThiefPath, +DetPath, +OutFile, -Status) is det.
%
%   Sobe o subprocesso swipl e espera com timeout. Status e `exit(Code)` ou
%   `timeout`.
run_subprocess(MatchId, ScenarioArg, Qdis, ThiefPath, DetectivePath, OutFile, Status) :-
    worker_file(WorkerFile),
    atom_number(QdisAtom, Qdis),
    process_create(path(swipl),
        ['-q', '-g', main, '-t', 'halt(1)', WorkerFile, '--',
         ScenarioArg, QdisAtom, ThiefPath, DetectivePath, OutFile],
        [process(Pid), stdout(null), stderr(null)]),
    set_job_pid(MatchId, Pid),
    config:match_timeout_seconds(Timeout),
    await_process(Pid, Timeout, Status).

%!  await_process(+Pid, +Timeout, -Status) is det.
%
%   Espera o subprocesso; traduz a saida via wait_result/3. Se o proprio
%   process_wait falhar, reporta `error`.
await_process(Pid, Timeout, Status) :-
    process_wait(Pid, ExitStatus, [timeout(Timeout)]),
    !,
    wait_result(Pid, ExitStatus, Status).
await_process(_Pid, _Timeout, error).

%!  wait_result(+Pid, +ExitStatus, -Status) is det.
%
%   Se a engine estourou o timeout, mata o subprocesso (TERM, depois KILL) e
%   reporta `timeout`; senao repassa o codigo de saida.
wait_result(Pid, timeout, timeout) :-
    !,
    kill_process(Pid).
wait_result(_Pid, exit(Code), exit(Code)) :- !.
wait_result(_Pid, killed(_Signal), error) :- !.
wait_result(_Pid, _Other, error).

kill_process(Pid) :-
    catch(process_kill(Pid, term), _, true),
    finish_after_term(Pid).

finish_after_term(Pid) :-
    catch(process_wait(Pid, _, [timeout(5)]), _, fail),
    !.

finish_after_term(Pid) :-
    catch(process_kill(Pid, kill), _, true),
    catch(process_wait(Pid, _, []), _, true).

finish_job(MatchId, exit(0), OutFile) :-
    read_result(OutFile, Winner, ReplayJson),
    !,
    db:finalize_match(MatchId, Winner, ReplayJson),
    cleanup(MatchId, OutFile).
finish_job(MatchId, timeout, OutFile) :-
    !,
    fail_job(MatchId, "timeout", "A partida excedeu o tempo limite de execução."),
    cleanup(MatchId, OutFile).
finish_job(MatchId, _Status, OutFile) :-
    result_error_message(OutFile, Message),
    !,
    fail_job(MatchId, "error", Message),
    cleanup(MatchId, OutFile).
finish_job(MatchId, Status, OutFile) :-
    format(string(Message), "O subprocesso da partida falhou: ~w.", [Status]),
    fail_job(MatchId, "error", Message),
    cleanup(MatchId, OutFile).

%!  read_result(+OutFile, -Winner, -ReplayJson) is semidet.
%
%   Le o JSON escrito pelo subprocesso. Falha se o arquivo nao existir, estiver
%   corrompido ou carregar `error` (e nao `winner`/`replay`).
read_result(OutFile, Winner, ReplayJson) :-
    read_result_payload(OutFile, Payload),
    get_dict(winner, Payload, Winner),
    get_dict(replay, Payload, Replay),
    atom_json_dict(ReplayJson, Replay, [width(0)]).

read_result_payload(OutFile, Payload) :-
    exists_file(OutFile),
    setup_call_cleanup(
        open(OutFile, read, In, [encoding(utf8)]),
        catch(json_read_dict(In, Payload), _, fail),
        close(In)).

result_error_message(OutFile, Message) :-
    read_result_payload(OutFile, Payload),
    get_dict(error, Payload, RawMessage),
    failure_message(RawMessage, Message).

cleanup(MatchId, OutFile) :-
    delete_if_exists(OutFile),
    forget_job(MatchId).

delete_if_exists(File) :-
    exists_file(File),
    !,
    catch(delete_file(File), _, true).
delete_if_exists(_File).

fail_job(MatchId, Status, Reason) :-
    failure_message(Reason, Message),
    format(user_error, "[match ~w] falhou (~w): ~s~n", [MatchId, Status, Message]),
    catch(db:mark_match_failed(MatchId, Status, Message), _, true),
    forget_job(MatchId).

failure_message(Reason, Message) :-
    reason_text(Reason, RawMessage),
    truncate_message(RawMessage, 2000, Message).

reason_text(Reason, Reason) :-
    string(Reason),
    !.
reason_text(Reason, Message) :-
    catch(message_to_string(Reason, Message), _, fail),
    !.
reason_text(Reason, Message) :-
    term_string(Reason, Message).

truncate_message(RawMessage, Limit, Message) :-
    string_length(RawMessage, Length),
    Length > Limit,
    !,
    PrefixLength is Limit - 3,
    sub_string(RawMessage, 0, PrefixLength, _, Prefix),
    string_concat(Prefix, "...", Message).
truncate_message(Message, _Limit, Message).

% =============================
% Registro de jobs (em memoria, so os ativos)
% =============================

register_job(MatchId, ThiefId, DetectiveId, Scenario, Status) :-
    get_time(Now),
    Dict = _{
        match_id: MatchId,
        status: Status,
        pid: null,
        created_at: Now,
        started_at: null,
        thief_id: ThiefId,
        detective_id: DetectiveId,
        scenario: Scenario
    },
    with_mutex(match_queue_jobs,
               ( retractall(job(MatchId, _)),
                 assertz(job(MatchId, Dict)) )).

mark_running(MatchId) :-
    get_time(Now),
    update_job(MatchId, _{status: "running", started_at: Now}),
    catch(db:update_match_status(MatchId, "running"), _, true).

set_job_pid(MatchId, Pid) :-
    update_job(MatchId, _{pid: Pid}).

update_job(MatchId, Patch) :-
    with_mutex(match_queue_jobs, apply_job_patch(MatchId, Patch)).

% Funde o Patch no job, se ele ainda existir; se ja foi removido (terminou),
% nao faz nada. Chamado sempre sob o mutex match_queue_jobs.
apply_job_patch(MatchId, Patch) :-
    retract(job(MatchId, Old)),
    !,
    New = Old.put(Patch),
    assertz(job(MatchId, New)).
apply_job_patch(_MatchId, _Patch).

forget_job(MatchId) :-
    with_mutex(match_queue_jobs, retractall(job(MatchId, _))).

% =============================
% Consulta (rotas /api/v1/jobs)
% =============================

%!  job_snapshot(-Jobs) is det.
%
%   Lista publica dos jobs ativos (queued|running) com tempo decorrido.
job_snapshot(Jobs) :-
    findall(Dict, job(_, Dict), Dicts),
    maplist(public_job, Dicts, Jobs).

%!  job_info(+MatchId, -Info) is semidet.
%
%   Detalhe de um job ativo. Se nao estiver mais em memoria (ja finalizado),
%   falha -- o chamador pode cair no estado persistido em `matches`.
job_info(MatchId, Info) :-
    job(MatchId, Dict),
    public_job(Dict, Info).

public_job(Dict, Public) :-
    get_time(Now),
    elapsed_ref(Dict, Ref),
    Elapsed is round(Now - Ref),
    Public = _{
        match_id: Dict.match_id,
        status: Dict.status,
        elapsed_seconds: Elapsed,
        pid: Dict.pid,
        thief_id: Dict.thief_id,
        detective_id: Dict.detective_id,
        scenario: Dict.scenario
    }.

% Tempo decorrido conta a partir do inicio da execucao quando ja rodando; antes
% disso (na fila), conta a espera desde a criacao.
elapsed_ref(Dict, Ref) :-
    Started = Dict.started_at,
    number(Started),
    !,
    Ref = Started.
elapsed_ref(Dict, Ref) :-
    Ref = Dict.created_at.

% =============================
% Caminhos
% =============================

worker_file(File) :-
    queue_dir_fact(Dir),
    directory_file_path(Dir, 'match_worker.pl', File).

output_file(MatchId, OutFile) :-
    config:match_runs_dir(DirS),
    atom_string(Dir, DirS),
    make_directory_path(Dir),
    atomic_list_concat([MatchId, '.json'], Name),
    directory_file_path(Dir, Name, OutFile).
