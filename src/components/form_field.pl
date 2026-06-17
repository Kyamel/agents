:- module(form_field, [
    text_field/5,
    slug_field/4,
    slug_field/5,
    textarea_field/4,
    select_field/4,
    checkbox_field/5,
    submit_button/2
]).

:- use_module(library(apply)).

input_class('w-full rounded-lg bg-surface-900 border border-surface-700 px-3 py-2 text-surface-100 placeholder-surface-500 focus:outline-none focus:border-ufop-500').

label_class('block text-sm font-medium text-surface-300 mb-1').

text_field(Name, Label, Type, Value, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        input([type(Type), name(Name), id(Name), value(Value), class(InputClass)])
    ]).

slug_field(Name, Label, Value, Html) :-
    slug_field(Name, Label, Value, [], Html).

% Forca slug ASCII (minusculas/numeros/hifens) durante a digitacao e valida o
% padrao no envio, para nao precisar normalizar no servidor.
slug_field(Name, Label, Value, ExtraAttrs, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    append([
        type(text), name(Name), id(Name), value(Value), class(InputClass),
        pattern('[a-z0-9-]+'),
        placeholder('meu-agente'),
        title('Use apenas minusculas, numeros e hifens (ex.: meu-agente).'),
        autocapitalize(none), autocomplete(off), spellcheck(false),
        oninput('this.value=this.value.toLowerCase().replace(/[^a-z0-9]+/g,\'-\').slice(0,60)')
    ], ExtraAttrs, Attrs),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        input(Attrs)
    ]).

textarea_field(Name, Label, Value, Html) :-
    input_class(BaseClass),
    label_class(LabelClass),
    atom_concat(BaseClass, ' font-mono text-sm', InputClass),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        textarea([name(Name), id(Name), rows(14), class(InputClass)], Value)
    ]).

% Options e uma lista de opt(Value, Label).
select_field(Name, Label, Options, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    maplist(option_html, Options, OptionEls),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        select([name(Name), id(Name), class(InputClass)], OptionEls)
    ]).

option_html(opt(Value, Label), option([value(Value)], Label)).

checkbox_field(Name, Label, Help, Checked, Html) :-
    checked_attr(Checked, CheckedAttrs),
    append([
        type(checkbox),
        name(Name),
        id(Name),
        value("true"),
        class('h-4 w-4 rounded border-surface-700 bg-surface-900 text-ufop-600 focus:ring-ufop-500')
    ], CheckedAttrs, Attrs),
    Html = label([for(Name),
                  class('mb-4 flex items-start gap-3 rounded-lg border border-surface-800 bg-surface-950/40 p-3 text-sm text-surface-300')],
                 [
                     input(Attrs),
                     span([], [
                         span([class('block font-medium text-surface-100')], Label),
                         span([class('block text-surface-500')], Help)
                     ])
                 ]).

checked_attr(true, [checked(checked)]) :- !.
checked_attr(_, []).

submit_button(Label, Html) :-
    Html = button(
        [ type(submit),
          class('w-full rounded-xl bg-ufop-600 px-4 py-2.5 font-semibold text-white hover:bg-ufop-500')
        ],
        Label
    ).
