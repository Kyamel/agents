:- module(route_static, []).

:- use_module(library(http/http_dispatch)).

%   Serve arquivos estaticos (imagens, logos) sob `/assets/...` a partir do
%   diretorio `assets/` na raiz do projeto.
:- http_handler(root(assets), assets_handler, [prefix]).

%!  assets_handler(+Request) is det.
%
%   Resolve o caminho pedido dentro de `assets/` e devolve o arquivo, ou 404.
assets_handler(Request) :-
    (   memberchk(path_info(PathInfo), Request)
    ->  true
    ;   PathInfo = ''
    ),
    strip_leading_slash(PathInfo, Rel),
    (   Rel \== '',
        \+ sub_atom(Rel, _, _, _, '..'),
        atom_concat('assets/', Rel, FilePath),
        exists_file(FilePath)
    ->  http_reply_file(FilePath, [unsafe(true)], Request)
    ;   http_404([], Request)
    ).

%!  strip_leading_slash(+Path, -Rel) is det.
%
%   Remove uma barra inicial do `path_info` (ex.: `/logo.png` -> `logo.png`).
strip_leading_slash(Path, Rel) :-
    (   atom_concat('/', Rel0, Path)
    ->  Rel = Rel0
    ;   Rel = Path
    ).
