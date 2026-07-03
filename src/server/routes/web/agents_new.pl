:- module(route_agents_new, []).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../engine/engine').
:- use_module('../../views/page').
:- use_module('../../views/alert').
:- use_module('../../views/form_field').
:- use_module('../../views/page_section').
:- use_module('../../views/ui').
:- use_module('../../http/web_session').

:- http_handler(root(agents/new), handler, [methods([get, post])]).

handler(Request) :-
    memberchk(method(Method), Request),
    web_session:require_user(Request, User),
    dispatch(Method, Request, User).

dispatch(get, Request, User) :-
    render_form(Request, User, _{}).
dispatch(post, Request, User) :-
    http_parameters(Request, [
        source(Source, [default(""), string]),
        private(PrivateRaw, [default("false"), string])
    ]),
    checkbox_bool(PrivateRaw, IsPrivate),
    Values = _{source: Source, private: IsPrivate},
    process_post(Request, User, Values).

process_post(Request, User, Values) :-
    User.is_verified \== true,
    !,
    render_form(Request, User, Values).
process_post(Request, User, Values) :-
    \+ fields_filled([Values.source]),
    !,
    render_form(Request, User,
        Values.put(error, "Cole o código Prolog do agente.")).
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
    engine:register_agent_source_from_module(UserId, V.source, V.private, _),
    !.
register_or_fail(_, _,
    error("Não foi possível registrar o agente \c
           (código muito grande ou inválido).")).

register_error(error(permission_error(load, agent_source, Pattern), _), error(Message)) :-
    !,
    format(string(Message),
           "Código bloqueado pela validação de segurança: padrão proibido '~w'.",
           [Pattern]).
register_error(error(domain_error(agent_role_exports, _), _),
               error("Não foi possível identificar o papel pelo código. \c
                      Ladrão deve exportar ladrao_action/3 e ladrao_preload/7; \c
                      detetive deve exportar detetive_action/3 e detetive_preload/5.")) :- !.
register_error(error(domain_error(agent_module_directive, _), _),
               error("O código deve começar com uma diretiva :- module(Nome, Exports).")) :- !.
register_error(error(domain_error(agent_name, _), _),
               error("Nome de módulo inválido. Use um átomo Prolog com 3 à 60 caracteres, sem / ou \\.")) :- !.
register_error(error(type_error(_, _), _),
               error("Campos inválidos no formulário.")) :- !.
register_error(error(syntax_error(_), _),
               error("Não foi possível ler a diretiva module/2 do código Prolog.")) :- !.
register_error(_, error("Erro inesperado ao registrar o agente.")).

checkbox_bool("true", true) :- !.
checkbox_bool("on", true) :- !.
checkbox_bool(_, false).

% Resposta (HTML)
render_form(Request, User, _State) :-
    User.is_verified \== true,
    !,
    alert:alert(info,
        "Seu email ainda não foi verificado. Verifique sua conta para enviar agentes.",
        Notice),
    page:reply_page(Request, 'Enviar agente', [
        h1([class('text-2xl font-bold mb-4')], 'Enviar agente'),
        Notice
    ]).
render_form(Request, _User, State) :-
    error_alert(State, AlertHtml),
    state_value(State, source, Source),
    state_bool(State, private, IsPrivate),
    ui:link_class(LinkClass),
    page_section:page_heading(
        'Enviar agente',
        [
            'O papel é detectado pelo código: ladrão exporta ladrao_action/3 e \c
             ladrao_preload/7; detetive exporta detetive_action/3 e \c
             detetive_preload/5. ',
            a([href('/about/#programar-agente'), class(LinkClass)],
              'Veja como programar seu agente.')
        ],
        Heading
    ),
    form_field:textarea_field(source, 'Código Prolog', Source, SourceField),
    form_field:checkbox_field(private,
        'Manter código privado',
        'Quando marcado, a API pública mostra apenas os metadados do agente.',
        IsPrivate,
        PrivateField),
    form_field:submit_button('Enviar agente', Submit),
    page:reply_page(Request, 'Enviar agente', [
        Heading,
        AlertHtml,
        form([method(post), action('/agents/new'), class('max-w-lg')], [
            SourceField, PrivateField, Submit
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

state_bool(State, Key, Value) :-
    get_dict(Key, State, Value),
    !.
state_bool(_, _, false).
