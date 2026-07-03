:- module(ui, [
    surface_class/1,
    surface_class/2,
    link_class/1,
    link_class/2,
    text_class/2,
    text_class/3,
    eyebrow_class/2,
    local_time/2
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

% Escala tipografica semantica do app (5 niveis, do menor ao maior):
%   meta      14 px — datas, autoria, rotulos, pills e informacao secundaria;
%   normal    16 px — conteudo principal;
%   emphasis  18 px — nomes, valores e texto introdutorio em destaque;
%   section   20/24 px — titulo de secao responsivo;
%   title     24/30 px — titulo principal de pagina (responsivo).
% `text-xs` nao deve ser usado para conteudo de leitura.
text_class(Kind, Class) :-
    text_base(Kind, Class).
text_class(Kind, Extra, Class) :-
    text_base(Kind, Base),
    atomic_list_concat([Base, Extra], ' ', Class).

text_base(meta,     'text-base leading-4').
text_base(normal,   'text-base leading-5').
text_base(emphasis, 'text-lg leading-5 font-semibold').
text_base(section,  'text-xl leading-5 font-bold sm:text-2xl sm:leading-6').
text_base(title,    'text-2xl leading-6 font-bold sm:text-3xl sm:leading-7').

% Rótulo pequeno em maiúsculas (eyebrow) com cor de acento.
eyebrow_class(Accent, Class) :-
    accent_color(Accent, Color),
    atomic_list_concat([Color, 'text-xs uppercase tracking-wide font-semibold'], ' ', Class).

% Timestamp em ISO 8601 (UTC) que o JS do cliente converte pro fuso horario
% local. Sem JS, o proprio ISO recebido do servidor fica como fallback visivel.
% O script correspondente vive em page.pl (local_time_script/1).
local_time(ISO, time([datetime(ISO), class('js-localtime')], ISO)).

accent_color(amber, 'text-amber-400').
accent_color(sky,   'text-sky-400').
accent_color(emerald, 'text-emerald-400').
accent_color(slate, 'text-surface-500').
