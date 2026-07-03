:- module(pagination, [
    paginate/5,
    pagination_nav/3
]).

:- use_module(ui).

% Recorta a lista para a pagina pedida e devolve os metadados para a UI.
paginate(Items, PerPage, RequestedPage, PageItems, Meta) :-
    length(Items, TotalItems),
    TotalPages is ceiling(TotalItems / PerPage),
    Page0 is max(1, RequestedPage),
    effective_page(Page0, TotalPages, Page),
    Offset is (Page - 1) * PerPage,
    drop(Offset, Items, Rest),
    take(PerPage, Rest, PageItems),
    ( Page > 1 -> HasPreviousPage = true ; HasPreviousPage = false ),
    ( Page < TotalPages -> HasNextPage = true ; HasNextPage = false ),
    Meta = _{
        page: Page,
        perPage: PerPage,
        totalItems: TotalItems,
        totalPages: TotalPages,
        hasPreviousPage: HasPreviousPage,
        hasNextPage: HasNextPage
    }.

effective_page(_RequestedPage, 0, 1) :- !.
effective_page(RequestedPage, TotalPages, Page) :-
    Page is min(RequestedPage, TotalPages).

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

pagination_nav(_BasePath, Meta, '') :-
    Meta.totalPages =< 1,
    !.
pagination_nav(BasePath, Meta, Html) :-
    PrevPage is Meta.page - 1,
    NextPage is Meta.page + 1,
    page_control(BasePath, PrevPage, Meta.hasPreviousPage, 'Anterior', Prev),
    page_control(BasePath, NextPage, Meta.hasNextPage, 'Próxima', Next),
    page_window(BasePath, Meta, Window),
    ui:text_class(meta,
                  'mt-8 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-center sm:gap-2',
                  NavClass),
    Html = nav([
        class(NavClass),
        'aria-label'('Navegação entre páginas')
    ], [
        div([class('flex items-center justify-center sm:contents')], Prev),
        div([class('flex min-h-8 items-center justify-center gap-0.5 sm:contents')], Window),
        div([class('flex items-center justify-center sm:contents')], Next)
    ]).

page_control(BasePath, Page, true, Label, Html) :-
    format(atom(Href), '~w?page=~w', [BasePath, Page]),
    Html = a([href(Href),
              class('inline-flex min-h-9 items-center justify-center rounded-lg bg-surface-800 px-3 py-1.5 text-center hover:bg-surface-700')],
             Label).
page_control(_, _, false, Label, Html) :-
    Html = span([class('inline-flex min-h-9 items-center justify-center rounded-lg border border-surface-700 bg-surface-900 px-3 py-1.5 text-center text-surface-600')],
                Label).

page_window(BasePath, Meta, Html) :-
    window_bounds(Meta.page, Meta.totalPages, Start, End),
    numlist(Start, End, Pages),
    maplist(page_number(BasePath, Meta.page), Pages, Numbers),
    first_page_control(BasePath, Meta.page, Start, First),
    last_page_control(BasePath, Meta.page, End, Meta.totalPages, Last),
    leading_ellipsis(Start, Leading),
    trailing_ellipsis(End, Meta.totalPages, Trailing),
    append([First, Leading, Numbers, Trailing, Last], Html).

window_bounds(_CurrentPage, TotalPages, Start, End) :-
    TotalPages =< 7,
    !,
    Start = 1,
    End = TotalPages.
window_bounds(CurrentPage, _TotalPages, 1, 6) :-
    CurrentPage =< 4,
    !.
window_bounds(CurrentPage, TotalPages, Start, TotalPages) :-
    CurrentPage >= TotalPages - 3,
    !,
    Start is TotalPages - 5.
window_bounds(CurrentPage, _TotalPages, Start, End) :-
    Start is CurrentPage - 2,
    End is CurrentPage + 2.

first_page_control(_BasePath, _CurrentPage, 1, []) :- !.
first_page_control(BasePath, CurrentPage, _Start, [Html]) :-
    page_number(BasePath, CurrentPage, 1, Html).

last_page_control(_BasePath, _CurrentPage, TotalPages, TotalPages, []) :- !.
last_page_control(BasePath, CurrentPage, _End, TotalPages, [Html]) :-
    page_number(BasePath, CurrentPage, TotalPages, Html).

leading_ellipsis(Start, [span([class('px-0.5 text-surface-500 sm:px-1'), 'aria-hidden'(true)], '…')]) :-
    Start > 2,
    !.
leading_ellipsis(_, []).

trailing_ellipsis(End, TotalPages,
                  [span([class('px-0.5 text-surface-500 sm:px-1'), 'aria-hidden'(true)], '…')]) :-
    End < TotalPages - 1,
    !.
trailing_ellipsis(_, _, []).

page_number(_BasePath, CurrentPage, CurrentPage, Html) :-
    !,
    Html = span([
        class('inline-flex h-8 min-w-8 items-center justify-center rounded-lg bg-ufop-600 px-1 font-semibold text-white sm:h-9 sm:min-w-9 sm:px-2'),
        'aria-current'(page)
    ], CurrentPage).
page_number(BasePath, _CurrentPage, Page, Html) :-
    format(atom(Href), '~w?page=~w', [BasePath, Page]),
    format(atom(Label), 'Ir para a página ~w', [Page]),
    Html = a([
        href(Href),
        class('inline-flex h-8 min-w-8 items-center justify-center rounded-lg border border-surface-700 bg-surface-900 px-1 hover:border-surface-500 hover:bg-surface-800 sm:h-9 sm:min-w-9 sm:px-2'),
        'aria-label'(Label)
    ], Page).
