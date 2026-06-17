:- module(pagination, [
    paginate/5,
    pagination_nav/3,
    cursor_nav/4
]).

:- use_module(library(uri)).

% Recorta a lista para a pagina pedida e devolve os metadados para a UI.
paginate(Items, PerPage, RequestedPage, PageItems, Meta) :-
    length(Items, TotalItems),
    TotalPages is max(1, ceiling(TotalItems / PerPage)),
    Page0 is max(1, RequestedPage),
    Page is min(Page0, TotalPages),
    Offset is (Page - 1) * PerPage,
    drop(Offset, Items, Rest),
    take(PerPage, Rest, PageItems),
    Meta = _{
        page: Page,
        per_page: PerPage,
        total_items: TotalItems,
        total_pages: TotalPages
    }.

drop(0, Items, Items) :- !.
drop(_, [], []) :- !.
drop(N, [_|Items], Rest) :-
    N1 is N - 1,
    drop(N1, Items, Rest).

take(0, _, []) :- !.
take(_, [], []) :- !.
take(N, [Item|Items], [Item|Rest]) :-
    N1 is N - 1,
    take(N1, Items, Rest).

% Navegacao anterior/proxima via query param `page`.
pagination_nav(_BasePath, Meta, '') :-
    Meta.total_pages =< 1,
    !.
pagination_nav(BasePath, Meta, Html) :-
    PrevPage is Meta.page - 1,
    NextPage is Meta.page + 1,
    page_control(BasePath, PrevPage, Meta.page > 1, 'Anterior', Prev),
    page_control(BasePath, NextPage, Meta.page < Meta.total_pages, 'Proxima', Next),
    format(atom(Label), 'Pagina ~w de ~w', [Meta.page, Meta.total_pages]),
    Html = nav([class('mt-6 flex flex-wrap items-center justify-between gap-3 text-sm')], [
        Prev,
        span([class('text-surface-500')], Label),
        Next
    ]).

page_control(BasePath, Page, true, Label, Html) :-
    format(atom(Href), '~w?page=~w', [BasePath, Page]),
    Html = a([href(Href),
              class('rounded-lg bg-surface-800 px-3 py-1.5 hover:bg-surface-700')],
             Label).
page_control(_, _, false, Label, Html) :-
    Html = span([class('rounded-lg bg-surface-900 px-3 py-1.5 text-surface-600 border border-surface-800')],
                Label).

% Navegacao por cursor. Como cursor e unidirecional, oferecemos "Voltar ao
% inicio" quando o usuario ja esta em uma pagina posterior.
cursor_nav(_BasePath, "", "", '') :- !.
cursor_nav(BasePath, CurrentCursor, NextCursor, Html) :-
    reset_control(BasePath, CurrentCursor, Reset),
    next_control(BasePath, NextCursor, Next),
    Html = nav([class('mt-6 flex flex-wrap items-center justify-between gap-3 text-sm')], [
        Reset,
        span([class('text-surface-500')], 'Paginação por cursor'),
        Next
    ]).

reset_control(_BasePath, "", Html) :-
    !,
    Html = span([class('rounded-lg bg-surface-900 px-3 py-1.5 text-surface-600 border border-surface-800')],
                'Início').
reset_control(BasePath, _CurrentCursor, Html) :-
    Html = a([href(BasePath),
              class('rounded-lg bg-surface-800 px-3 py-1.5 hover:bg-surface-700')],
             'Voltar ao início').

next_control(_BasePath, "", Html) :-
    !,
    Html = span([class('rounded-lg bg-surface-900 px-3 py-1.5 text-surface-600 border border-surface-800')],
                'Próxima').
next_control(BasePath, NextCursor, Html) :-
    uri_encoded(query_value, NextCursor, EncodedCursor),
    format(atom(Href), '~w?cursor=~w', [BasePath, EncodedCursor]),
    Html = a([href(Href),
              class('rounded-lg bg-surface-800 px-3 py-1.5 hover:bg-surface-700')],
             'Próxima').
