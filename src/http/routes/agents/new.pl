:- module(route_agents_new, [
    render/2
]).

:- use_module(library(http/html_write)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_parameters)).
:- use_module('../../../engine/registry').
:- use_module('../../../components/layout/page').
:- use_module('../../../components/ui/alert').
:- use_module('../../../components/ui/form_field').
:- use_module('../../security/web_session').

%!  render(+Method, +Request) is det.
render(get, Request) :-
    web_session:require_user(Request, User),
    render_form(Request, User, _{}).
render(post, Request) :-
    web_session:require_user(Request, User),
    http_parameters(Request, [
        name(Name, [default(""), string]),
        role(Role, [default(""), string]),
        source(Source, [default(""), string])
    ]),
    Values = _{name: Name, role: Role, source: Source},
    (   User.is_verified \== true
    ->  render_form(Request, User, Values)
    ;   fields_filled([Name, Role, Source])
    ->  to_id_string(User.id, UserId),
        try_register(UserId, Values, Result),
        (   Result == ok
        ->  http_redirect(see_other, '/agents', Request)
        ;   Result = error(Message),
            render_form(Request, User, Values.put(error, Message))
        )
    ;   render_form(Request, User,
            Values.put(error, "Preencha todos os campos do formulario."))
    ).

fields_filled(Values) :-
    forall(member(V, Values), (string(V), V \== "")).

to_id_string(Id, Str) :-
    (   string(Id) -> Str = Id
    ;   atom(Id)   -> atom_string(Id, Str)
    ;   term_string(Id, Str)
    ).

try_register(UserId, V, Result) :-
    catch(
        (   agent_registry:register_agent_source(UserId, V.name, V.role,
                                                 V.source, _Agent)
        ->  Result = ok
        ;   Result = error("Nao foi possivel registrar o agente \c
                            (codigo muito grande ou invalido).")
        ),
        Error,
        ( register_error_message(Error, Message), Result = error(Message) )
    ).

register_error_message(error(permission_error(load, agent_source, Pattern), _), Message) :-
    !,
    format(string(Message),
           "Codigo bloqueado pela validacao de seguranca: padrao proibido '~w'.",
           [Pattern]).
register_error_message(error(domain_error(role, _), _), Message) :-
    !,
    Message = "Papel invalido. Escolha ladrao ou detetive.".
register_error_message(error(type_error(_, _), _), Message) :-
    !,
    Message = "Campos invalidos no formulario.".
register_error_message(_, "Erro inesperado ao registrar o agente.").

%!  render_form(+Request, +User, +State) is det.
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
    form_field:text_field(name, 'Nome do agente', text, Name, NameField),
    form_field:select_field(role, 'Papel',
        [opt("thief", 'Ladrao'), opt("detective", 'Detetive')], RoleField),
    form_field:textarea_field(source, 'Codigo Prolog', Source, SourceField),
    form_field:submit_button('Enviar agente', Submit),
    page:reply_page(Request, 'Enviar agente', [
        h1([class('text-2xl font-bold mb-1')], 'Enviar agente'),
        p([class('text-slate-400 text-sm mb-6')],
          'Ladrao deve exportar ladrao_action/3 e ladrao_preload/7. \c
           Detetive deve exportar detetive_action/3 e detetive_preload/5.'),
        AlertHtml,
        form([method(post), action('/agents/new'), class('max-w-lg')], [
            NameField, RoleField, SourceField, Submit
        ])
    ]).

error_alert(State, Html) :-
    (   get_dict(error, State, Message)
    ->  alert:alert(error, Message, Html)
    ;   Html = ''
    ).

state_value(State, Key, Value) :-
    (   get_dict(Key, State, Found) -> Value = Found ; Value = "" ).
