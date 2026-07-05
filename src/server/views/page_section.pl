:- module(page_section, [
    top_bar/3,
    page_heading/3,
    eyebrow_heading/3,
    back_link/3,
    back_link_to_list/4,
    empty_state/2
]).

:- use_module(ui).
:- use_module(library(uri)).
:- use_module(library(lists)).

% Eyebrow (rotulo curto em maiusculas) acima de um titulo de secao. Usado em
% paginas de conteudo (about) para separar blocos.
eyebrow_heading(Eyebrow, Title, Html) :-
    ui:eyebrow_class(slate, EyebrowBase),
    atomic_list_concat([EyebrowBase, 'mb-1'], ' ', EyebrowClass),
    ui:text_class(section, TitleClass),
    Html = div([class('mb-5')], [
        p([class(EyebrowClass)], Eyebrow),
        h2([class(TitleClass)], Title)
    ]).

% Cabecalho de listagem com CTA opcional na direita.
top_bar(Title, ActionHtml, Html) :-
    ui:text_class(title, HeadingClass),
    Html = div([class('flex items-center justify-between gap-3 mb-2 mt-2')], [
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

% Link de "voltar" para uma listagem paginada que preserva a pagina de
% origem. Se o usuario chegou aqui a partir da propria listagem (Referer
% com o mesmo caminho), reaproveita a query string (ex.: ?page=3). Caso
% contrario (acesso direto, recarga, vindo de outra tela), cai no caminho
% base sem query.
back_link_to_list(Request, ListPath, Label, Html) :-
    back_list_href(Request, ListPath, Href),
    back_link(Href, Label, Html).

back_list_href(Request, ListPath, Href) :-
    memberchk(referer(Referer), Request),
    referer_list_href(Referer, ListPath, Href),
    !.
back_list_href(_Request, ListPath, ListPath).

referer_list_href(Referer, ListPath, Href) :-
    uri_components(Referer, Components),
    uri_data(path, Components, Path),
    Path == ListPath,
    uri_data(search, Components, Search),
    list_href(ListPath, Search, Href).

list_href(ListPath, Search, ListPath) :-
    ( var(Search) ; Search == '' ),
    !.
list_href(ListPath, Search, Href) :-
    atomic_list_concat([ListPath, '?', Search], Href).

empty_state(Text, Html) :-
    ui:text_class(normal, 'text-surface-500', Class),
    Html = p([class(Class)], Text).
