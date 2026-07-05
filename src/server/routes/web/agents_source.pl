:- module(route_agents_source, []).

:- use_module(library(http/http_dispatch)).
:- use_module('../../../services/agents').
:- use_module('../../views/page').
:- use_module('../../views/page_section').
:- use_module('../../views/prolog_code').
:- use_module('../../views/agent_card',
              [role_label/2, role_badge_class/2]).
:- use_module('../../views/ui').

:- http_handler(root(agents/Id/source), handler(Id), [method(get)]).

handler(Id, Request) :-
    agents:source_view(Id, Outcome),
    render_outcome(Outcome, Id, Request).

render_outcome(source(Agent, Source), _Id, Request) :-
    !,
    render_source(Request, Agent, Source).
render_outcome(private, Id, Request) :-
    !,
    format(atom(ProfileHref), '/agents/~w', [Id]),
    page_section:back_link(ProfileHref, 'Voltar para o agente', BackLink),
    ui:text_class(title, 'mt-3 mb-2', TitleClass),
    ui:text_class(normal, 'text-surface-400', TextClass),
    page:reply_page(Request, 'Código privado', [
        BackLink,
        h1([class(TitleClass)], 'Código privado'),
        p([class(TextClass)],
          'O proprietário marcou o código deste agente como privado.')
    ]).
render_outcome(not_found, _Id, Request) :-
    render_not_found(Request).

render_source(Request, Agent, Source) :-
    format(atom(ProfileHref), '/agents/~w', [Agent.id]),
    page_section:back_link(ProfileHref, 'Voltar para o agente', BackLink),
    role_label(Agent.role, RoleLabel),
    role_badge_class(Agent.role, RoleClass),
    format(string(Heading), "~w #~w", [Agent.name, Agent.id]),
    ui:text_class(title, 'mt-3 break-words', TitleClass),
    ui:text_class(section, 'mt-8 mb-4', SectionClass),
    prolog_code:code_block(Source, CodeBlock),
    prolog_code:highlight_assets(HighlightAssets),
    append([
        BackLink,
        div([class('flex flex-wrap items-center gap-3')], [
            h1([class(TitleClass)], Heading),
            span([class(RoleClass)], RoleLabel)
        ]),
        h2([class(SectionClass)], 'Código-fonte'),
        CodeBlock
    ], HighlightAssets, Content),
    format(string(Title), "Código de ~w", [Agent.name]),
    page:reply_page(Request, Title, Content).

render_not_found(Request) :-
    ui:link_class(LinkClass),
    ui:text_class(title, 'mb-2', TitleClass),
    page:reply_page(Request, 'Agente não encontrado', [
        h1([class(TitleClass)], 'Agente não encontrado'),
        a([href('/agents'), class(LinkClass)], 'Voltar para agentes')
    ]).
