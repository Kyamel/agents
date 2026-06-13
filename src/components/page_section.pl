:- module(page_section, [
    top_bar/3,
    page_heading/3,
    back_link/3,
    empty_state/2
]).

%!  top_bar(+Title, +ActionHtml, -Html) is det.
%
%   Barra de cabecalho para telas de listagem com CTA opcional na direita.
top_bar(Title, ActionHtml, Html) :-
    Html = div([class('flex items-center justify-between gap-3 mb-2')], [
        h1([class('text-2xl font-bold')], Title),
        ActionHtml
    ]).

%!  page_heading(+Title, +Subtitle, -Html) is det.
%
%   Bloco padrao de titulo/subtitulo para paginas de formulario e detalhe.
page_heading(Title, Subtitle, Html) :-
    Html = div([class('mb-6')], [
        h1([class('text-2xl font-bold mb-1')], Title),
        p([class('text-slate-400 text-sm')], Subtitle)
    ]).

%!  back_link(+Href, +Label, -Html) is det.
%
%   Link discreto de retorno para navegacao entre telas.
back_link(Href, Label, Html) :-
    Html = a([href(Href), class('text-sm text-ufop-400 hover:underline')], Label).

%!  empty_state(+Text, -Html) is det.
%
%   Texto padrao para listas vazias.
empty_state(Text, Html) :-
    Html = p([class('text-slate-500')], Text).
