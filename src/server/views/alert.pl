:- module(alert, [
    alert/3
]).

:- use_module(ui).

% `Kind` e um de `error`, `success` ou `info`.
alert(Kind, Message, Html) :-
    alert_class(Kind, BaseClass),
    ui:text_class(normal, BaseClass, Class),
    Html = div([class(Class)], Message).

alert_class(error,
    'rounded-lg border border-rose-900 bg-rose-950 text-rose-200 px-4 py-3 mb-5').
alert_class(success,
    'rounded-lg border border-emerald-900 bg-emerald-950 text-emerald-200 px-4 py-3 mb-5').
alert_class(info,
    'rounded-lg border border-sky-900 bg-sky-950 text-sky-200 px-4 py-3 mb-5').
