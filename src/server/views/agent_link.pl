:- module(agent_link, [
    agent_link/3,
    agent_link/4
]).

:- use_module(ui).

% Link canônico para o perfil público de um agente. O estilo vem da mesma
% receita usada pelos links de navegação do app; callers só acrescentam layout.
agent_link(Id, Name, Html) :-
    agent_link(Id, Name, '', Html).

agent_link(Id, Name, ExtraClass, Html) :-
    format(atom(Href), '/agents/~w', [Id]),
    ui:link_class(ExtraClass, Class),
    format(string(Title), "Ver perfil de ~w", [Name]),
    Html = a([
        href(Href),
        class(Class),
        title(Title)
    ], Name).
