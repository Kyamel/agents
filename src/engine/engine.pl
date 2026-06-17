:- module(engine, []).

% Fachada do pacote da engine. Reexporta o que e usado fora de engine/: fila de
% partidas (match_queue), cenarios (match_runner), cache de agentes
% (agent_cache) e registro/validacao de agentes (registry). match_replay e
% sandbox sao internos; match_worker e um subprocesso standalone.

:- reexport(match_queue).
:- reexport(match_runner).
:- reexport(agent_cache).
:- reexport(registry).
