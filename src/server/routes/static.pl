:- module(route_static, []).

:- use_module(library(http/http_dispatch)).

%   Serve arquivos estaticos (imagens, logos) sob `/assets/...` a partir do
%   diretorio `assets/` na raiz do projeto.
:- http_handler(root(assets), assets_handler, [prefix]).

assets_handler(Request) :-
    request_path_info(Request, PathInfo),
    strip_leading_slash(PathInfo, Rel),
    reply_asset(Rel, Request).

request_path_info(Request, PathInfo) :-
    memberchk(path_info(PathInfo), Request),
    !.
request_path_info(_Request, '').

% Bloqueia `..` (path traversal) e serve so o que existir sob assets/.
reply_asset(Rel, Request) :-
    Rel \== '',
    \+ sub_atom(Rel, _, _, _, '..'),
    atom_concat('assets/', Rel, FilePath),
    exists_file(FilePath),
    !,
    http_reply_file(FilePath, [unsafe(true)], Request).
reply_asset(_Rel, Request) :-
    http_404([], Request).

strip_leading_slash(Path, Rel) :-
    atom_concat('/', Rel, Path),
    !.
strip_leading_slash(Path, Path).
