:- module(route_users_show, []).

:- use_module(library(http/http_dispatch)).
:- use_module(library(http/html_write)).
:- use_module('../../db/sqlite_store').
:- use_module('../../components/layout/page').
:- use_module('../../components/ui/alert').

% Prefix em /users/ para capturar /users/<id>. Nao existe /users (lista).
:- http_handler('/users/', handler, [method(get), prefix]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(path(Path), Request),
    extract_id(Path, Id),
    !,
    load_and_render(Request, Id).
handler(Request) :-
    render_not_found(Request).

extract_id(Path, Id) :-
    atom_concat('/users/', Id, Path),
    Id \== ''.

% =============================
% Logica (DB)
% =============================

load_and_render(Request, Id) :-
    (   sqlite_store:find_user_by_id(Id, User)
    ->  render_stub(Request, User)
    ;   render_not_found(Request)
    ).

% =============================
% Resposta (HTML)
% =============================

% Stub do perfil. Lista de agentes do dono + W/L/D fica para o proximo batch.
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
