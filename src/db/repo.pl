:- module(repo, [
    exec/1,
    get_one/3,
    get_all/3,
    get_one_with/3,
    get_all_with/3,
    insert/2,
    lit/2,
    quote/2,
    now_iso/1,
    int_of_bool/2,
    int/2,
    text/2,
    count_rows/3,
    paginate/4
]).

:- use_module(connection).

% Toolkit de repositorio: as pecas repetitivas de acesso ao SQLite num lugar so,
% pra que cada repositorio de recurso (ex.: agents_repo) fique curto e novas
% consultas sejam faceis de escrever.

%!  exec(+SQL) is det.
exec(SQL) :-
    sql_exec(SQL).

%!  insert(+SQL, -RowId) is det.
%
%   Executa um INSERT e devolve o rowid gerado.
insert(SQL, RowId) :-
    sql_exec(SQL),
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, "SELECT last_insert_rowid();", row(RowId))).

%!  get_one(+SQL, +Fields, -Dict) is semidet.
%
%   Primeira linha do SELECT mapeada por uma lista de campos `Nome-Decoder`;
%   falha se nao houver linha.
get_one(SQL, Fields, Dict) :-
    get_one_with(SQL, row_to_dict(Fields), Dict).

%!  get_all(+SQL, +Fields, -Dicts) is det.
get_all(SQL, Fields, Dicts) :-
    get_all_with(SQL, row_to_dict(Fields), Dicts).

% Variantes com mapeador customizado, para linhas que precisam de logica de
% dominio (ex.: status de partida com fallback). `Mapper` e chamado como
% call(Mapper, +Row, -Dict).
:- meta_predicate get_one_with(+, 2, -), get_all_with(+, 2, -).

get_one_with(SQL, Mapper, Dict) :-
    ensure_connected,
    conn_alias(Alias),
    once(prosqlite:sqlite_query(Alias, SQL, Row)),
    call(Mapper, Row, Dict).

get_all_with(SQL, Mapper, Dicts) :-
    ensure_connected,
    conn_alias(Alias),
    findall(Dict,
            ( prosqlite:sqlite_query(Alias, SQL, Row),
              call(Mapper, Row, Dict) ),
            Dicts).

% Literais SQL com escape (unica barreira contra injection; ver connection.pl).
lit(Value, Literal) :- sql_literal(Value, Literal).
quote(Text, Quoted) :- sql_quote(Text, Quoted).

now_iso(Iso) :-
    get_time(Now),
    format_time(string(Iso), '%FT%TZ', Now).

row_to_dict(Fields, Row, Dict) :-
    Row =.. [row|Values],
    maplist(decode_field, Fields, Values, Pairs),
    dict_pairs(Dict, row, Pairs).

decode_field(Name-Decoder, Raw, Name-Value) :-
    decode(Decoder, Raw, Value).

% Decoders por tipo de coluna do SQLite. Regra unica do projeto: coluna INTEGER
% vira inteiro (`int`), coluna TEXT vira string (`text`/`optional`). O driver
% devolve INTEGER como inteiro e TEXT como atom.
decode(int, Raw, Int) :- to_int(Raw, Int).
decode(text, Raw, Text) :- to_text(Raw, Text).
decode(bool, Raw, Bool) :- bool_of_int(Raw, Bool).
decode(optional, '$null$', "") :- !.
decode(optional, Raw, Text) :- to_text(Raw, Text).

bool_of_int(1, true).
bool_of_int('1', true).
bool_of_int(0, false).
bool_of_int('0', false).
bool_of_int('$null$', false).

%!  int_of_bool(+Bool, -Int) is det.   (para montar INSERT/UPDATE)
int_of_bool(true, 1).
int_of_bool(false, 0).

%!  text(+Raw, -Text) is det.   Converte qualquer valor do driver em string.
text(Raw, Text) :- to_text(Raw, Text).

to_text(Raw, Raw) :- string(Raw), !.
to_text(Raw, Text) :- atom(Raw), !, atom_string(Raw, Text).
to_text(Raw, Text) :- format(string(Text), "~w", [Raw]).

%!  int(+Raw, -Int) is det.   Converte qualquer valor do driver em inteiro.
int(Raw, Int) :- to_int(Raw, Int).

to_int(Raw, Raw)  :- integer(Raw), !.
to_int(Raw, Int)  :- float(Raw), !, Int is truncate(Raw).
to_int(Raw, Int)  :- atom(Raw), !, atom_number(Raw, N), Int is integer(N).
to_int(Raw, Int)  :- string(Raw), !, number_string(N, Raw), Int is integer(N).

% Paginacao (generica)

%!  count_rows(+Table, +WhereClause, -Total) is det.
count_rows(Table, Where, Total) :-
    conn_alias(Alias),
    format(string(SQL), "SELECT COUNT(*) FROM ~w ~w;", [Table, Where]),
    once(prosqlite:sqlite_query(Alias, SQL, row(Total))).

%!  paginate(+RequestedPage, +PerPage, +TotalItems, -Pagination) is det.
paginate(RequestedPage, PerPage, TotalItems, Pagination) :-
    TotalPages is ceiling(TotalItems / PerPage),
    Page0 is max(1, RequestedPage),
    effective_page(Page0, TotalPages, Page),
    has_prev(Page, HasPreviousPage),
    has_next(Page, TotalPages, HasNextPage),
    Pagination = _{
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

has_prev(Page, true) :- Page > 1, !.
has_prev(_Page, false).

has_next(Page, TotalPages, true) :- Page < TotalPages, !.
has_next(_Page, _TotalPages, false).
