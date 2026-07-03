:- module(agents_repo, [
    save_agent/6,
    get_agent/2,
    list_agents/1,
    list_agents_page/4,
    list_agents_by_owner/2,
    list_agents_by_owner_page/5,
    delete_agent/1,
    update_agent_source/2
]).

:- use_module(repo).

% Repositorio do recurso "agente": todo o acesso ao banco da tabela `agents`.
% Escrito sobre o toolkit repo.pl, entao cada consulta e curta e adicionar uma
% nova e so seguir o mesmo formato (SQL + lista de campos). Reexportado por
% db.pl.

% Colunas completas (inclui source_text) -> usado para materializar o cache.
agent_full_fields([
    id-int, owner_user_id-int, name-text, role-text,
    source_text-text, is_private-bool, deleted_at-optional, created_at-text
]).

% Metadados leves (sem source_text), para listagens.
agent_list_fields([
    id-int, owner_user_id-int, name-text, role-text, created_at-text, is_private-bool
]).

%!  save_agent(+OwnerUserId, +Name, +Role, +SourceText, +IsPrivate, -AgentId) is det.
save_agent(OwnerUserId, Name, Role, SourceText, IsPrivate, AgentId) :-
    repo:now_iso(CreatedAt),
    repo:int_of_bool(IsPrivate, PrivateInt),
    repo:lit(OwnerUserId, QOwner),
    repo:quote(Name, QName),
    repo:quote(Role, QRole),
    repo:quote(SourceText, QSource),
    repo:quote(CreatedAt, QCreated),
    format(string(SQL),
        "INSERT INTO agents(owner_user_id, name, role, source_text, is_private, deleted_at, created_at) VALUES(~s, ~s, ~s, ~s, ~w, NULL, ~s);",
        [QOwner, QName, QRole, QSource, PrivateInt, QCreated]),
    repo:insert(SQL, AgentId).

%!  get_agent(+AgentId, -Agent) is semidet.
get_agent(AgentId, Agent) :-
    repo:lit(AgentId, QId),
    format(string(SQL),
        "SELECT id, owner_user_id, name, role, source_text, is_private, deleted_at, created_at FROM agents WHERE id = ~s LIMIT 1;",
        [QId]),
    agent_full_fields(Fields),
    repo:get_one(SQL, Fields, Agent).

%!  list_agents(-Agents) is det.   (ordem decrescente de criacao)
list_agents(Agents) :-
    agent_list_fields(Fields),
    repo:get_all(
        "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents WHERE deleted_at IS NULL ORDER BY created_at DESC;",
        Fields, Agents).

%!  list_agents_page(+RequestedPage, +PerPage, -Agents, -Pagination) is det.
list_agents_page(RequestedPage, PerPage, Agents, Pagination) :-
    repo:count_rows("agents", "WHERE deleted_at IS NULL", TotalItems),
    repo:paginate(RequestedPage, PerPage, TotalItems, Pagination),
    Offset is (Pagination.page - 1) * PerPage,
    format(string(SQL),
        "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents WHERE deleted_at IS NULL ORDER BY id ASC LIMIT ~w OFFSET ~w;",
        [PerPage, Offset]),
    agent_list_fields(Fields),
    repo:get_all(SQL, Fields, Agents).

%!  list_agents_by_owner_page(+OwnerId, +RequestedPage, +PerPage, -Agents, -Pagination) is det.
%
%   Como list_agents_page/4, mas escopado aos agentes ativos de um dono (WHERE +
%   LIMIT/OFFSET), sem carregar a tabela inteira.
list_agents_by_owner_page(OwnerId, RequestedPage, PerPage, Agents, Pagination) :-
    repo:lit(OwnerId, QOwner),
    format(string(Where),
        "WHERE owner_user_id = ~s AND deleted_at IS NULL", [QOwner]),
    repo:count_rows("agents", Where, TotalItems),
    repo:paginate(RequestedPage, PerPage, TotalItems, Pagination),
    Offset is (Pagination.page - 1) * PerPage,
    format(string(SQL),
        "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents ~w ORDER BY id ASC LIMIT ~w OFFSET ~w;",
        [Where, PerPage, Offset]),
    agent_list_fields(Fields),
    repo:get_all(SQL, Fields, Agents).

%!  list_agents_by_owner(+OwnerId, -Agents) is det.
%
%   Todos os agentes ativos de um dono (sem paginacao). Usado pelo perfil da API,
%   que lista o retrospecto de todos eles.
list_agents_by_owner(OwnerId, Agents) :-
    repo:lit(OwnerId, QOwner),
    format(string(SQL),
        "SELECT id, owner_user_id, name, role, created_at, is_private FROM agents WHERE owner_user_id = ~s AND deleted_at IS NULL ORDER BY id ASC;",
        [QOwner]),
    agent_list_fields(Fields),
    repo:get_all(SQL, Fields, Agents).

%!  delete_agent(+AgentId) is det.   (soft delete)
delete_agent(AgentId) :-
    repo:lit(AgentId, QId),
    repo:now_iso(Now),
    repo:quote(Now, QNow),
    format(string(SQL),
        "UPDATE agents SET deleted_at = ~s WHERE id = ~s AND deleted_at IS NULL;",
        [QNow, QId]),
    repo:exec(SQL).

%!  update_agent_source(+AgentId, +SourceText) is det.
update_agent_source(AgentId, SourceText) :-
    repo:lit(AgentId, QId),
    repo:quote(SourceText, QSource),
    format(string(SQL),
        "UPDATE agents SET source_text = ~s WHERE id = ~s;",
        [QSource, QId]),
    repo:exec(SQL).
