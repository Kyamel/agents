:- module(page_section, [
    top_bar/3,
    page_heading/3,
    back_link/3,
    empty_state/2
]).

:- use_module(ui).

% Cabecalho de listagem com CTA opcional na direita.
top_bar(Title, ActionHtml, Html) :-
    ui:text_class(title, HeadingClass),
    Html = div([class('flex items-center justify-between gap-3 mb-2')], [
        h1([class(HeadingClass)], Title),
        ActionHtml
    ]).

page_heading(Title, Subtitle, Html) :-
    ui:text_class(title, 'mb-1', HeadingClass),
    ui:text_class(emphasis, 'text-surface-400', SubtitleClass),
    Html = div([class('mb-6')], [
        h1([class(HeadingClass)], Title),
        p([class(SubtitleClass)], Subtitle)
    ]).

back_link(Href, Label, Html) :-
    ui:text_class(meta, MetaClass),
    ui:link_class(MetaClass, LinkClass),
    Html = a([href(Href), class(LinkClass)], Label).

empty_state(Text, Html) :-
    ui:text_class(normal, 'text-surface-500', Class),
    Html = p([class(Class)], Text).
