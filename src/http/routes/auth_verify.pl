:- module(route_auth_verify, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../components/page').
:- use_module('../../components/button_link').
:- use_module('../../components/ui').
:- use_module('../../auth/auth').

:- http_handler(root(auth/verify), handler, [method(get)]).

handler(Request) :-
    catch(verify_from_request(Request, Status, Payload),
          _Error,
          invalid_result(Status, Payload)),
    render_result(Request, Status, Payload).

invalid_result(400, _{error: "invalid_or_expired_token"}).

verify_from_request(Request, 200, _{status: "verified", user_id: UserId}) :-
    http_parameters(Request, [token(Token, [string])]),
    auth:verify_email_token(Token, verified(UserId)),
    !.
verify_from_request(_Request, 400, _{error: "invalid_or_expired_token"}).

render_result(Request, 200, Payload) :-
    !,
    button_link:button_link('/login', 'Entrar', LoginButton),
    ui:surface_class('p-6', CardClass),
    page:reply_page(Request, 'Email verificado', [
        section([class('max-w-lg mx-auto text-center py-10')], [
            div([class(CardClass)], [
                p([class('text-emerald-300 text-sm font-semibold mb-2')],
                  'Conta verificada'),
                h1([class('text-2xl font-bold mb-3')], 'Seu email foi confirmado'),
                p([class('text-surface-400 text-sm mb-5')],
                  ['A conta ', span([class('font-mono text-surface-300 break-all')], Payload.user_id),
                   ' já pode enviar agentes e criar partidas.']),
                LoginButton
            ])
        ])
    ]).
render_result(Request, _Status, _Payload) :-
    button_link:button_link('/signup', 'Criar conta', SignupButton),
    ui:surface_class('p-6', CardClass),
    page:reply_page(Request, 'Verificacao invalida', [
        section([class('max-w-lg mx-auto text-center py-10')], [
            div([class(CardClass)], [
                p([class('text-red-300 text-sm font-semibold mb-2')],
                  'Verificacao indisponivel'),
                h1([class('text-2xl font-bold mb-3')], 'Link inválido ou expirado'),
                p([class('text-surface-400 text-sm mb-5')],
                  'Esse link de verificacão não existe, já foi usado ou expirou.'),
                SignupButton
            ])
        ])
    ]).
