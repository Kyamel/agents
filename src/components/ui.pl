:- module(ui, [
    surface_class/1,
    surface_class/2,
    link_class/1,
    link_class/2,
    eyebrow_class/2
]).

% Receitas de classe Tailwind: combinações de utilitários que se repetem ao
% longo das páginas mas não chegam a ser componentes (fragmentos de DOM). Centraliza
% o vocabulário visual do app num lugar só, para manter a estética consistente e
% facilitar ajustes. Cores primitivas/semânticas ficam no tailwind_config (page.pl);
% fragmentos de DOM inteiros viram componentes próprios (agent_card, alert, ...).

% Aparência de cartão usada em todo o app.
surface_base('rounded-xl bg-surface-900 border border-surface-800').

surface_class(Class) :-
    surface_base(Class).
surface_class(Extra, Class) :-
    surface_base(Base),
    atomic_list_concat([Base, Extra], ' ', Class).

% Link de destaque: cor institucional com sublinhado no hover.
link_class(Class) :-
    link_base(Class).
link_class(Extra, Class) :-
    link_base(Base),
    atomic_list_concat([Base, Extra], ' ', Class).

link_base('text-ufop-400 hover:underline underline-offset-2').

% Rótulo pequeno em maiúsculas (eyebrow) com cor de acento.
eyebrow_class(Accent, Class) :-
    accent_color(Accent, Color),
    atomic_list_concat([Color, 'text-xs uppercase tracking-wide font-semibold'], ' ', Class).

accent_color(amber, 'text-amber-400').
accent_color(sky,   'text-sky-400').
accent_color(slate, 'text-surface-500').
