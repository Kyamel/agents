:- module(form_field, [
    text_field/5,
    text_field/6,
    slug_field/4,
    slug_field/5,
    textarea_field/4,
    select_field/4,
    select_field/5,
    checkbox_field/5,
    submit_button/2
]).

:- use_module(library(apply)).
:- use_module(ui).

input_class(Class) :-
    ui:text_class(
        normal,
        'w-full rounded-lg bg-surface-900 border border-surface-600 px-3 py-2 \c
         text-surface-100 placeholder-surface-500 focus:outline-none focus:border-ufop-500',
        Class
    ).

label_class(Class) :-
    ui:text_class(normal, 'block font-medium text-surface-300 mb-1', Class).

text_field(Name, Label, Type, Value, Html) :-
    text_field(Name, Label, Type, Value, [], Html).

text_field(Name, Label, Type, Value, ExtraAttrs, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    append(
        [type(Type), name(Name), id(Name), value(Value), class(InputClass)],
        ExtraAttrs,
        InputAttrs
    ),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        input(InputAttrs)
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
    atom_concat(BaseClass, ' font-mono', InputClass),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        textarea([name(Name), id(Name), rows(14), class(InputClass)], Value)
    ]).

% Options e uma lista de opt(Value, Label).
select_field(Name, Label, Options, Html) :-
    select_field(Name, Label, Options, "", Html).

select_field(Name, Label, Options, Selected, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    maplist(option_html(Selected), Options, OptionEls),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        select([name(Name), id(Name), class(InputClass)], OptionEls)
    ]).

option_html(Selected, placeholder(Value, Label), option(Attrs, Label)) :-
    option_attrs(Value, Selected, BaseAttrs),
    append(BaseAttrs, [disabled(disabled), hidden(hidden)], Attrs).
option_html(Selected, opt(Value, Label), option(Attrs, Label)) :-
    option_attrs(Value, Selected, Attrs).

option_attrs(Value, Selected, [value(Value), selected(selected)]) :-
    Value == Selected,
    !.
option_attrs(Value, _Selected, [value(Value)]).

checkbox_field(Name, Label, Help, Checked, Html) :-
    checked_attr(Checked, CheckedAttrs),
    ui:text_class(
        normal,
        'mb-4 flex items-start gap-3 rounded-lg border border-surface-700 \c
         bg-surface-950/40 p-3 text-surface-300',
        FieldClass
    ),
    append([
        type(checkbox),
        name(Name),
        id(Name),
        value("true"),
        class('h-4 w-4 rounded border-surface-600 bg-surface-900 text-ufop-600 focus:ring-ufop-500')
    ], CheckedAttrs, Attrs),
    Html = label([for(Name), class(FieldClass)],
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
    ui:primary_button_class('w-full rounded-xl px-4 py-2.5 text-center', Class),
    Html = button(
        [ type(submit),
          class(Class)
        ],
        Label
    ).
