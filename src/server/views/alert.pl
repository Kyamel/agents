:- module(alert, [
    alert/3
]).

:- use_module(ui).

% `Kind` e um de `error`, `success` ou `info`.
alert(Kind, Message, Html) :-
    alert_accent(Kind, Accent),
    ui:notice_class(Accent, Class),
    Html = div([class(Class)], Message).

alert_accent(error, ufop).
alert_accent(success, emerald).
alert_accent(info, sky).
