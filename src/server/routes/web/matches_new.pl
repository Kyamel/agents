:- module(route_matches_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(apply)).
:- use_module('../../../engine/engine').
:- use_module('../../../services/matches').
:- use_module('../../http/web_session').
:- use_module('../../views/page').
:- use_module('../../views/alert').
:- use_module('../../views/form_field').
:- use_module('../../views/page_section').
:- use_module('../../views/ui').

:- http_handler(root(matches/new), handler, [methods([get, post])]).

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
    matches:create_match(ThiefId, DetectiveId, Scenario, Created),
    finish(Created, ThiefId, DetectiveId, Request).

finish(created(MatchId), _, _, Request) :-
    !,
    atom_concat('/matches/', MatchId, Location),
    http_redirect(see_other, Location, Request).
finish(Outcome, ThiefId, DetectiveId, Request) :-
    outcome_message(Outcome, Message),
    render_form(Request, _{error: Message, thief: ThiefId, detective: DetectiveId}).

outcome_message(missing_agents,
                "Selecione um ladrão e um detetive.").
outcome_message(thief_not_found,
                "Agente ladrão não encontrado.").
outcome_message(detective_not_found,
                "Agente detetive não encontrado.").
outcome_message(invalid_scenario,
                "Cenário inválido.").
outcome_message(invalid_roles,
                "Papéis inválidos: o primeiro deve ser ladrão e o segundo detetive.").
outcome_message(enqueue_failed,
                "Falha ao criar a partida. Tente novamente.").

% Resposta (HTML)
render_form(Request, State) :-
    matches:eligible_rosters(Thieves, Detectives),
    render_form_for(Thieves, Detectives, Request, State).

render_form_for([], _, Request, _) :- !,
    render_empty_roster(Request).
render_form_for(_, [], Request, _) :- !,
    render_empty_roster(Request).
render_form_for(Thieves, Detectives, Request, State) :-
    render_form_fields(Request, State, Thieves, Detectives).

render_empty_roster(Request) :-
    ui:text_class(title, 'mb-4', TitleClass),
    alert:alert(info,
        "Cadastre ao menos um agente ladrão e um agente detetive para criar partidas.",
        Notice),
    page:reply_page(Request, 'Nova partida', [
        h1([class(TitleClass)], 'Nova partida'),
        Notice
    ]).

render_form_fields(Request, State, Thieves, Detectives) :-
    maplist(agent_option, Thieves, ThiefOptions),
    maplist(agent_option, Detectives, DetectiveOptions),
    scenario_options(ScenarioOptions),
    page_section:page_heading(
        'Nova partida',
        'A partida entra na fila e roda em background; acompanhe o progresso na \c
         página da partida.',
        Heading
    ),
    form_field:select_field(thief_agent_id, 'Agente ladrão', ThiefOptions, ThiefField),
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
    format(string(Label), "~w  #~w", [Agent.name, Id]).
