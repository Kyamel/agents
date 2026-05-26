:- module(form_field, [
    text_field/5,
    textarea_field/4,
    select_field/4,
    submit_button/2
]).

:- use_module(library(apply)).

%!  input_class(-Class) is det.
%
%   Classe Tailwind base para inputs de formulario.
input_class('w-full rounded-lg bg-slate-900 border border-slate-700 px-3 py-2 text-slate-100 placeholder-slate-500 focus:outline-none focus:border-ufop-500').

%!  label_class(-Class) is det.
%
%   Classe Tailwind para rotulos de campo.
label_class('block text-sm font-medium text-slate-300 mb-1').

%!  text_field(+Name, +Label, +Type, +Value, -Html) is det.
%
%   Campo de texto rotulado (`Type` pode ser `text`, `email`, `password`...).
text_field(Name, Label, Type, Value, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        input([type(Type), name(Name), id(Name), value(Value), class(InputClass)])
    ]).

%!  textarea_field(+Name, +Label, +Value, -Html) is det.
%
%   Campo de texto multilinha rotulado, em fonte monoespacada.
textarea_field(Name, Label, Value, Html) :-
    input_class(BaseClass),
    label_class(LabelClass),
    atom_concat(BaseClass, ' font-mono text-sm', InputClass),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        textarea([name(Name), id(Name), rows(14), class(InputClass)], Value)
    ]).

%!  select_field(+Name, +Label, +Options, -Html) is det.
%
%   Campo de selecao rotulado. `Options` e uma lista de `opt(Value, Label)`.
select_field(Name, Label, Options, Html) :-
    input_class(InputClass),
    label_class(LabelClass),
    maplist(option_html, Options, OptionEls),
    Html = div([class('mb-4')], [
        label([for(Name), class(LabelClass)], Label),
        select([name(Name), id(Name), class(InputClass)], OptionEls)
    ]).

%!  option_html(+Opt, -Html) is det.
%
%   Converte `opt(Value, Label)` em um elemento `<option>`.
option_html(opt(Value, Label), option([value(Value)], Label)).

%!  submit_button(+Label, -Html) is det.
%
%   Botao primario de envio de formulario, ocupando a largura disponivel.
submit_button(Label, Html) :-
    Html = button(
        [ type(submit),
          class('w-full rounded-xl bg-ufop-600 px-4 py-2.5 font-semibold text-white hover:bg-ufop-500')
        ],
        Label
    ).
