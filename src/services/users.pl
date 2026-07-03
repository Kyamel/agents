:- module(users, [
    profile/2,
    profile_page/4,
    display_name/2
]).

:- use_module('../db/db').
:- use_module(library(apply)).

% Servico de usuario: monta o perfil com o retrospecto (vitorias/derrotas/
% empates) de cada agente e o global. As agregacoes rodam no banco (ver
% db/matches_repo: agent_record/owner_record), sem trazer as partidas para o
% Prolog. Devolve dados (outcome), sem HTML/JSON; web e api formatam.

%!  profile(+UserId, -Outcome) is det.
%
%   Todos os agentes do usuario com estatisticas (sem paginacao). Usado pela API.
%   Outcome: profile(User, AgentStats, GlobalStats) | not_found.
%     AgentStats  = lista de stat(Agent, _{wins, losses, draws})
profile(UserId, profile(User, AgentStats, GlobalStats)) :-
    db:find_user_by_id(UserId, User),
    !,
    db:list_agents_by_owner(User.id, Agents),
    maplist(agent_stat_pair, Agents, AgentStats),
    db:owner_record(User.id, GlobalStats).
profile(_, not_found).

%!  profile_page(+UserId, +Page, +PerPage, -Outcome) is det.
%
%   Como profile/2, mas a lista de agentes vem paginada do banco (LIMIT/OFFSET).
%   GlobalStats agrega TODOS os agentes do usuario, nao so os da pagina. Web.
%   Outcome: profile(User, AgentStats, GlobalStats, Pagination) | not_found.
profile_page(UserId, Page, PerPage,
             profile(User, AgentStats, GlobalStats, Pagination)) :-
    db:find_user_by_id(UserId, User),
    !,
    db:list_agents_by_owner_page(User.id, Page, PerPage, PageAgents, Pagination),
    maplist(agent_stat_pair, PageAgents, AgentStats),
    db:owner_record(User.id, GlobalStats).
profile_page(_, _, _, not_found).

agent_stat_pair(Agent, stat(Agent, Record)) :-
    db:agent_record(Agent.id, Record).

%!  display_name(+User, -Name) is det.
%
%   Nome seguro para exibicao publica. Contas atuais usam `username`; contas
%   antigas que salvaram o email nesse campo recebem apenas a parte antes de
%   `@`, sem expor o endereco completo.
display_name(User, Name) :-
    get_dict(username, User, RawUsername),
    text_value(RawUsername, Username),
    Username \== "",
    \+ sub_string(Username, _, _, _, "@"),
    !,
    Name = Username.
display_name(User, Name) :-
    get_dict(email, User, RawEmail),
    text_value(RawEmail, Email),
    split_string(Email, "@", "", [LocalPart|_]),
    LocalPart \== "",
    !,
    Name = LocalPart.
display_name(User, Name) :-
    format(string(Name), "Usuário ~w", [User.id]).

text_value(Value, Value) :- string(Value), !.
text_value(Value, Text) :- atom(Value), !, atom_string(Value, Text).
text_value(Value, Text) :- format(string(Text), "~w", [Value]).
