% =========================================================
%  METRO 3^3
%
%  27 cidades
%  3-dimensional ternary metro grid
%  Gerado por tools/generate_metro_scenarios.py
% =========================================================

:- dynamic item/3.
:- dynamic tesouro/3.
:- dynamic roubado/2.

max_turnos(255).

% =========================================================
% SUSPEITOS
% =========================================================

procurado(0,'Ariadne Vale',
    aparencia([
        altura(alta),
        genero(gen2),
        cor_olhos(verde),
        cor_cabelo(preto),
        marca(cicatriz_rosto),
        passo(rapido)
    ])).

procurado(1,'Bruno Knox',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(castanho),
        cor_cabelo(loiro),
        nariz(longo),
        passo(lento)
    ])).

procurado(2,'Celia Flux',
    aparencia([
        altura(baixa),
        genero(gen2),
        cor_olhos(azul),
        cor_cabelo(ruivo),
        tatuagem(braco),
        mochila(cinza)
    ])).

procurado(3,'Dario Pike',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(escuro),
        cor_cabelo(preto),
        barba,
        casaco(azul)
    ])).

procurado(4,'Elena Mist',
    aparencia([
        altura(media),
        genero(gen2),
        cor_olhos(verde),
        cor_cabelo(castanho),
        piercing(nariz),
        luvas(pretas)
    ])).

procurado(5,'Felix Ward',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(azul),
        cor_cabelo(grisalho),
        marca(tatuagem_pescoco),
        mala(vermelha)
    ])).

procurado(6,'Gaia Stone',
    aparencia([
        altura(baixa),
        genero(gen2),
        cor_olhos(castanho),
        cor_cabelo(preto),
        oculos,
        cachecol(roxo)
    ])).

procurado(7,'Hugo Reed',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(verde),
        cor_cabelo(ruivo),
        nariz(curto),
        chapeu(preto)
    ])).

procurado(8,'Iris Frost',
    aparencia([
        altura(alta),
        genero(gen2),
        cor_olhos(azul),
        cor_cabelo(loiro),
        cicatriz(sobrancelha),
        casaco(branco)
    ])).

procurado(9,'Jonas Wolfe',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(escuro),
        cor_cabelo(castanho),
        atletico,
        mochila(preta)
    ])).

procurado(10,'Kira North',
    aparencia([
        altura(baixa),
        genero(gen2),
        cor_olhos(verde),
        cor_cabelo(loiro),
        luvas(pretas),
        passo(rapido)
    ])).

procurado(11,'Luca Voss',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(castanho),
        cor_cabelo(preto),
        oculos,
        casaco(cinza)
    ])).

procurado(12,'Mina Cross',
    aparencia([
        altura(media),
        genero(gen2),
        cor_olhos(escuro),
        cor_cabelo(ruivo),
        piercing(orelha),
        mala(azul)
    ])).

procurado(13,'Noah Flint',
    aparencia([
        altura(baixa),
        genero(gen1),
        cor_olhos(azul),
        cor_cabelo(castanho),
        barba,
        cachecol(verde)
    ])).

procurado(14,'Orion Lake',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(verde),
        cor_cabelo(grisalho),
        nariz(longo),
        chapeu(cinza)
    ])).


% =========================================================
% TESOUROS
% =========================================================

tesouro(reliquia_norte, m3_2_2_2,
    [cartao_norte, chave_norte, token_norte]).

tesouro(diamante_sul, m3_0_2_2,
    [mapa_sul, broca_sul, senha_sul, luva_sul]).

tesouro(coroa_leste, m3_2_0_2,
    [anel_leste, codigo_leste, cortador_leste, bateria_leste]).

tesouro(arquivo_oeste, m3_2_2_0,
    [pendrive_oeste, badge_oeste, rota_oeste, decoder_oeste, selo_oeste]).

% =========================================================
% ITENS
% =========================================================

item(cartao_norte, m3_1_0_0,
    []).

item(chave_norte, m3_1_1_2,
    [mini_chave_norte]).

item(mini_chave_norte, m3_1_2_0,
    []).

item(token_norte, m3_1_1_1,
    []).

item(mapa_sul, m3_1_0_2,
    []).

item(broca_sul, m3_1_0_0,
    [combustivel_sul]).

item(combustivel_sul, m3_1_2_0,
    []).

item(senha_sul, m3_1_1_2,
    []).

item(luva_sul, m3_1_2_1,
    [fibra_sul]).

item(fibra_sul, m3_1_0_2,
    []).

item(anel_leste, m3_1_1_1,
    []).

item(codigo_leste, m3_1_1_0,
    []).

item(cortador_leste, m3_1_2_2,
    [bateria_leste]).

item(bateria_leste, m3_1_0_2,
    []).

item(bateria_leste, m3_1_0_2,
    []).

item(pendrive_oeste, m3_1_1_1,
    []).

item(badge_oeste, m3_1_2_0,
    []).

item(rota_oeste, m3_1_2_2,
    []).

item(decoder_oeste, m3_1_0_1,
    [chip_oeste]).

item(chip_oeste, m3_1_1_2,
    []).

item(selo_oeste, m3_1_1_0,
    [carimbo_oeste]).

item(carimbo_oeste, m3_1_2_1,
    []).

% =========================================================
% CIDADES
% =========================================================

cidade(m3_0_0_0).
cidade(m3_0_0_1).
cidade(m3_0_0_2).
cidade(m3_0_1_0).
cidade(m3_0_1_1).
cidade(m3_0_1_2).
cidade(m3_0_2_0).
cidade(m3_0_2_1).
cidade(m3_0_2_2).
cidade(m3_1_0_0).
cidade(m3_1_0_1).
cidade(m3_1_0_2).
cidade(m3_1_1_0).
cidade(m3_1_1_1).
cidade(m3_1_1_2).
cidade(m3_1_2_0).
cidade(m3_1_2_1).
cidade(m3_1_2_2).
cidade(m3_2_0_0).
cidade(m3_2_0_1).
cidade(m3_2_0_2).
cidade(m3_2_1_0).
cidade(m3_2_1_1).
cidade(m3_2_1_2).
cidade(m3_2_2_0).
cidade(m3_2_2_1).
cidade(m3_2_2_2).

% =========================================================
% CONEXOES
% =========================================================

conectado(m3_0_0_0,m3_1_0_0).
conectado(m3_0_0_0,m3_0_1_0).
conectado(m3_0_0_0,m3_0_0_1).
conectado(m3_0_0_1,m3_1_0_1).
conectado(m3_0_0_1,m3_0_1_1).
conectado(m3_0_0_1,m3_0_0_2).
conectado(m3_0_0_2,m3_1_0_2).
conectado(m3_0_0_2,m3_0_1_2).
conectado(m3_0_1_0,m3_1_1_0).
conectado(m3_0_1_0,m3_0_2_0).
conectado(m3_0_1_0,m3_0_1_1).
conectado(m3_0_1_1,m3_1_1_1).
conectado(m3_0_1_1,m3_0_2_1).
conectado(m3_0_1_1,m3_0_1_2).
conectado(m3_0_1_2,m3_1_1_2).
conectado(m3_0_1_2,m3_0_2_2).
conectado(m3_0_2_0,m3_1_2_0).
conectado(m3_0_2_0,m3_0_2_1).
conectado(m3_0_2_1,m3_1_2_1).
conectado(m3_0_2_1,m3_0_2_2).
conectado(m3_0_2_2,m3_1_2_2).
conectado(m3_1_0_0,m3_2_0_0).
conectado(m3_1_0_0,m3_1_1_0).
conectado(m3_1_0_0,m3_1_0_1).
conectado(m3_1_0_1,m3_2_0_1).
conectado(m3_1_0_1,m3_1_1_1).
conectado(m3_1_0_1,m3_1_0_2).
conectado(m3_1_0_2,m3_2_0_2).
conectado(m3_1_0_2,m3_1_1_2).
conectado(m3_1_1_0,m3_2_1_0).
conectado(m3_1_1_0,m3_1_2_0).
conectado(m3_1_1_0,m3_1_1_1).
conectado(m3_1_1_1,m3_2_1_1).
conectado(m3_1_1_1,m3_1_2_1).
conectado(m3_1_1_1,m3_1_1_2).
conectado(m3_1_1_2,m3_2_1_2).
conectado(m3_1_1_2,m3_1_2_2).
conectado(m3_1_2_0,m3_2_2_0).
conectado(m3_1_2_0,m3_1_2_1).
conectado(m3_1_2_1,m3_2_2_1).
conectado(m3_1_2_1,m3_1_2_2).
conectado(m3_1_2_2,m3_2_2_2).
conectado(m3_2_0_0,m3_2_1_0).
conectado(m3_2_0_0,m3_2_0_1).
conectado(m3_2_0_1,m3_2_1_1).
conectado(m3_2_0_1,m3_2_0_2).
conectado(m3_2_0_2,m3_2_1_2).
conectado(m3_2_1_0,m3_2_2_0).
conectado(m3_2_1_0,m3_2_1_1).
conectado(m3_2_1_1,m3_2_2_1).
conectado(m3_2_1_1,m3_2_1_2).
conectado(m3_2_1_2,m3_2_2_2).
conectado(m3_2_2_0,m3_2_2_1).
conectado(m3_2_2_1,m3_2_2_2).