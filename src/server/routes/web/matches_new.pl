:- module(route_matches_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(apply)).
:- use_module('../../../db/db').
:- use_module('../../../engine/engine').
:- use_module('../../views/page').
:- use_module('../../views/alert').
:- use_module('../../views/form_field').
:- use_module('../../views/page_section').
:- use_module('../../http/web_session').

:- http_handler(root(matches/new), handler, [methods([get, post])]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(method(Method), Request),
    web_session:require_user(Request, _User),
    dispatch(Method, Request).

dispatch(get, Request) :-
    render_form(Request, _{}).
dispatch(post, Request) :-
    http_parameters(Request, [
        thief_agent_id(ThiefId, [default(""), string]),
        detective_agent_id(DetectiveId, [default(""), string]),
        scenario(Scenario, [default(""), string])
    ]),
    run_new_match(ThiefId, DetectiveId, Scenario, Outcome),
    finish(Outcome, Request, ThiefId, DetectiveId).

finish(ok(MatchId), Request, _, _) :-
    atom_concat('/matches/', MatchId, Location),
    http_redirect(see_other, Location, Request).
finish(error(Message), Request, ThiefId, DetectiveId) :-
    render_form(Request,
        _{error: Message, thief: ThiefId, detective: DetectiveId}).

% =============================
% Logica (validacao, execucao, DB)
% =============================

run_new_match("", _, _, error("Selecione um ladrao e um detetive.")) :- !.
run_new_match(_, "", _, error("Selecione um ladrao e um detetive.")) :- !.
run_new_match(_, _, Scenario, error("Cenário invalido.")) :-
    \+ engine:valid_scenario(Scenario),
    !.
run_new_match(ThiefId, _, _, error("Agente ladrao nao encontrado.")) :-
    \+ db:get_agent(ThiefId, _),
    !.
run_new_match(_, DetectiveId, _, error("Agente detetive nao encontrado.")) :-
    \+ db:get_agent(DetectiveId, _),
    !.
run_new_match(ThiefId, DetectiveId, Scenario, Outcome) :-
    db:get_agent(ThiefId, Thief),
    db:get_agent(DetectiveId, Detective),
    check_roles_and_run(Thief, Detective, ThiefId, DetectiveId, Scenario, Outcome).

check_roles_and_run(Thief, Detective, ThiefId, DetectiveId, Scenario, Outcome) :-
    agent_has_role(Thief, thief),
    agent_has_role(Detective, detective),
    !,
    execute_match(ThiefId, DetectiveId, Thief, Detective, Scenario, Outcome).
check_roles_and_run(_, _, _, _, _,
    error("Papeis invalidos: o primeiro deve ser ladrao e o \c
           segundo detetive.")).

execute_match(ThiefId, DetectiveId, Thief, Detective, Scenario, Outcome) :-
    catch(
        run_and_save(ThiefId, DetectiveId, Thief, Detective, Scenario, Outcome),
        Error,
        match_error_outcome(ThiefId, DetectiveId, Error, Outcome)
    ).

% Apenas ENFILEIRA a partida: cria a linha pendente, devolve o id e redireciona.
% A execucao acontece em background, num subprocesso, gerida por match_queue.
run_and_save(ThiefId, DetectiveId, _Thief, _Detective, Scenario, ok(MatchId)) :-
    engine:enqueue_match(ThiefId, DetectiveId, Scenario, MatchId).

match_error_outcome(ThiefId, DetectiveId, Error, error(Message)) :-
    format(user_error,
           '[match] erro ao enfileirar ladrao=~w detective=~w: ~q~n',
           [ThiefId, DetectiveId, Error]),
    format(string(Message), "Falha ao criar a partida: ~w", [Error]).

agent_has_role(Agent, Role) :-
    agent_role_atom(Agent, RoleAtom),
    RoleAtom == Role.

agent_role_atom(Agent, RoleAtom) :-
    Role = Agent.role,
    role_to_atom(Role, RoleAtom).

role_to_atom(Role, Role) :- atom(Role), !.
role_to_atom(Role, Atom) :- atom_string(Atom, Role).

agent_has_role_(Role, Agent) :- agent_has_role(Agent, Role).

% =============================
% Resposta (HTML)
% =============================

render_form(Request, State) :-
    db:list_agents(Agents),
    include(agent_has_role_(thief), Agents, Thieves),
    include(agent_has_role_(detective), Agents, Detectives),
    render_form_for(Thieves, Detectives, Request, State).

render_form_for([], _, Request, _) :- !,
    render_empty_roster(Request).
render_form_for(_, [], Request, _) :- !,
    render_empty_roster(Request).
render_form_for(Thieves, Detectives, Request, State) :-
    render_form_fields(Request, State, Thieves, Detectives).

render_empty_roster(Request) :-
    alert:alert(info,
        "Cadastre ao menos um agente ladrao e um agente detetive para criar partidas.",
        Notice),
    page:reply_page(Request, 'Nova partida', [
        h1([class('text-2xl font-bold mb-4')], 'Nova partida'),
        Notice
    ]).

render_form_fields(Request, State, Thieves, Detectives) :-
    maplist(agent_option, Thieves, ThiefOptions),
    maplist(agent_option, Detectives, DetectiveOptions),
    scenario_options(ScenarioOptions),
    page_section:page_heading(
        'Nova partida',
        'A partida entra na fila e roda em background; acompanhe o progresso na \c
         pagina da partida.',
        Heading
    ),
    form_field:select_field(thief_agent_id, 'Agente ladrao', ThiefOptions, ThiefField),
    form_field:select_field(detective_agent_id, 'Agente detetive', DetectiveOptions,
                            DetectiveField),
    form_field:select_field(scenario, 'Cenário', ScenarioOptions, ScenarioField),
    form_field:submit_button('Criar e executar partida', Submit),
    state_alert(State, AlertHtml),
    page:reply_page(Request, 'Nova partida', [
        Heading,
        AlertHtml,
        form([method(post), action('/matches/new'), class('max-w-lg')], [
            ThiefField, DetectiveField, ScenarioField, Submit
        ])
    ]).

scenario_options(Options) :-
    engine:available_scenarios(Scenarios),
    maplist(scenario_option, Scenarios, Options).

scenario_option(scenario(Value, Label), opt(Value, Label)).

state_alert(State, Html) :-
    get_dict(error, State, Message),
    !,
    alert:alert(error, Message, Html).
state_alert(_, '').

agent_option(Agent, opt(Id, Label)) :-
    Id = Agent.id,
    format(string(Label), "~w  (~w)", [Agent.name, Id]).
