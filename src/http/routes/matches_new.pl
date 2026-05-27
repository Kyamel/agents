:- module(route_matches_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module(library(apply)).
:- use_module('../../db/sqlite_store').
:- use_module('../../engine/match_runner').
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/alert').
:- use_module('../../components/ui/form_field').
:- use_module('../../components/ui/page_section').
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
    (   Outcome = ok(MatchId)
    ->  atom_concat('/matches/', MatchId, Location),
        http_redirect(see_other, Location, Request)
    ;   Outcome = error(Message),
        render_form(Request,
            _{error: Message, thief: ThiefId, detective: DetectiveId})
    ).

% =============================
% Logica (validacao, execucao, DB)
% =============================

run_new_match(ThiefId, DetectiveId, Outcome) :-
    (   ( ThiefId == "" ; DetectiveId == "" )
    ->  Outcome = error("Selecione um ladrao e um detetive.")
    ;   \+ sqlite_store:get_agent(ThiefId, _)
    ->  Outcome = error("Agente ladrao nao encontrado.")
    ;   \+ sqlite_store:get_agent(DetectiveId, _)
    ->  Outcome = error("Agente detetive nao encontrado.")
    ;   sqlite_store:get_agent(ThiefId, Thief),
        sqlite_store:get_agent(DetectiveId, Detective),
        ( agent_has_role(Thief, thief), agent_has_role(Detective, detective)
        ->  execute_match(ThiefId, DetectiveId, Thief, Detective, Outcome)
        ;   Outcome = error("Papeis invalidos: o primeiro deve ser ladrao e o \c
                             segundo detetive.")
        )
    ).

execute_match(ThiefId, DetectiveId, Thief, Detective, Outcome) :-
    catch(
        ( match_runner:run_match(Thief, Detective, Result, ReplayJson),
          sqlite_store:save_match(ThiefId, DetectiveId, Result.winner, ReplayJson, MatchId),
          Outcome = ok(MatchId)
        ),
        Error,
        ( format(user_error,
                 '[match] erro ladrao=~w detective=~w: ~q~n',
                 [ThiefId, DetectiveId, Error]),
          format(string(Message),
                 "Falha ao executar a partida: ~w",
                 [Error]),
          Outcome = error(Message) )
    ).
execute_match(_ThiefId, _DetectiveId, _Thief, _Detective,
              error("Falha ao executar a partida. Verifique o codigo dos agentes.")).

agent_has_role(Agent, Role) :-
    agent_role_atom(Agent, RoleAtom),
    RoleAtom == Role.

agent_role_atom(Agent, RoleAtom) :-
    Role = Agent.role,
    (   atom(Role)
    ->  RoleAtom = Role
    ;   atom_string(RoleAtom, Role)
    ).

agent_has_role_(Role, Agent) :-
    agent_has_role(Agent, Role).

% =============================
% Resposta (HTML)
% =============================

render_form(Request, State) :-
    sqlite_store:list_agents(Agents),
    include(agent_has_role_(thief), Agents, Thieves),
    include(agent_has_role_(detective), Agents, Detectives),
    (   ( Thieves == [] ; Detectives == [] )
    ->  alert:alert(info,
            "Cadastre ao menos um agente ladrao e um agente detetive para criar partidas.",
            Notice),
        page:reply_page(Request, 'Nova partida', [
            h1([class('text-2xl font-bold mb-4')], 'Nova partida'),
            Notice
        ])
    ;   render_form_fields(Request, State, Thieves, Detectives)
    ).

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
    (   get_dict(error, State, Message)
    ->  alert:alert(error, Message, AlertHtml)
    ;   AlertHtml = ''
    ),
    page:reply_page(Request, 'Nova partida', [
        Heading,
        AlertHtml,
        form([method(post), action('/matches/new'), class('max-w-lg')], [
            ThiefField, DetectiveField, Submit
        ])
    ]).

agent_option(Agent, opt(Id, Label)) :-
    Id = Agent.id,
    format(string(Label), "~w  (~w)", [Agent.name, Id]).
