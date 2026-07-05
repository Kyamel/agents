:- module(prolog_code, [
    code_block/2,
    highlight_assets/1
]).

:- use_module(ui).

% Bloco compartilhado para código Prolog. O conteúdo continua legível sem JS;
% o realce local apenas transforma text nodes em spans, sem usar innerHTML.
code_block(Code, Html) :-
    ui:text_class(
        meta,
        'overflow-x-auto rounded-lg bg-surface-950 border \c
         border-surface-700 p-4 text-surface-300',
        Class
    ),
    Html = pre([
        class(Class),
        tabindex(0),
        'aria-label'('Código Prolog')
    ], code([
        class('language-prolog js-prolog-highlight')
    ], Code)).

highlight_assets([
    style([], "
      .ph-comment{color:#8491a4;font-style:italic}
      .ph-string{color:#a7f3d0}
      .ph-number{color:#fcd34d}
      .ph-variable{color:#7dd3fc}
      .ph-functor{color:#f0b3b8}
      .ph-control{color:#c4b5fd;font-weight:600}
    "),
    script([
        src('/assets/prolog_highlight.js?v=1')
    ], [])
]).
