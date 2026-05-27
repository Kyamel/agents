:- module(route_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/form_field').
:- use_module('../../components/ui/alert').
:- use_module('../controller/auth_orchestrator').
:- use_module('../security/rate_limit').

:- http_handler(root(signup), handler, [methods([get, post])]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(method(Method), Request),
    dispatch(Method, Request).

dispatch(get, Request) :-
    render_form(Request, "", '').
dispatch(post, Request) :-
    rate_limit:enforce_ip_rate_limit(Request),
    http_parameters(Request, [
        email(Email, [default(""), string]),
        password(Password, [default(""), string])
    ]),
    process_signup(Request, Email, Password).

% =============================
% Logica (validacao, calculo, DB)
% =============================

process_signup(Request, Email, Password) :-
    (   ( Email == "" ; Password == "" )
    ->  render_error(Request, Email, "Informe email e senha.")
    ;   string_length(Password, Length), Length < 6
    ->  render_error(Request, Email, "A senha deve ter ao menos 6 caracteres.")
    ;   safe_signup(Email, Password, Outcome),
        handle_outcome(Outcome, Request, Email)
    ).

safe_signup(Email, Password, Outcome) :-
    catch(auth_orchestrator:signup(Email, Password, Outcome),
          Error,
          ( format(user_error,
                   '[signup] erro inesperado para ~w: ~q~n',
                   [Email, Error]),
            Outcome = failed )).

handle_outcome(created(_, _), Request, _) :-
    http_redirect(see_other, '/login?notice=signup_ok', Request).
handle_outcome(email_exists, Request, Email) :-
    render_error(Request, Email, "Esse email ja esta cadastrado.").
handle_outcome(failed, Request, Email) :-
    render_error(Request, Email,
        "Nao foi possivel concluir o cadastro. Tente novamente.").

% =============================
% Resposta (HTML)
% =============================

render_error(Request, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_form(Request, Email, AlertHtml).

render_form(Request, Email, AlertHtml) :-
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:submit_button('Criar conta', Submit),
    FooterLink = a([href('/login'), class('text-ufop-400 hover:underline')],
                   'Entrar'),
    page:reply_page(Request, 'Criar conta', [
        div([class('max-w-sm mx-auto')], [
            h1([class('text-2xl font-bold mb-1')], 'Criar conta'),
            p([class('text-slate-400 text-sm mb-6')],
              'Cadastre-se para enviar agentes e criar partidas.'),
            AlertHtml,
            form([method(post), action('/signup')], [
                EmailField, PasswordField, Submit
            ]),
            p([class('text-slate-400 text-sm mt-4')], [
                'Ja tem conta? ',
                FooterLink
            ])
        ])
    ]).
