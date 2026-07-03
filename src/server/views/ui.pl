:- module(ui, [
    surface_class/1,
    surface_class/2,
    link_class/1,
    link_class/2,
    text_class/2,
    text_class/3,
    eyebrow_class/2
]).

% Receitas de classe Tailwind: combinações de utilitários que se repetem ao
% longo das páginas mas não chegam a ser componentes (fragmentos de DOM).
% Cores primitivas/semânticas ficam no tailwind_config (page.pl);
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

% Escala tipografica semantica do app:
%   normal    16 px — conteudo principal;
%   highlight 18 px — nomes e valores em destaque;
%   lead      18 px — texto introdutorio sem negrito;
%   auxiliary 14 px — datas, autoria e informacao secundaria;
%   badge      12 px — pills e rotulos curtos.
%   page_title 24 px — titulo principal de uma pagina;
%   section_title 20/24 px — titulo de secao responsivo;
%   hero_title 30/36 px — titulo de destaque da pagina inicial/About.
% `text-xs` nao deve ser usado para conteudo de leitura.
text_class(Kind, Class) :-
    text_base(Kind, Class).
text_class(Kind, Extra, Class) :-
    text_base(Kind, Base),
    atomic_list_concat([Base, Extra], ' ', Class).

text_base(normal,    'text-base leading-6').
text_base(highlight, 'text-lg leading-7 font-semibold').
text_base(lead,      'text-lg leading-7').
text_base(auxiliary, 'text-sm leading-5').
text_base(badge,     'text-xs leading-4 font-medium').
text_base(page_title,    'text-2xl leading-8 font-bold').
text_base(section_title, 'text-xl leading-7 font-bold sm:text-2xl sm:leading-8').
text_base(hero_title,    'text-3xl leading-9 font-bold sm:text-4xl sm:leading-10').

% Rótulo pequeno em maiúsculas (eyebrow) com cor de acento.
eyebrow_class(Accent, Class) :-
    accent_color(Accent, Color),
    atomic_list_concat([Color, 'text-xs uppercase tracking-wide font-semibold'], ' ', Class).

accent_color(amber, 'text-amber-400').
accent_color(sky,   'text-sky-400').
accent_color(emerald, 'text-emerald-400').
accent_color(slate, 'text-surface-500').
