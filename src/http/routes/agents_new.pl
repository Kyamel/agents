:- module(route_agents_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../engine/registry').
:- use_module('../../components/page').
:- use_module('../../components/alert').
:- use_module('../../components/form_field').
:- use_module('../../components/page_section').
:- use_module('../security/web_session').

:- http_handler(root(agents/new), handler, [methods([get, post])]).

% =============================
% Handler
% =============================

handler(Request) :-
    memberchk(method(Method), Request),
    web_session:require_user(Request, User),
    dispatch(Method, Request, User).

dispatch(get, Request, User) :-
    render_form(Request, User, _{}).
dispatch(post, Request, User) :-
    http_parameters(Request, [
        name(Name, [default(""), string]),
        role(Role, [default(""), string]),
        source(Source, [default(""), string])
    ]),
    Values = _{name: Name, role: Role, source: Source},
    process_post(Request, User, Values).

% =============================
% Logica (validacao + DB)
% =============================

process_post(Request, User, Values) :-
    User.is_verified \== true,
    !,
    render_form(Request, User, Values).
process_post(Request, User, Values) :-
    \+ fields_filled([Values.name, Values.role, Values.source]),
    !,
    render_form(Request, User,
        Values.put(error, "Preencha todos os campos do formulario.")).
process_post(Request, User, Values) :-
    \+ agent_registry:valid_agent_name(Values.name),
    !,
    render_form(Request, User,
        Values.put(error, "Nome invalido: use apenas minusculas, numeros e \c
                           hifens, com no maximo 60 caracteres \c
                           (ex.: meu-agente).")).
process_post(Request, User, Values) :-
    to_id_string(User.id, UserId),
    try_register(UserId, Values, Result),
    finish_register(Result, Request, User, Values).

finish_register(ok, Request, _, _) :-
    http_redirect(see_other, '/agents', Request).
finish_register(error(Message), Request, User, Values) :-
    render_form(Request, User, Values.put(error, Message)).

fields_filled([]).
fields_filled([V|Vs]) :- string(V), V \== "", fields_filled(Vs).

to_id_string(Id, Id) :- string(Id), !.
to_id_string(Id, Str) :- atom(Id), !, atom_string(Id, Str).
to_id_string(Id, Str) :- term_string(Id, Str).

try_register(UserId, V, Result) :-
    catch(register_or_fail(UserId, V, Result),
          Error,
          register_error(Error, Result)).

register_or_fail(UserId, V, ok) :-
    agent_registry:register_agent_source(UserId, V.name, V.role, V.source, _),
    !.
register_or_fail(_, _,
    error("Nao foi possivel registrar o agente \c
           (codigo muito grande ou invalido).")).

register_error(error(permission_error(load, agent_source, Pattern), _), error(Message)) :-
    !,
    format(string(Message),
           "Codigo bloqueado pela validacao de seguranca: padrao proibido '~w'.",
           [Pattern]).
register_error(error(domain_error(role, _), _),
               error("Papel invalido. Escolha ladrao ou detetive.")) :- !.
register_error(error(type_error(_, _), _),
               error("Campos invalidos no formulario.")) :- !.
register_error(_, error("Erro inesperado ao registrar o agente.")).

% =============================
% Resposta (HTML)
% =============================

render_form(Request, User, _State) :-
    User.is_verified \== true,
    !,
    alert:alert(info,
        "Seu email ainda nao foi verificado. Verifique sua conta para enviar agentes.",
        Notice),
    page:reply_page(Request, 'Enviar agente', [
        h1([class('text-2xl font-bold mb-4')], 'Enviar agente'),
        Notice
    ]).
render_form(Request, _User, State) :-
    error_alert(State, AlertHtml),
    state_value(State, name, Name),
    state_value(State, source, Source),
    page_section:page_heading(
        'Enviar agente',
        'Ladrao deve exportar ladrao_action/3 e ladrao_preload/7. Detetive deve exportar detetive_action/3 e detetive_preload/5.',
        Heading
    ),
    form_field:slug_field(name, 'Nome do agente', Name, [maxlength(60)], NameField),
    form_field:select_field(role, 'Papel',
        [opt("thief", 'Ladrao'), opt("detective", 'Detetive')], RoleField),
    form_field:textarea_field(source, 'Codigo Prolog', Source, SourceField),
    form_field:submit_button('Enviar agente', Submit),
    page:reply_page(Request, 'Enviar agente', [
        Heading,
        AlertHtml,
        form([method(post), action('/agents/new'), class('max-w-lg')], [
            NameField, RoleField, SourceField, Submit
        ])
    ]).

error_alert(State, Html) :-
    get_dict(error, State, Message),
    !,
    alert:alert(error, Message, Html).
error_alert(_, '').

state_value(State, Key, Value) :-
    get_dict(Key, State, Value),
    !.
state_value(_, _, "").
