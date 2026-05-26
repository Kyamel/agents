:- module(auth_pages, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/form_field').
:- use_module('../../components/ui/alert').
:- use_module('../controller/auth_orchestrator').
:- use_module('../security/web_session').
:- use_module('../security/rate_limit').

:- http_handler(root(signup), signup_router, [methods([get, post])]).
:- http_handler(root(login), login_router, [methods([get, post])]).
:- http_handler(root(logout), logout_handler, [method(post)]).

% -----------------------------
% Cadastro
% -----------------------------

%!  signup_router(+Request) is det.
%
%   Encaminha a pagina de cadastro conforme o metodo HTTP.
signup_router(Request) :-
    memberchk(method(Method), Request),
    signup_page(Method, Request).

%!  signup_page(+Method, +Request) is det.
%
%   GET renderiza o formulario; POST valida e cria a conta.
signup_page(get, Request) :-
    render_signup(Request, "", '').
signup_page(post, Request) :-
    rate_limit:enforce_ip_rate_limit(Request),
    http_parameters(Request, [
        email(Email, [default(""), string]),
        password(Password, [default(""), string])
    ]),
    (   ( Email == "" ; Password == "" )
    ->  signup_error(Request, Email, "Informe email e senha.")
    ;   string_length(Password, Length), Length < 6
    ->  signup_error(Request, Email, "A senha deve ter ao menos 6 caracteres.")
    ;   catch(auth_orchestrator:signup(Email, Password, Outcome),
              Error,
              ( format(user_error,
                       '[signup] erro inesperado para ~w: ~q~n',
                       [Email, Error]),
                Outcome = failed )),
        signup_result(Outcome, Request, Email)
    ).

%!  signup_result(+Outcome, +Request, +Email) is det.
%
%   Trata o resultado do cadastro: redireciona em sucesso ou re-renderiza.
signup_result(created(_, _), Request, _) :-
    http_redirect(see_other, '/login?notice=signup_ok', Request).
signup_result(email_exists, Request, Email) :-
    signup_error(Request, Email, "Esse email ja esta cadastrado.").
signup_result(failed, Request, Email) :-
    signup_error(Request, Email,
        "Nao foi possivel concluir o cadastro. Tente novamente.").

%!  signup_error(+Request, +Email, +Message) is det.
%
%   Re-renderiza o cadastro preservando o email e exibindo o erro.
signup_error(Request, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_signup(Request, Email, AlertHtml).

%!  render_signup(+Request, +Email, +AlertHtml) is det.
%
%   Renderiza a pagina de cadastro.
render_signup(Request, Email, AlertHtml) :-
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:submit_button('Criar conta', Submit),
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
                a([href('/login'), class('text-ufop-400 hover:underline')], 'Entrar')
            ])
        ])
    ]).

% -----------------------------
% Login
% -----------------------------

%!  login_router(+Request) is det.
%
%   Encaminha a pagina de login conforme o metodo HTTP.
login_router(Request) :-
    memberchk(method(Method), Request),
    login_page(Method, Request).

%!  login_page(+Method, +Request) is det.
%
%   GET renderiza o formulario; POST autentica e abre a sessao por cookie.
login_page(get, Request) :-
    http_parameters(Request, [notice(Notice, [default(""), string])]),
    notice_alert(Notice, AlertHtml),
    render_login(Request, "", AlertHtml).
login_page(post, Request) :-
    rate_limit:enforce_ip_rate_limit(Request),
    http_parameters(Request, [
        email(Email, [default(""), string]),
        password(Password, [default(""), string])
    ]),
    (   ( Email == "" ; Password == "" )
    ->  login_error(Request, Email, "Informe email e senha.")
    ;   catch(auth_orchestrator:login(Email, Password, Outcome), _, Outcome = failed),
        login_result(Outcome, Request, Email)
    ).

%!  login_result(+Outcome, +Request, +Email) is det.
%
%   Trata o resultado do login: grava o cookie de sessao ou re-renderiza.
login_result(ok(Token, _UserId, _ExpiresAt), _Request, _Email) :-
    web_session:send_session_redirect(Token, '/').
login_result(invalid_credentials, Request, Email) :-
    login_error(Request, Email, "Email ou senha invalidos.").
login_result(email_not_verified, Request, Email) :-
    login_error(Request, Email,
        "Seu email ainda nao foi verificado. Confira sua caixa de entrada.").
login_result(failed, Request, Email) :-
    login_error(Request, Email, "Nao foi possivel entrar. Tente novamente.").

%!  login_error(+Request, +Email, +Message) is det.
%
%   Re-renderiza o login preservando o email e exibindo o erro.
login_error(Request, Email, Message) :-
    alert:alert(error, Message, AlertHtml),
    render_login(Request, Email, AlertHtml).

%!  render_login(+Request, +Email, +AlertHtml) is det.
%
%   Renderiza a pagina de login.
render_login(Request, Email, AlertHtml) :-
    form_field:text_field(email, 'Email', email, Email, EmailField),
    form_field:text_field(password, 'Senha', password, "", PasswordField),
    form_field:submit_button('Entrar', Submit),
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
                a([href('/signup'), class('text-ufop-400 hover:underline')], 'Criar conta')
            ])
        ])
    ]).

%!  notice_alert(+Notice, -Html) is det.
%
%   Traduz o parametro `notice` da query string em um aviso, se houver.
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

% -----------------------------
% Logout
% -----------------------------

%!  logout_handler(+Request) is det.
%
%   Revoga a sessao atual, apaga o cookie e redireciona para o login.
logout_handler(Request) :-
    web_session:revoke_web_session(Request),
    web_session:send_logout_redirect('/login?notice=logged_out').
