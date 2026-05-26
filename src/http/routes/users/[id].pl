:- module(route_users_show, [
    render/2
]).

:- use_module(library(http/html_write)).
:- use_module('../../../db/sqlite_store').
:- use_module('../../../components/layout/page').
:- use_module('../../../components/ui/alert').

%!  render(+Request, +UserId) is det.
%
%   Stub do perfil de usuario. A versao completa (lista de agentes do dono
%   + stats W/L/D por agente) sera implementada no proximo batch.
render(Request, UserId) :-
    (   sqlite_store:find_user_by_id(UserId, User)
    ->  render_stub(Request, User)
    ;   render_not_found(Request)
    ).

render_stub(Request, User) :-
    alert:alert(info,
        "Perfil completo (agentes enviados, vitorias/derrotas/empates) chega no proximo batch.",
        Notice),
    page:reply_page(Request, 'Perfil', [
        a([href('/agents'), class('text-sm text-ufop-400 hover:underline')],
          'Voltar para agentes'),
        h1([class('text-2xl font-bold mt-3 mb-1')], User.email),
        p([class('font-mono text-xs text-slate-500 mb-5 break-all')], User.id),
        Notice
    ]).

render_not_found(Request) :-
    page:reply_page(Request, 'Usuario nao encontrado', [
        h1([class('text-2xl font-bold mb-2')], 'Usuario nao encontrado'),
        a([href('/agents'), class('text-ufop-400 hover:underline')],
          'Voltar para agentes')
    ]).
