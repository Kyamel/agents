:- module(alert, [
    alert/3
]).

:- use_module(ui).

% `Kind` e um de `error`, `success` ou `info`.
alert(Kind, Message, Html) :-
    alert_accent(Kind, Accent),
    alert_attributes(Kind, Attributes),
    ui:notice_class(Accent, Class),
    Html = div([class(Class)|Attributes], Message).

alert_attributes(error, [
    role(alert),
    'aria-live'(assertive),
    'aria-atomic'(true)
]) :- !.
alert_attributes(_, [
    role(status),
    'aria-live'(polite),
    'aria-atomic'(true)
]).

alert_accent(error, ufop).
alert_accent(success, emerald).
alert_accent(info, sky).
