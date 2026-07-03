:- module(page_section, [
    top_bar/3,
    page_heading/3,
    back_link/3,
    empty_state/2
]).

:- use_module(ui).

% Cabecalho de listagem com CTA opcional na direita.
top_bar(Title, ActionHtml, Html) :-
    Html = div([class('flex items-center justify-between gap-3 mb-2')], [
        h1([class('text-2xl font-bold')], Title),
        ActionHtml
    ]).

page_heading(Title, Subtitle, Html) :-
    ui:text_class(normal, 'text-surface-400', SubtitleClass),
    Html = div([class('mb-6')], [
        h1([class('text-2xl font-bold mb-1')], Title),
        p([class(SubtitleClass)], Subtitle)
    ]).

back_link(Href, Label, Html) :-
    ui:text_class(auxiliary, AuxiliaryClass),
    ui:link_class(AuxiliaryClass, LinkClass),
    Html = a([href(Href), class(LinkClass)], Label).

empty_state(Text, Html) :-
    Html = p([class('text-surface-500')], Text).
