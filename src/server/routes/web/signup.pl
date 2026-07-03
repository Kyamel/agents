:- module(route_signup, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../views/page').
:- use_module('../../views/form_field').
:- use_module('../../views/alert').
:- use_module('../../views/ui').
:- use_module('../../../services/accounts').
:- use_module('../../http/rate_limit').

:- http_handler(root(signup), handler, [methods([get, post])]).

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

process_signup(Request, "", Email, _, _) :- !,
    render_error(Request, "", Email, "Informe seu nome de usuário.").
process_signup(Request, Username, "", _, _) :- !,
    render_error(Request, Username, "", "Informe email e senha.").
process_signup(Request, Username, Email, "", _) :- !,
    render_error(Request, Username, Email, "Informe email e senha.").
process_signup(Request, Username, Email, _, "") :- !,
    render_error(Request, Username, Email, "Confirme sua senha.").
process_signup(Request, Username, Email, Password, ConfirmPassword) :-
    Password \== ConfirmPassword,
    !,
    render_error(Request, Username, Email, "As senhas não conferem.").
process_signup(Request, Username, Email, Password, _) :-
    string_length(Password, Length),
    Length < 6,
    !,
    render_error(Request, Username, Email, "A senha deve ter ao menos 6 caracteres.").
process_signup(Request, Username, Email, Password, _) :-
    safe_signup(Username, Email, Password, Outcome),
    handle_outcome(Outcome, Request, Username, Email).

safe_signup(Username, Email, Password, Outcome) :-
    catch(accounts:signup(Username, Email, Password, Outcome),
          Error,
          log_and_fail(Email, Error, Outcome)).

log_and_fail(Email, Error, failed) :-
    format(user_error,
           '[signup] erro inesperado para ~w: ~q~n',
           [Email, Error]).

handle_outcome(created(_, _), Request, _, _) :-
    http_redirect(see_other, '/login?notice=signup_ok', Request).
handle_outcome(invalid_username, Request, Username, Email) :-
    render_error(Request, Username, Email,
        "O nome de usuário deve ter entre 3 e 60 caracteres e usar apenas \c
         letras, números, espaços, _, - ou .").
handle_outcome(email_exists, Request, Username, Email) :-
    render_error(Request, Username, Email, "Esse email já está cadastrado.").
handle_outcome(failed, Request, Username, Email) :-
    render_error(Request, Username, Email,
        "Não foi possível concluir o cadastro. Tente novamente.").

% Resposta (HTML)
render_error(Request, Username, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_form(Request, Username, Email, AlertHtml).

render_form(Request, Username, Email, AlertHtml) :-
    form_field:text_field(
        username,
        'Nome de usuário',
        text,
        Username,
        [minlength(3), maxlength(60)],
        UsernameField
    ),
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:text_field(confirm_password, 'Confirmar senha', password, "", ConfirmPasswordField),
    form_field:submit_button('Criar conta', Submit),
    ui:link_class(FooterClass),
    ui:text_class(page_title, 'mb-1', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-6', DescriptionClass),
    ui:text_class(normal, 'text-surface-400 mt-4', FooterTextClass),
    FooterLink = a([href('/login'), class(FooterClass)],
                   'Entrar'),
    page:reply_page(Request, 'Criar conta', [
        div([class('max-w-sm mx-auto')], [
            h1([class(TitleClass)], 'Criar conta'),
            p([class(DescriptionClass)],
              'Cadastre-se para enviar agentes e criar partidas.'),
            AlertHtml,
            form([method(post), action('/signup')], [
                UsernameField, EmailField, PasswordField, ConfirmPasswordField, Submit
            ]),
            p([class(FooterTextClass)], [
                'Já tem conta? ',
                FooterLink
            ])
        ])
    ]).
