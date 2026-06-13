:- module(route_matches_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../engine/match_runner').
:- use_module('../../components/page').
:- use_module('../../components/alert').
:- use_module('../../components/form_field').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

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
        detective_agent_id(DetectiveId, [default(""), string])
    ]),
    run_new_match(ThiefId, DetectiveId, Outcome),
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

run_new_match("", _, error("Selecione um ladrao e um detetive.")) :- !.
run_new_match(_, "", error("Selecione um ladrao e um detetive.")) :- !.
run_new_match(ThiefId, _, error("Agente ladrao nao encontrado.")) :-
    \+ sqlite_store:get_agent(ThiefId, _),
    !.
run_new_match(_, DetectiveId, error("Agente detetive nao encontrado.")) :-
    \+ sqlite_store:get_agent(DetectiveId, _),
    !.
run_new_match(ThiefId, DetectiveId, Outcome) :-
    sqlite_store:get_agent(ThiefId, Thief),
    sqlite_store:get_agent(DetectiveId, Detective),
    check_roles_and_run(Thief, Detective, ThiefId, DetectiveId, Outcome).

check_roles_and_run(Thief, Detective, ThiefId, DetectiveId, Outcome) :-
    agent_has_role(Thief, thief),
    agent_has_role(Detective, detective),
    !,
    execute_match(ThiefId, DetectiveId, Thief, Detective, Outcome).
check_roles_and_run(_, _, _, _,
    error("Papeis invalidos: o primeiro deve ser ladrao e o \c
           segundo detetive.")).

execute_match(ThiefId, DetectiveId, Thief, Detective, Outcome) :-
    catch(
        run_and_save(ThiefId, DetectiveId, Thief, Detective, Outcome),
        Error,
        match_error_outcome(ThiefId, DetectiveId, Error, Outcome)
    ).

run_and_save(ThiefId, DetectiveId, Thief, Detective, ok(MatchId)) :-
    match_runner:run_match(Thief, Detective, Result, ReplayJson),
    sqlite_store:save_match(ThiefId, DetectiveId, Result.winner, ReplayJson, MatchId).

match_error_outcome(ThiefId, DetectiveId, Error, error(Message)) :-
    format(user_error,
           '[match] erro ladrao=~w detective=~w: ~q~n',
           [ThiefId, DetectiveId, Error]),
    format(string(Message), "Falha ao executar a partida: ~w", [Error]).

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
    sqlite_store:list_agents(Agents),
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
    page_section:page_heading(
        'Nova partida',
        'A partida e executada na hora e o replay fica disponivel ao final.',
        Heading
    ),
    form_field:select_field(thief_agent_id, 'Agente ladrao', ThiefOptions, ThiefField),
    form_field:select_field(detective_agent_id, 'Agente detetive', DetectiveOptions,
                            DetectiveField),
    form_field:submit_button('Criar e executar partida', Submit),
    state_alert(State, AlertHtml),
    page:reply_page(Request, 'Nova partida', [
        Heading,
        AlertHtml,
        form([method(post), action('/matches/new'), class('max-w-lg')], [
            ThiefField, DetectiveField, Submit
        ])
    ]).

state_alert(State, Html) :-
    get_dict(error, State, Message),
    !,
    alert:alert(error, Message, Html).
state_alert(_, '').

agent_option(Agent, opt(Id, Label)) :-
    Id = Agent.id,
    format(string(Label), "~w  (~w)", [Agent.name, Id]).
