:- module(route_auth_verify, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../views/page').
:- use_module('../../views/button_link').
:- use_module('../../views/ui').
:- use_module('../../../services/accounts').

:- http_handler(root(auth/verify), handler, [method(get)]).

handler(Request) :-
    catch(verify_from_request(Request, Status, Payload),
          _Error,
          invalid_result(Status, Payload)),
    render_result(Request, Status, Payload).

invalid_result(400, _{error: "invalid_or_expired_token"}).

verify_from_request(Request, 200, _{status: "verified", user_id: UserId}) :-
    http_parameters(Request, [token(Token, [string])]),
    accounts:verify_email_token(Token, verified(UserId)),
    !.
verify_from_request(_Request, 400, _{error: "invalid_or_expired_token"}).

render_result(Request, 200, Payload) :-
    !,
    button_link:button_link('/login', 'Entrar', LoginButton),
    ui:surface_class('p-6', CardClass),
    ui:text_class(meta, 'text-emerald-300 font-semibold mb-2', StatusClass),
    ui:text_class(title, 'mb-3', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-5', MessageClass),
    page:reply_page(Request, 'Email verificado', [
        section([class('max-w-lg mx-auto text-center py-10')], [
            div([class(CardClass)], [
                p([class(StatusClass)],
                  'Conta verificada'),
                h1([class(TitleClass)], 'Seu email foi confirmado'),
                p([class(MessageClass)],
                  ['A conta ', span([class('font-mono text-surface-300 break-all')], Payload.user_id),
                   ' já pode enviar agentes e criar partidas.']),
                LoginButton
            ])
        ])
    ]).
render_result(Request, _Status, _Payload) :-
    button_link:button_link('/signup', 'Criar conta', SignupButton),
    ui:surface_class('p-6', CardClass),
    ui:text_class(meta, 'text-rose-300 font-semibold mb-2', StatusClass),
    ui:text_class(title, 'mb-3', TitleClass),
    ui:text_class(normal, 'text-surface-400 mb-5', MessageClass),
    page:reply_page(Request, 'Verificação inválida', [
        section([class('max-w-lg mx-auto text-center py-10')], [
            div([class(CardClass)], [
                p([class(StatusClass)],
                  'Verificação indisponível'),
                h1([class(TitleClass)], 'Link inválido ou expirado'),
                p([class(MessageClass)],
                  'Esse link de verificação não existe, já foi usado ou expirou.'),
                SignupButton
            ])
        ])
    ]).
