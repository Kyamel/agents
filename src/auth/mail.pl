:- module(mail, [
    send_verification_email/3
]).

:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module('../config').

%!  send_verification_email(+ToEmail, +VerifyUrl, -Status) is det.
%
%   Despacha o email de verificacao para o transporte configurado em
%   `src/config.pl` (`mail_transport/1`). Status:
%     * `sent`    — Resend respondeu OK
%     * `console` — link impresso no terminal (modo dev)
%     * `failed`  — Resend retornou erro
send_verification_email(ToEmail, VerifyUrl, Status) :-
    config:mail_transport(Transport),
    deliver(Transport, ToEmail, VerifyUrl, Status).

% Envia o email transacional via API do Resend.
resend_client(ToEmail, VerifyUrl, Response) :-
    config:resend_api_key(ApiKey),
    config:resend_from(From),

    Payload = _{
        from: From,
        to: [ToEmail],
        subject: "Verify your account",
        html: "<p>Click to verify your account:</p><p><a href=\"" + VerifyUrl + "\">Verify email</a></p>"
    },

    format(string(AuthHeader), 'Bearer ~s', [ApiKey]),

    http_post(
        'https://api.resend.com/emails',
        json(Payload),
        Response,
        [ request_header('Authorization'=AuthHeader),
          json_object(dict),
          timeout(10)
        ]
    ).

deliver(console, ToEmail, VerifyUrl, console) :-
    print_console_link(ToEmail, VerifyUrl).
deliver(resend, ToEmail, VerifyUrl, sent) :-
    catch(resend_client(ToEmail, VerifyUrl, _Resp),
          Error,
          ( log_resend_error(Error), fail )),
    !.
deliver(resend, _ToEmail, _VerifyUrl, failed).
deliver(Other, ToEmail, VerifyUrl, console) :-
    format(user_error,
           '[mail] transport desconhecido "~w"; caindo para console~n', [Other]),
    print_console_link(ToEmail, VerifyUrl).

print_console_link(ToEmail, VerifyUrl) :-
    format(user_error, '~n', []),
    format(user_error, '==============================================================~n', []),
    format(user_error, '[mail:console] Link de verificacao (dev mode)~n', []),
    format(user_error, '  para: ~w~n', [ToEmail]),
    format(user_error, '  link: ~w~n', [VerifyUrl]),
    format(user_error, '==============================================================~n~n', []).

log_resend_error(Error) :-
    format(user_error, '[mail:resend] erro: ~q~n', [Error]).
