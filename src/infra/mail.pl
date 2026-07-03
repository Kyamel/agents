:- module(mail, [
    send_email/4
]).

:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module('../config').

% Servico de email generico (infra): so sabe ENTREGAR um email para o transporte
% configurado em config:mail_transport/1. (ver emails/*.pl).

%!  send_email(+To, +Subject, +Html, -Status) is det.
%
%   Status: sent (Resend OK) | console (impresso no terminal, dev) | failed.
send_email(To, Subject, Html, Status) :-
    config:mail_transport(Transport),
    deliver(Transport, To, Subject, Html, Status).

deliver(console, To, Subject, Html, console) :-
    print_console(To, Subject, Html).
deliver(resend, To, Subject, Html, sent) :-
    catch(resend_send(To, Subject, Html, _Resp),
          Error,
          ( log_resend_error(Error), fail )),
    !.
deliver(resend, _To, _Subject, _Html, failed).
deliver(Other, To, Subject, Html, console) :-
    format(user_error,
           '[mail] transporte desconhecido "~w"; caindNao conhece nenhum email especifico;
% o conteudo vem pronto de quem chamao para console~n', [Other]),
    print_console(To, Subject, Html).

resend_send(To, Subject, Html, Response) :-
    config:resend_api_key(ApiKey),
    config:resend_from(From),
    Payload = _{ from: From, to: [To], subject: Subject, html: Html },
    format(string(AuthHeader), 'Bearer ~s', [ApiKey]),
    http_post('https://api.resend.com/emails',
              json(Payload),
              Response,
              [ request_header('Authorization'=AuthHeader),
                json_object(dict),
                timeout(10)
              ]).

print_console(To, Subject, Html) :-
    format(user_error, '~n', []),
    format(user_error, '==============================================================~n', []),
    format(user_error, '[mail:console] (dev mode)~n', []),
    format(user_error, '  para:    ~w~n', [To]),
    format(user_error, '  assunto: ~w~n', [Subject]),
    format(user_error, '  corpo:   ~w~n', [Html]),
    format(user_error, '==============================================================~n~n', []).

log_resend_error(Error) :-
    format(user_error, '[mail:resend] erro: ~q~n', [Error]).
