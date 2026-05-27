:- module(route_login, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/form_field').
:- use_module('../../components/ui/alert').
:- use_module('../controller/auth_orchestrator').
:- use_module('../security/web_session').
:- use_module('../security/rate_limit').

:- http_handler(root(login), handler, [methods([get, post])]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(method(Method), Request),
    dispatch(Method, Request).

dispatch(get, Request) :-
    http_parameters(Request, [notice(Notice, [default(""), string])]),
    notice_alert(Notice, AlertHtml),
    render_form(Request, "", AlertHtml).
dispatch(post, Request) :-
    rate_limit:enforce_ip_rate_limit(Request),
    http_parameters(Request, [
        email(Email, [default(""), string]),
        password(Password, [default(""), string])
    ]),
    process_login(Request, Email, Password).

% =============================
% Logica (validacao, calculo, DB)
% =============================

process_login(Request, Email, Password) :-
    (   ( Email == "" ; Password == "" )
    ->  render_error(Request, Email, "Informe email e senha.")
    ;   catch(auth_orchestrator:login(Email, Password, Outcome), _, Outcome = failed),
        handle_outcome(Outcome, Request, Email)
    ).

handle_outcome(ok(Token, _UserId, _ExpiresAt), _Request, _Email) :-
    web_session:send_session_redirect(Token, '/').
handle_outcome(invalid_credentials, Request, Email) :-
    render_error(Request, Email, "Email ou senha invalidos.").
handle_outcome(email_not_verified, Request, Email) :-
    render_error(Request, Email,
        "Seu email ainda nao foi verificado. Confira sua caixa de entrada.").
handle_outcome(failed, Request, Email) :-
    render_error(Request, Email, "Nao foi possivel entrar. Tente novamente.").

notice_alert("signup_ok", Html) :-
    !,
    alert:alert(success,
        "Conta criada. Verifique seu email para ativar o cadastro e depois faca login.",
        Html).
notice_alert("login_required", Html) :-
    !,
    alert:alert(info, "Faca login para acessar essa pagina.", Html).
notice_alert("logged_out", Html) :-
    !,
    alert:alert(info, "Voce saiu da sua conta.", Html).
notice_alert(_, '').

% =============================
% Resposta (HTML)
% =============================

render_error(Request, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_form(Request, Email, AlertHtml).

render_form(Request, Email, AlertHtml) :-
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:submit_button('Entrar', Submit),
    FooterLink = a([href('/signup'), class('text-ufop-400 hover:underline')],
                   'Criar conta'),
    page:reply_page(Request, 'Entrar', [
        div([class('max-w-sm mx-auto')], [
            h1([class('text-2xl font-bold mb-1')], 'Entrar'),
            p([class('text-slate-400 text-sm mb-6')],
              'Acesse sua conta para enviar agentes e criar partidas.'),
            AlertHtml,
            form([method(post), action('/login')], [
                EmailField, PasswordField, Submit
            ]),
            p([class('text-slate-400 text-sm mt-4')], [
                'Nao tem conta? ',
                FooterLink
            ])
        ])
    ]).
