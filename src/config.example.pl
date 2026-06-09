:- module(config, [
    http_port/1,
    app_base_url/1,
    trust_proxy/1,
    db_path/1,
    agent_cache_dir/1,
    agent_max_source_bytes/1,
    engine_scenario/1,
    engine_disguises/1,
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
app_base_url("http://localhost:8080").

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

% Cenario carregado pela engine (nome do arquivo em src/engine, sem extensao).
engine_scenario(mapa1).

% Quantidade de disfarces disponiveis ao ladrao.
engine_disguises(3).

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
