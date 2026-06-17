:- module(alert, [
    alert/3
]).

% `Kind` e um de `error`, `success` ou `info`.
alert(Kind, Message, Html) :-
    alert_class(Kind, Class),
    Html = div([class(Class)], Message).

alert_class(error,
    'rounded-lg border border-red-900 bg-red-950 text-red-200 px-4 py-3 mb-5 text-sm').
alert_class(success,
    'rounded-lg border border-emerald-900 bg-emerald-950 text-emerald-200 px-4 py-3 mb-5 text-sm').
alert_class(info,
    'rounded-lg border border-blue-900 bg-blue-950 text-blue-200 px-4 py-3 mb-5 text-sm').
