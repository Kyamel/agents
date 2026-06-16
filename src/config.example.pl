:- module(config, [
    http_port/1,
    app_base_url/1,
    trust_proxy/1,
    db_path/1,
    agent_cache_dir/1,
    agent_max_source_bytes/1,
    engine_scenario/1,
    scenario_dir/1,
    engine_disguises/1,
    match_max_workers/1,
    match_timeout_seconds/1,
    match_runs_dir/1,
    rate_limit_window_seconds/1,
    rate_limit_max/1,
    email_verify_ttl_minutes/1,
    auth_session_ttl_minutes/1,
    mail_transport/1,
    resend_api_key/1,
    resend_from/1
]).

% --- Servidor HTTP ---

% Porta em que o servidor escuta.
http_port(8080).

% URL base usada nos links enviados por email (verificacao de conta).
app_base_url(Url) :-
    http_port(Port),
    format(atom(Url), 'http://localhost:~w', [Port]).

% So habilite atras de um proxy reverso (Caddy/nginx) que define
% X-Forwarded-For; senao o cliente poderia forjar o proprio IP.
trust_proxy(false).

% --- Banco de dados e cache em disco ---

% Arquivo SQLite (criado se nao existir).
db_path("./data/agents.db").

% Diretorio onde o codigo dos agentes e materializado antes das partidas.
agent_cache_dir("./uploads/agents").

% --- Limites de agente ---

% Tamanho maximo do codigo-fonte de um agente, em bytes.
agent_max_source_bytes(65536).

% --- Engine de partidas ---

% Diretorio onde ficam os arquivos .prolog de cenario. Usado para listar os
% cenarios disponiveis ao criar uma partida. Relativo a raiz do projeto.
scenario_dir("./scenarios").

% Cenario padrao carregado pela engine: caminho do arquivo .prolog.
engine_scenario("./scenarios/mapa1.prolog").

% Quantidade de disfarces disponiveis ao ladrao.
engine_disguises(3).

% Tamanho do pool de execucao de partidas. Cada partida roda num subprocesso
% swipl proprio; este e o numero maximo rodando em paralelo. `auto` =
% max(1, cpu_count - 1), deixando um nucleo para o servidor.
match_max_workers(auto).

% Tempo maximo (segundos) de uma partida antes de ser interrompida. 21600 = 6h.
match_timeout_seconds(21600).

% Diretorio para os arquivos temporarios de resultado dos subprocessos.
match_runs_dir("./data/runs").

% --- Rate limit por IP ---

% Janela de contagem (segundos) e maximo de requisicoes por janela.
rate_limit_window_seconds(60).
rate_limit_max(120).

% --- Sessao e tokens (em minutos) ---

% Validade do link de verificacao de email.
email_verify_ttl_minutes(30).

% Validade da sessao de login (10080 = 7 dias).
auth_session_ttl_minutes(10080).

% --- Email ---

% Transporte de envio: `console` imprime o link no terminal (modo dev);
% `resend` envia de verdade pela API do Resend.
mail_transport(console).

resend_api_key("").
resend_from("Agents <no-reply@example.com>").
