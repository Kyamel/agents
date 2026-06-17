:- module(route_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../components/page').
:- use_module('../../components/form_field').
:- use_module('../../components/alert').
:- use_module('../../components/ui').
:- use_module('../../auth/auth').
:- use_module('../security/rate_limit').

:- http_handler(root(signup), handler, [methods([get, post])]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(method(Method), Request),
    dispatch(Method, Request).

dispatch(get, Request) :-
    render_form(Request, "", "", '').
dispatch(post, Request) :-
    rate_limit:enforce_ip_rate_limit(Request),
    http_parameters(Request, [
        username(Username, [default(""), string]),
        email(Email, [default(""), string]),
        password(Password, [default(""), string]),
        confirm_password(ConfirmPassword, [default(""), string])
    ]),
    process_signup(Request, Username, Email, Password, ConfirmPassword).

% =============================
% Logica (validacao, calculo, DB)
% =============================

process_signup(Request, "", Email, _, _) :- !,
    render_error(Request, "", Email, "Informe seu nome de usuario.").
process_signup(Request, Username, "", _, _) :- !,
    render_error(Request, Username, "", "Informe email e senha.").
process_signup(Request, Username, Email, "", _) :- !,
    render_error(Request, Username, Email, "Informe email e senha.").
process_signup(Request, Username, Email, _, "") :- !,
    render_error(Request, Username, Email, "Confirme sua senha.").
process_signup(Request, Username, Email, Password, ConfirmPassword) :-
    Password \== ConfirmPassword,
    !,
    render_error(Request, Username, Email, "As senhas nao conferem.").
process_signup(Request, Username, Email, Password, _) :-
    string_length(Password, Length),
    Length < 6,
    !,
    render_error(Request, Username, Email, "A senha deve ter ao menos 6 caracteres.").
process_signup(Request, Username, Email, Password, _) :-
    safe_signup(Username, Email, Password, Outcome),
    handle_outcome(Outcome, Request, Username, Email).

safe_signup(Username, Email, Password, Outcome) :-
    catch(auth:signup(Username, Email, Password, Outcome),
          Error,
          log_and_fail(Email, Error, Outcome)).

log_and_fail(Email, Error, failed) :-
    format(user_error,
           '[signup] erro inesperado para ~w: ~q~n',
           [Email, Error]).

handle_outcome(created(_, _), Request, _, _) :-
    http_redirect(see_other, '/login?notice=signup_ok', Request).
handle_outcome(email_exists, Request, Username, Email) :-
    render_error(Request, Username, Email, "Esse email ja esta cadastrado.").
handle_outcome(failed, Request, Username, Email) :-
    render_error(Request, Username, Email,
        "Nao foi possivel concluir o cadastro. Tente novamente.").

% =============================
% Resposta (HTML)
% =============================

render_error(Request, Username, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_form(Request, Username, Email, AlertHtml).

render_form(Request, Username, Email, AlertHtml) :-
    form_field:text_field(username, 'Nome de usuario', text, Username, UsernameField),
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:text_field(confirm_password, 'Confirmar senha', password, "", ConfirmPasswordField),
    form_field:submit_button('Criar conta', Submit),
    ui:link_class(FooterClass),
    FooterLink = a([href('/login'), class(FooterClass)],
                   'Entrar'),
    page:reply_page(Request, 'Criar conta', [
        div([class('max-w-sm mx-auto')], [
            h1([class('text-2xl font-bold mb-1')], 'Criar conta'),
            p([class('text-surface-400 text-sm mb-6')],
              'Cadastre-se para enviar agentes e criar partidas.'),
            AlertHtml,
            form([method(post), action('/signup')], [
                UsernameField, EmailField, PasswordField, ConfirmPasswordField, Submit
            ]),
            p([class('text-surface-400 text-sm mt-4')], [
                'Ja tem conta? ',
                FooterLink
            ])
        ])
    ]).
