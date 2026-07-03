:- module(api_jobs_show, []).

:- use_module('../../http/api_endpoint').
:- use_module('../../../services/jobs').

% Detalhe de um job pelo id da partida. Se o job ainda esta ativo, devolve o
% estado em memoria (com elapsed_seconds em tempo real); se ja terminou, cai no
% estado persistido em `matches` (status final, elapsed nulo).
path(root(api/v1/jobs/Id), [id-Id]).
accept(get, none).

handle(get, _Request, _User, Params, Outcome) :-
    load_job(Params.id, Outcome).

render(_Request, job(Info),  json(200, _{job: Info})).
render(_Request, not_found,  json(404, _{error: "job_not_found"})).

load_job(Id, job(Info)) :-
    jobs:find_job(Id, job(Info)),
    !.
load_job(_, not_found).

:- api_endpoint:mount(api_jobs_show).
