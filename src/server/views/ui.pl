:- module(ui, [
    surface_class/1,
    surface_class/2,
    padded_surface_class/2,
    padded_surface_class/3,
    link_class/1,
    link_class/2,
    muted_link_class/1,
    muted_link_class/2,
    text_class/2,
    text_class/3,
    eyebrow_class/2,
    micro_label_class/1,
    micro_label_class/2,
    micro_badge_class/1,
    micro_badge_class/2,
    control_class/3,
    status_chip_class/2,
    status_chip_class/3,
    inset_item_class/1,
    inset_item_class/2,
    event_row_base_class/1,
    event_row_class/2,
    table_cell_class/1,
    table_cell_class/2,
    notice_class/2,
    panel_header_class/2,
    panel_header_class/3,
    tinted_card_class/2,
    pill_class/2,
    secondary_button_class/1,
    secondary_button_class/2,
    primary_button_class/1,
    primary_button_class/2,
    primary_button_class/3,
    local_time/2
]).

% Receitas de classe Tailwind: combinações de utilitários que se repetem ao
% longo das páginas mas não chegam a ser componentes (fragmentos de DOM).
% Cores primitivas/semânticas ficam no tailwind_config (page.pl);
% fragmentos de DOM inteiros viram componentes próprios (agent_card, alert, ...).

% Aparência de cartão usada em todo o app.
surface_base('rounded-xl bg-surface-900 border border-surface-700').

surface_class(Class) :-
    surface_base(Class).
surface_class(Extra, Class) :-
    surface_base(Base),
    atomic_list_concat([Base, Extra], ' ', Class).

% Superficies com padding recorrente. Dimensoes estruturais da pagina seguem
% locais; estes tres niveis cobrem cards e paineis reutilizados.
padded_surface_class(Density, Class) :-
    padded_surface_class(Density, '', Class).
padded_surface_class(Density, Extra, Class) :-
    surface_padding(Density, Padding),
    atomic_list_concat([Padding, Extra], ' ', SurfaceExtra),
    surface_class(SurfaceExtra, Class).

surface_padding(compact, 'p-3').
surface_padding(normal,  'p-4').
surface_padding(roomy,   'p-6').

% Link de destaque: cor institucional com sublinhado no hover.
link_class(Class) :-
    link_base(Class).
link_class(Extra, Class) :-
    link_base(Base),
    atomic_list_concat([Base, Extra], ' ', Class).

link_base('text-ufop-400 hover:underline underline-offset-2').

% Link neutro: herda a cor por padrao e fica vermelho UFOP (com sublinhado) so
% no hover. Para nav/footer, onde o link nao deve competir visualmente ate o
% hover. Links de destaque inline continuam no link_class (vermelho fixo).
muted_link_class(Class) :-
    muted_link_base(Class).
muted_link_class(Extra, Class) :-
    muted_link_base(Base),
    atomic_list_concat([Base, Extra], ' ', Class).

muted_link_base('hover:text-ufop-400 hover:underline underline-offset-2 transition').

% Botao primario (acao institucional preenchida).
primary_button_class(Class) :-
    primary_button_class(default, '', Class).
primary_button_class(Layout, Class) :-
    primary_button_tone(Tone),
    atomic_list_concat([Layout, Tone], ' ', Class).
primary_button_class(Variant, Extra, Class) :-
    primary_button_layout(Variant, Layout),
    atomic_list_concat([Layout, Extra], ' ', FullLayout),
    primary_button_class(FullLayout, Class).

primary_button_tone('bg-ufop-600 text-white font-semibold hover:bg-ufop-500 transition').

primary_button_layout(default, 'inline-block rounded-xl px-4 py-2').
primary_button_layout(full,    'w-full rounded-xl px-4 py-2.5 text-center').
primary_button_layout(compact, 'rounded-lg px-3 py-2').
primary_button_layout(small,   'rounded-lg px-3 py-1.5').

secondary_button_class(Class) :-
    secondary_button_class('', Class).
secondary_button_class(Extra, Class) :-
    atomic_list_concat(
        ['rounded-lg bg-surface-800 border border-surface-600 px-3 py-2 \c
          hover:border-surface-400 transition',
         Extra],
        ' ',
        Class
    ).

% Cartao com tom de acento (banners de status, resultado da partida, etc.).
tinted_card_class(Accent, Class) :-
    tinted_card_tone(Accent, Tone),
    atomic_list_concat(['rounded-xl p-4 border', Tone], ' ', Class).

tinted_card_tone(amber,   'bg-amber-950 border-amber-800 text-amber-200').
tinted_card_tone(sky,     'bg-sky-950 border-sky-800 text-sky-200').
tinted_card_tone(emerald, 'bg-emerald-950 border-emerald-800 text-emerald-200').
tinted_card_tone(ufop,    'bg-ufop-950 border-ufop-700 text-ufop-200').
tinted_card_tone(neutral, 'bg-surface-900 border-surface-600 text-surface-200').

% Pill/etiqueta arredondada curta (badges de vencedor, papel, privacidade).
pill_class(Accent, Class) :-
    pill_tone(Accent, Tone),
    atomic_list_concat(['rounded-full px-2.5 py-1 whitespace-nowrap', Tone], ' ', Base),
    text_class(meta, Base, Class).

pill_tone(amber,   'bg-amber-950 text-amber-300').
pill_tone(sky,     'bg-sky-950 text-sky-300').
pill_tone(emerald, 'bg-emerald-950 text-emerald-300').
pill_tone(ufop,    'bg-ufop-950 text-ufop-200').
pill_tone(neutral, 'bg-surface-800 text-surface-300').
pill_tone(muted,   'bg-surface-950 text-surface-400 border border-surface-700').

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

text_base(meta,     'text-sm leading-4').
text_base(normal,   'text-base leading-5').
text_base(emphasis, 'text-lg leading-5 font-semibold').
text_base(section,  'text-xl leading-5 font-bold sm:text-2xl sm:leading-6').
text_base(title,    'text-2xl leading-6 font-bold sm:text-3xl sm:leading-7').

% Rótulo pequeno em maiúsculas (eyebrow) com cor de acento.
eyebrow_class(Accent, Class) :-
    accent_color(Accent, Color),
    atomic_list_concat([Color, 'text-xs uppercase tracking-wide font-semibold'], ' ', Class).

% Microtexto serve apenas para rotulos densos dentro de componentes.
micro_label_class(Class) :-
    micro_label_class('', Class).
micro_label_class(Extra, Class) :-
    atomic_list_concat(
        ['text-[0.65rem] uppercase tracking-wide font-semibold', Extra],
        ' ',
        Class
    ).

micro_badge_class(Class) :-
    micro_badge_class('', Class).
micro_badge_class(Extra, Class) :-
    micro_label_class(
        'rounded-full border px-2 py-0.5',
        Base
    ),
    atomic_list_concat([Base, Extra], ' ', Class).

% Controles de formulario e controles compactos preservam o mesmo raio,
% borda, foco e tipografia; apenas o padding muda por densidade.
control_class(Density, Extra, Class) :-
    control_padding(Density, Padding),
    atomic_list_concat(
        ['rounded-lg bg-surface-900 border border-surface-600 \c
          text-surface-100 focus:outline-none focus:border-ufop-500',
         Padding, Extra],
        ' ',
        Control
    ),
    text_class(normal, Control, Class).

control_padding(normal,  'px-3 py-2').
control_padding(compact, 'px-2 py-1').

% Chips que identificam entidades (suspeito, identidade do ladrao).
status_chip_class(Accent, Class) :-
    status_chip_class(Accent, '', Class).
status_chip_class(Accent, Extra, Class) :-
    status_chip_tone(Accent, Tone),
    atomic_list_concat(
        ['rounded-full border px-2.5 py-1 font-mono font-semibold \c
          normal-case tracking-normal',
         Tone, Extra],
        ' ',
        Class
    ).

status_chip_tone(amber, 'bg-amber-950 border-amber-800 text-amber-300').
status_chip_tone(sky,   'bg-sky-950 border-sky-800 text-sky-300').

% Item compacto neutro: pistas, tags e valores curtos.
inset_item_class(Class) :-
    inset_item_class('', Class).
inset_item_class(Extra, Class) :-
    atomic_list_concat(
        ['rounded-lg bg-surface-950 border border-surface-700 px-2.5 py-1',
         Extra],
        ' ',
        Class
    ).

% Linha de evento compartilhada pelo detalhe e pelos templates do mapa.
event_row_base_class('rounded-lg border px-3 py-2').

event_row_class(Accent, Class) :-
    event_row_base_class(Base),
    event_row_tone(Accent, Tone),
    atomic_list_concat([Base, Tone], ' ', Class).

event_row_tone(amber,
               'bg-amber-950/40 border-amber-900/60 text-amber-200').
event_row_tone(reveal,
               'bg-reveal-surface/40 border-reveal-border text-reveal-text').
event_row_tone(emerald,
               'bg-emerald-950/40 border-emerald-800 text-emerald-200').
event_row_tone(sky,
               'bg-sky-950/40 border-sky-800 text-sky-200').
event_row_tone(neutral,
               'bg-surface-900 border-surface-700 text-surface-300').

table_cell_class(Class) :-
    table_cell_class('', Class).
table_cell_class(Extra, Class) :-
    atomic_list_concat(['px-3 py-2', Extra], ' ', Class).

% Avisos de pagina usam mais area clicavel/respiracao que linhas de evento.
notice_class(Accent, Class) :-
    notice_tone(Accent, Tone),
    atomic_list_concat(
        ['rounded-lg border px-4 py-3 mb-5', Tone],
        ' ',
        Base
    ),
    text_class(normal, Base, Class).

notice_tone(ufop,    'border-ufop-900 bg-ufop-950 text-ufop-200').
notice_tone(emerald, 'border-emerald-900 bg-emerald-950 text-emerald-200').
notice_tone(sky,     'border-sky-900 bg-sky-950 text-sky-200').

% Cabecalho interno de painel; conteudo e layout externo continuam no caller.
panel_header_class(Accent, Class) :-
    panel_header_class(Accent, '', Class).
panel_header_class(Accent, Extra, Class) :-
    eyebrow_class(Accent, Eyebrow),
    atomic_list_concat(
        [Eyebrow, 'mb-3 flex flex-wrap items-center gap-2', Extra],
        ' ',
        Class
    ).

% Timestamp em ISO 8601 (UTC) que o JS do cliente converte pro fuso horario
% local. Sem JS, o proprio ISO recebido do servidor fica como fallback visivel.
% O script correspondente vive em page.pl (local_time_script/1).
local_time(ISO, time([datetime(ISO), class('js-localtime')], ISO)).

accent_color(amber, 'text-amber-400').
accent_color(sky,   'text-sky-400').
accent_color(emerald, 'text-emerald-400').
accent_color(slate, 'text-surface-500').
