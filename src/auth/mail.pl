:- module(mail, [
    send_verification_email/3
]).

:- use_module('../config/env').
:- use_module('../http/resend_client', []).

%!  send_verification_email(+ToEmail, +VerifyUrl, -Status) is det.
%
%   Despacha o email de verificacao para o transporte ativo. Status:
%     * `sent`    — Resend respondeu OK
%     * `console` — link impresso no terminal (dev fallback)
%     * `failed`  — Resend retornou erro
%
%   Escolha do transporte (em ordem de precedencia):
%     1. env MAIL_TRANSPORT=console|resend (explicito)
%     2. APP_ENV != production -> console (dev por padrao)
%     3. RESEND_API_KEY vazio  -> console (fallback)
%     4. caso contrario        -> resend
send_verification_email(ToEmail, VerifyUrl, Status) :-
    chosen_transport(Transport),
    deliver(Transport, ToEmail, VerifyUrl, Status).

%!  chosen_transport(-Transport) is det.
chosen_transport(Transport) :-
    env:env_string('MAIL_TRANSPORT', "", Explicit),
    Explicit \== "",
    !,
    atom_string(Transport, Explicit).
chosen_transport(console) :-
    env:env_string('APP_ENV', "development", AppEnv),
    AppEnv \== "production",
    !.
chosen_transport(console) :-
    env:env_string('RESEND_API_KEY', "", ApiKey),
    ApiKey == "",
    !.
chosen_transport(resend).

%!  deliver(+Transport, +ToEmail, +VerifyUrl, -Status) is det.
deliver(console, ToEmail, VerifyUrl, console) :-
    print_console_link(ToEmail, VerifyUrl).
deliver(resend, ToEmail, VerifyUrl, sent) :-
    catch(resend_client:send_verification_email(ToEmail, VerifyUrl, _Resp),
          Error,
          ( log_resend_error(Error), fail )),
    !.
deliver(resend, _ToEmail, _VerifyUrl, failed).
deliver(Other, ToEmail, VerifyUrl, console) :-
    format(user_error,
           '[mail] transport desconhecido "~w"; caindo para console~n', [Other]),
    print_console_link(ToEmail, VerifyUrl).

%!  print_console_link(+ToEmail, +VerifyUrl) is det.
%
%   Imprime o link de verificacao no stderr de forma visivel para o dev.
print_console_link(ToEmail, VerifyUrl) :-
    format(user_error, '~n', []),
    format(user_error, '==============================================================~n', []),
    format(user_error, '[mail:console] Link de verificacao (dev mode)~n', []),
    format(user_error, '  para: ~w~n', [ToEmail]),
    format(user_error, '  link: ~w~n', [VerifyUrl]),
    format(user_error, '==============================================================~n~n', []).

log_resend_error(Error) :-
    format(user_error, '[mail:resend] erro: ~q~n', [Error]).
