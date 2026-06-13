% =========================================================
%  METRO 3^5
%
%  243 cidades
%  5-dimensional ternary metro grid
%  Gerado por tools/generate_metro_scenarios.py
% =========================================================

:- dynamic item/3.
:- dynamic tesouro/3.
:- dynamic roubado/2.

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
% CIDADES
% =========================================================

cidade(m5_0_0_0_0_0).
cidade(m5_0_0_0_0_1).
cidade(m5_0_0_0_0_2).
cidade(m5_0_0_0_1_0).
cidade(m5_0_0_0_1_1).
cidade(m5_0_0_0_1_2).
cidade(m5_0_0_0_2_0).
cidade(m5_0_0_0_2_1).
cidade(m5_0_0_0_2_2).
cidade(m5_0_0_1_0_0).
cidade(m5_0_0_1_0_1).
cidade(m5_0_0_1_0_2).
cidade(m5_0_0_1_1_0).
cidade(m5_0_0_1_1_1).
cidade(m5_0_0_1_1_2).
cidade(m5_0_0_1_2_0).
cidade(m5_0_0_1_2_1).
cidade(m5_0_0_1_2_2).
cidade(m5_0_0_2_0_0).
cidade(m5_0_0_2_0_1).
cidade(m5_0_0_2_0_2).
cidade(m5_0_0_2_1_0).
cidade(m5_0_0_2_1_1).
cidade(m5_0_0_2_1_2).
cidade(m5_0_0_2_2_0).
cidade(m5_0_0_2_2_1).
cidade(m5_0_0_2_2_2).
cidade(m5_0_1_0_0_0).
cidade(m5_0_1_0_0_1).
cidade(m5_0_1_0_0_2).
cidade(m5_0_1_0_1_0).
cidade(m5_0_1_0_1_1).
cidade(m5_0_1_0_1_2).
cidade(m5_0_1_0_2_0).
cidade(m5_0_1_0_2_1).
cidade(m5_0_1_0_2_2).
cidade(m5_0_1_1_0_0).
cidade(m5_0_1_1_0_1).
cidade(m5_0_1_1_0_2).
cidade(m5_0_1_1_1_0).
cidade(m5_0_1_1_1_1).
cidade(m5_0_1_1_1_2).
cidade(m5_0_1_1_2_0).
cidade(m5_0_1_1_2_1).
cidade(m5_0_1_1_2_2).
cidade(m5_0_1_2_0_0).
cidade(m5_0_1_2_0_1).
cidade(m5_0_1_2_0_2).
cidade(m5_0_1_2_1_0).
cidade(m5_0_1_2_1_1).
cidade(m5_0_1_2_1_2).
cidade(m5_0_1_2_2_0).
cidade(m5_0_1_2_2_1).
cidade(m5_0_1_2_2_2).
cidade(m5_0_2_0_0_0).
cidade(m5_0_2_0_0_1).
cidade(m5_0_2_0_0_2).
cidade(m5_0_2_0_1_0).
cidade(m5_0_2_0_1_1).
cidade(m5_0_2_0_1_2).
cidade(m5_0_2_0_2_0).
cidade(m5_0_2_0_2_1).
cidade(m5_0_2_0_2_2).
cidade(m5_0_2_1_0_0).
cidade(m5_0_2_1_0_1).
cidade(m5_0_2_1_0_2).
cidade(m5_0_2_1_1_0).
cidade(m5_0_2_1_1_1).
cidade(m5_0_2_1_1_2).
cidade(m5_0_2_1_2_0).
cidade(m5_0_2_1_2_1).
cidade(m5_0_2_1_2_2).
cidade(m5_0_2_2_0_0).
cidade(m5_0_2_2_0_1).
cidade(m5_0_2_2_0_2).
cidade(m5_0_2_2_1_0).
cidade(m5_0_2_2_1_1).
cidade(m5_0_2_2_1_2).
cidade(m5_0_2_2_2_0).
cidade(m5_0_2_2_2_1).
cidade(m5_0_2_2_2_2).
cidade(m5_1_0_0_0_0).
cidade(m5_1_0_0_0_1).
cidade(m5_1_0_0_0_2).
cidade(m5_1_0_0_1_0).
cidade(m5_1_0_0_1_1).
cidade(m5_1_0_0_1_2).
cidade(m5_1_0_0_2_0).
cidade(m5_1_0_0_2_1).
cidade(m5_1_0_0_2_2).
cidade(m5_1_0_1_0_0).
cidade(m5_1_0_1_0_1).
cidade(m5_1_0_1_0_2).
cidade(m5_1_0_1_1_0).
cidade(m5_1_0_1_1_1).
cidade(m5_1_0_1_1_2).
cidade(m5_1_0_1_2_0).
cidade(m5_1_0_1_2_1).
cidade(m5_1_0_1_2_2).
cidade(m5_1_0_2_0_0).
cidade(m5_1_0_2_0_1).
cidade(m5_1_0_2_0_2).
cidade(m5_1_0_2_1_0).
cidade(m5_1_0_2_1_1).
cidade(m5_1_0_2_1_2).
cidade(m5_1_0_2_2_0).
cidade(m5_1_0_2_2_1).
cidade(m5_1_0_2_2_2).
cidade(m5_1_1_0_0_0).
cidade(m5_1_1_0_0_1).
cidade(m5_1_1_0_0_2).
cidade(m5_1_1_0_1_0).
cidade(m5_1_1_0_1_1).
cidade(m5_1_1_0_1_2).
cidade(m5_1_1_0_2_0).
cidade(m5_1_1_0_2_1).
cidade(m5_1_1_0_2_2).
cidade(m5_1_1_1_0_0).
cidade(m5_1_1_1_0_1).
cidade(m5_1_1_1_0_2).
cidade(m5_1_1_1_1_0).
cidade(m5_1_1_1_1_1).
cidade(m5_1_1_1_1_2).
cidade(m5_1_1_1_2_0).
cidade(m5_1_1_1_2_1).
cidade(m5_1_1_1_2_2).
cidade(m5_1_1_2_0_0).
cidade(m5_1_1_2_0_1).
cidade(m5_1_1_2_0_2).
cidade(m5_1_1_2_1_0).
cidade(m5_1_1_2_1_1).
cidade(m5_1_1_2_1_2).
cidade(m5_1_1_2_2_0).
cidade(m5_1_1_2_2_1).
cidade(m5_1_1_2_2_2).
cidade(m5_1_2_0_0_0).
cidade(m5_1_2_0_0_1).
cidade(m5_1_2_0_0_2).
cidade(m5_1_2_0_1_0).
cidade(m5_1_2_0_1_1).
cidade(m5_1_2_0_1_2).
cidade(m5_1_2_0_2_0).
cidade(m5_1_2_0_2_1).
cidade(m5_1_2_0_2_2).
cidade(m5_1_2_1_0_0).
cidade(m5_1_2_1_0_1).
cidade(m5_1_2_1_0_2).
cidade(m5_1_2_1_1_0).
cidade(m5_1_2_1_1_1).
cidade(m5_1_2_1_1_2).
cidade(m5_1_2_1_2_0).
cidade(m5_1_2_1_2_1).
cidade(m5_1_2_1_2_2).
cidade(m5_1_2_2_0_0).
cidade(m5_1_2_2_0_1).
cidade(m5_1_2_2_0_2).
cidade(m5_1_2_2_1_0).
cidade(m5_1_2_2_1_1).
cidade(m5_1_2_2_1_2).
cidade(m5_1_2_2_2_0).
cidade(m5_1_2_2_2_1).
cidade(m5_1_2_2_2_2).
cidade(m5_2_0_0_0_0).
cidade(m5_2_0_0_0_1).
cidade(m5_2_0_0_0_2).
cidade(m5_2_0_0_1_0).
cidade(m5_2_0_0_1_1).
cidade(m5_2_0_0_1_2).
cidade(m5_2_0_0_2_0).
cidade(m5_2_0_0_2_1).
cidade(m5_2_0_0_2_2).
cidade(m5_2_0_1_0_0).
cidade(m5_2_0_1_0_1).
cidade(m5_2_0_1_0_2).
cidade(m5_2_0_1_1_0).
cidade(m5_2_0_1_1_1).
cidade(m5_2_0_1_1_2).
cidade(m5_2_0_1_2_0).
cidade(m5_2_0_1_2_1).
cidade(m5_2_0_1_2_2).
cidade(m5_2_0_2_0_0).
cidade(m5_2_0_2_0_1).
cidade(m5_2_0_2_0_2).
cidade(m5_2_0_2_1_0).
cidade(m5_2_0_2_1_1).
cidade(m5_2_0_2_1_2).
cidade(m5_2_0_2_2_0).
cidade(m5_2_0_2_2_1).
cidade(m5_2_0_2_2_2).
cidade(m5_2_1_0_0_0).
cidade(m5_2_1_0_0_1).
cidade(m5_2_1_0_0_2).
cidade(m5_2_1_0_1_0).
cidade(m5_2_1_0_1_1).
cidade(m5_2_1_0_1_2).
cidade(m5_2_1_0_2_0).
cidade(m5_2_1_0_2_1).
cidade(m5_2_1_0_2_2).
cidade(m5_2_1_1_0_0).
cidade(m5_2_1_1_0_1).
cidade(m5_2_1_1_0_2).
cidade(m5_2_1_1_1_0).
cidade(m5_2_1_1_1_1).
cidade(m5_2_1_1_1_2).
cidade(m5_2_1_1_2_0).
cidade(m5_2_1_1_2_1).
cidade(m5_2_1_1_2_2).
cidade(m5_2_1_2_0_0).
cidade(m5_2_1_2_0_1).
cidade(m5_2_1_2_0_2).
cidade(m5_2_1_2_1_0).
cidade(m5_2_1_2_1_1).
cidade(m5_2_1_2_1_2).
cidade(m5_2_1_2_2_0).
cidade(m5_2_1_2_2_1).
cidade(m5_2_1_2_2_2).
cidade(m5_2_2_0_0_0).
cidade(m5_2_2_0_0_1).
cidade(m5_2_2_0_0_2).
cidade(m5_2_2_0_1_0).
cidade(m5_2_2_0_1_1).
cidade(m5_2_2_0_1_2).
cidade(m5_2_2_0_2_0).
cidade(m5_2_2_0_2_1).
cidade(m5_2_2_0_2_2).
cidade(m5_2_2_1_0_0).
cidade(m5_2_2_1_0_1).
cidade(m5_2_2_1_0_2).
cidade(m5_2_2_1_1_0).
cidade(m5_2_2_1_1_1).
cidade(m5_2_2_1_1_2).
cidade(m5_2_2_1_2_0).
cidade(m5_2_2_1_2_1).
cidade(m5_2_2_1_2_2).
cidade(m5_2_2_2_0_0).
cidade(m5_2_2_2_0_1).
cidade(m5_2_2_2_0_2).
cidade(m5_2_2_2_1_0).
cidade(m5_2_2_2_1_1).
cidade(m5_2_2_2_1_2).
cidade(m5_2_2_2_2_0).
cidade(m5_2_2_2_2_1).
cidade(m5_2_2_2_2_2).

% =========================================================
% CONEXOES
% =========================================================

conectado(m5_0_0_0_0_0,m5_1_0_0_0_0).
conectado(m5_0_0_0_0_0,m5_0_1_0_0_0).
conectado(m5_0_0_0_0_0,m5_0_0_1_0_0).
conectado(m5_0_0_0_0_0,m5_0_0_0_1_0).
conectado(m5_0_0_0_0_0,m5_0_0_0_0_1).
conectado(m5_0_0_0_0_1,m5_1_0_0_0_1).
conectado(m5_0_0_0_0_1,m5_0_1_0_0_1).
conectado(m5_0_0_0_0_1,m5_0_0_1_0_1).
conectado(m5_0_0_0_0_1,m5_0_0_0_1_1).
conectado(m5_0_0_0_0_1,m5_0_0_0_0_2).
conectado(m5_0_0_0_0_2,m5_1_0_0_0_2).
conectado(m5_0_0_0_0_2,m5_0_1_0_0_2).
conectado(m5_0_0_0_0_2,m5_0_0_1_0_2).
conectado(m5_0_0_0_0_2,m5_0_0_0_1_2).
conectado(m5_0_0_0_1_0,m5_1_0_0_1_0).
conectado(m5_0_0_0_1_0,m5_0_1_0_1_0).
conectado(m5_0_0_0_1_0,m5_0_0_1_1_0).
conectado(m5_0_0_0_1_0,m5_0_0_0_2_0).
conectado(m5_0_0_0_1_0,m5_0_0_0_1_1).
conectado(m5_0_0_0_1_1,m5_1_0_0_1_1).
conectado(m5_0_0_0_1_1,m5_0_1_0_1_1).
conectado(m5_0_0_0_1_1,m5_0_0_1_1_1).
conectado(m5_0_0_0_1_1,m5_0_0_0_2_1).
conectado(m5_0_0_0_1_1,m5_0_0_0_1_2).
conectado(m5_0_0_0_1_2,m5_1_0_0_1_2).
conectado(m5_0_0_0_1_2,m5_0_1_0_1_2).
conectado(m5_0_0_0_1_2,m5_0_0_1_1_2).
conectado(m5_0_0_0_1_2,m5_0_0_0_2_2).
conectado(m5_0_0_0_2_0,m5_1_0_0_2_0).
conectado(m5_0_0_0_2_0,m5_0_1_0_2_0).
conectado(m5_0_0_0_2_0,m5_0_0_1_2_0).
conectado(m5_0_0_0_2_0,m5_0_0_0_2_1).
conectado(m5_0_0_0_2_1,m5_1_0_0_2_1).
conectado(m5_0_0_0_2_1,m5_0_1_0_2_1).
conectado(m5_0_0_0_2_1,m5_0_0_1_2_1).
conectado(m5_0_0_0_2_1,m5_0_0_0_2_2).
conectado(m5_0_0_0_2_2,m5_1_0_0_2_2).
conectado(m5_0_0_0_2_2,m5_0_1_0_2_2).
conectado(m5_0_0_0_2_2,m5_0_0_1_2_2).
conectado(m5_0_0_1_0_0,m5_1_0_1_0_0).
conectado(m5_0_0_1_0_0,m5_0_1_1_0_0).
conectado(m5_0_0_1_0_0,m5_0_0_2_0_0).
conectado(m5_0_0_1_0_0,m5_0_0_1_1_0).
conectado(m5_0_0_1_0_0,m5_0_0_1_0_1).
conectado(m5_0_0_1_0_1,m5_1_0_1_0_1).
conectado(m5_0_0_1_0_1,m5_0_1_1_0_1).
conectado(m5_0_0_1_0_1,m5_0_0_2_0_1).
conectado(m5_0_0_1_0_1,m5_0_0_1_1_1).
conectado(m5_0_0_1_0_1,m5_0_0_1_0_2).
conectado(m5_0_0_1_0_2,m5_1_0_1_0_2).
conectado(m5_0_0_1_0_2,m5_0_1_1_0_2).
conectado(m5_0_0_1_0_2,m5_0_0_2_0_2).
conectado(m5_0_0_1_0_2,m5_0_0_1_1_2).
conectado(m5_0_0_1_1_0,m5_1_0_1_1_0).
conectado(m5_0_0_1_1_0,m5_0_1_1_1_0).
conectado(m5_0_0_1_1_0,m5_0_0_2_1_0).
conectado(m5_0_0_1_1_0,m5_0_0_1_2_0).
conectado(m5_0_0_1_1_0,m5_0_0_1_1_1).
conectado(m5_0_0_1_1_1,m5_1_0_1_1_1).
conectado(m5_0_0_1_1_1,m5_0_1_1_1_1).
conectado(m5_0_0_1_1_1,m5_0_0_2_1_1).
conectado(m5_0_0_1_1_1,m5_0_0_1_2_1).
conectado(m5_0_0_1_1_1,m5_0_0_1_1_2).
conectado(m5_0_0_1_1_2,m5_1_0_1_1_2).
conectado(m5_0_0_1_1_2,m5_0_1_1_1_2).
conectado(m5_0_0_1_1_2,m5_0_0_2_1_2).
conectado(m5_0_0_1_1_2,m5_0_0_1_2_2).
conectado(m5_0_0_1_2_0,m5_1_0_1_2_0).
conectado(m5_0_0_1_2_0,m5_0_1_1_2_0).
conectado(m5_0_0_1_2_0,m5_0_0_2_2_0).
conectado(m5_0_0_1_2_0,m5_0_0_1_2_1).
conectado(m5_0_0_1_2_1,m5_1_0_1_2_1).
conectado(m5_0_0_1_2_1,m5_0_1_1_2_1).
conectado(m5_0_0_1_2_1,m5_0_0_2_2_1).
conectado(m5_0_0_1_2_1,m5_0_0_1_2_2).
conectado(m5_0_0_1_2_2,m5_1_0_1_2_2).
conectado(m5_0_0_1_2_2,m5_0_1_1_2_2).
conectado(m5_0_0_1_2_2,m5_0_0_2_2_2).
conectado(m5_0_0_2_0_0,m5_1_0_2_0_0).
conectado(m5_0_0_2_0_0,m5_0_1_2_0_0).
conectado(m5_0_0_2_0_0,m5_0_0_2_1_0).
conectado(m5_0_0_2_0_0,m5_0_0_2_0_1).
conectado(m5_0_0_2_0_1,m5_1_0_2_0_1).
conectado(m5_0_0_2_0_1,m5_0_1_2_0_1).
conectado(m5_0_0_2_0_1,m5_0_0_2_1_1).
conectado(m5_0_0_2_0_1,m5_0_0_2_0_2).
conectado(m5_0_0_2_0_2,m5_1_0_2_0_2).
conectado(m5_0_0_2_0_2,m5_0_1_2_0_2).
conectado(m5_0_0_2_0_2,m5_0_0_2_1_2).
conectado(m5_0_0_2_1_0,m5_1_0_2_1_0).
conectado(m5_0_0_2_1_0,m5_0_1_2_1_0).
conectado(m5_0_0_2_1_0,m5_0_0_2_2_0).
conectado(m5_0_0_2_1_0,m5_0_0_2_1_1).
conectado(m5_0_0_2_1_1,m5_1_0_2_1_1).
conectado(m5_0_0_2_1_1,m5_0_1_2_1_1).
conectado(m5_0_0_2_1_1,m5_0_0_2_2_1).
conectado(m5_0_0_2_1_1,m5_0_0_2_1_2).
conectado(m5_0_0_2_1_2,m5_1_0_2_1_2).
conectado(m5_0_0_2_1_2,m5_0_1_2_1_2).
conectado(m5_0_0_2_1_2,m5_0_0_2_2_2).
conectado(m5_0_0_2_2_0,m5_1_0_2_2_0).
conectado(m5_0_0_2_2_0,m5_0_1_2_2_0).
conectado(m5_0_0_2_2_0,m5_0_0_2_2_1).
conectado(m5_0_0_2_2_1,m5_1_0_2_2_1).
conectado(m5_0_0_2_2_1,m5_0_1_2_2_1).
conectado(m5_0_0_2_2_1,m5_0_0_2_2_2).
conectado(m5_0_0_2_2_2,m5_1_0_2_2_2).
conectado(m5_0_0_2_2_2,m5_0_1_2_2_2).
conectado(m5_0_1_0_0_0,m5_1_1_0_0_0).
conectado(m5_0_1_0_0_0,m5_0_2_0_0_0).
conectado(m5_0_1_0_0_0,m5_0_1_1_0_0).
conectado(m5_0_1_0_0_0,m5_0_1_0_1_0).
conectado(m5_0_1_0_0_0,m5_0_1_0_0_1).
conectado(m5_0_1_0_0_1,m5_1_1_0_0_1).
conectado(m5_0_1_0_0_1,m5_0_2_0_0_1).
conectado(m5_0_1_0_0_1,m5_0_1_1_0_1).
conectado(m5_0_1_0_0_1,m5_0_1_0_1_1).
conectado(m5_0_1_0_0_1,m5_0_1_0_0_2).
conectado(m5_0_1_0_0_2,m5_1_1_0_0_2).
conectado(m5_0_1_0_0_2,m5_0_2_0_0_2).
conectado(m5_0_1_0_0_2,m5_0_1_1_0_2).
conectado(m5_0_1_0_0_2,m5_0_1_0_1_2).
conectado(m5_0_1_0_1_0,m5_1_1_0_1_0).
conectado(m5_0_1_0_1_0,m5_0_2_0_1_0).
conectado(m5_0_1_0_1_0,m5_0_1_1_1_0).
conectado(m5_0_1_0_1_0,m5_0_1_0_2_0).
conectado(m5_0_1_0_1_0,m5_0_1_0_1_1).
conectado(m5_0_1_0_1_1,m5_1_1_0_1_1).
conectado(m5_0_1_0_1_1,m5_0_2_0_1_1).
conectado(m5_0_1_0_1_1,m5_0_1_1_1_1).
conectado(m5_0_1_0_1_1,m5_0_1_0_2_1).
conectado(m5_0_1_0_1_1,m5_0_1_0_1_2).
conectado(m5_0_1_0_1_2,m5_1_1_0_1_2).
conectado(m5_0_1_0_1_2,m5_0_2_0_1_2).
conectado(m5_0_1_0_1_2,m5_0_1_1_1_2).
conectado(m5_0_1_0_1_2,m5_0_1_0_2_2).
conectado(m5_0_1_0_2_0,m5_1_1_0_2_0).
conectado(m5_0_1_0_2_0,m5_0_2_0_2_0).
conectado(m5_0_1_0_2_0,m5_0_1_1_2_0).
conectado(m5_0_1_0_2_0,m5_0_1_0_2_1).
conectado(m5_0_1_0_2_1,m5_1_1_0_2_1).
conectado(m5_0_1_0_2_1,m5_0_2_0_2_1).
conectado(m5_0_1_0_2_1,m5_0_1_1_2_1).
conectado(m5_0_1_0_2_1,m5_0_1_0_2_2).
conectado(m5_0_1_0_2_2,m5_1_1_0_2_2).
conectado(m5_0_1_0_2_2,m5_0_2_0_2_2).
conectado(m5_0_1_0_2_2,m5_0_1_1_2_2).
conectado(m5_0_1_1_0_0,m5_1_1_1_0_0).
conectado(m5_0_1_1_0_0,m5_0_2_1_0_0).
conectado(m5_0_1_1_0_0,m5_0_1_2_0_0).
conectado(m5_0_1_1_0_0,m5_0_1_1_1_0).
conectado(m5_0_1_1_0_0,m5_0_1_1_0_1).
conectado(m5_0_1_1_0_1,m5_1_1_1_0_1).
conectado(m5_0_1_1_0_1,m5_0_2_1_0_1).
conectado(m5_0_1_1_0_1,m5_0_1_2_0_1).
conectado(m5_0_1_1_0_1,m5_0_1_1_1_1).
conectado(m5_0_1_1_0_1,m5_0_1_1_0_2).
conectado(m5_0_1_1_0_2,m5_1_1_1_0_2).
conectado(m5_0_1_1_0_2,m5_0_2_1_0_2).
conectado(m5_0_1_1_0_2,m5_0_1_2_0_2).
conectado(m5_0_1_1_0_2,m5_0_1_1_1_2).
conectado(m5_0_1_1_1_0,m5_1_1_1_1_0).
conectado(m5_0_1_1_1_0,m5_0_2_1_1_0).
conectado(m5_0_1_1_1_0,m5_0_1_2_1_0).
conectado(m5_0_1_1_1_0,m5_0_1_1_2_0).
conectado(m5_0_1_1_1_0,m5_0_1_1_1_1).
conectado(m5_0_1_1_1_1,m5_1_1_1_1_1).
conectado(m5_0_1_1_1_1,m5_0_2_1_1_1).
conectado(m5_0_1_1_1_1,m5_0_1_2_1_1).
conectado(m5_0_1_1_1_1,m5_0_1_1_2_1).
conectado(m5_0_1_1_1_1,m5_0_1_1_1_2).
conectado(m5_0_1_1_1_2,m5_1_1_1_1_2).
conectado(m5_0_1_1_1_2,m5_0_2_1_1_2).
conectado(m5_0_1_1_1_2,m5_0_1_2_1_2).
conectado(m5_0_1_1_1_2,m5_0_1_1_2_2).
conectado(m5_0_1_1_2_0,m5_1_1_1_2_0).
conectado(m5_0_1_1_2_0,m5_0_2_1_2_0).
conectado(m5_0_1_1_2_0,m5_0_1_2_2_0).
conectado(m5_0_1_1_2_0,m5_0_1_1_2_1).
conectado(m5_0_1_1_2_1,m5_1_1_1_2_1).
conectado(m5_0_1_1_2_1,m5_0_2_1_2_1).
conectado(m5_0_1_1_2_1,m5_0_1_2_2_1).
conectado(m5_0_1_1_2_1,m5_0_1_1_2_2).
conectado(m5_0_1_1_2_2,m5_1_1_1_2_2).
conectado(m5_0_1_1_2_2,m5_0_2_1_2_2).
conectado(m5_0_1_1_2_2,m5_0_1_2_2_2).
conectado(m5_0_1_2_0_0,m5_1_1_2_0_0).
conectado(m5_0_1_2_0_0,m5_0_2_2_0_0).
conectado(m5_0_1_2_0_0,m5_0_1_2_1_0).
conectado(m5_0_1_2_0_0,m5_0_1_2_0_1).
conectado(m5_0_1_2_0_1,m5_1_1_2_0_1).
conectado(m5_0_1_2_0_1,m5_0_2_2_0_1).
conectado(m5_0_1_2_0_1,m5_0_1_2_1_1).
conectado(m5_0_1_2_0_1,m5_0_1_2_0_2).
conectado(m5_0_1_2_0_2,m5_1_1_2_0_2).
conectado(m5_0_1_2_0_2,m5_0_2_2_0_2).
conectado(m5_0_1_2_0_2,m5_0_1_2_1_2).
conectado(m5_0_1_2_1_0,m5_1_1_2_1_0).
conectado(m5_0_1_2_1_0,m5_0_2_2_1_0).
conectado(m5_0_1_2_1_0,m5_0_1_2_2_0).
conectado(m5_0_1_2_1_0,m5_0_1_2_1_1).
conectado(m5_0_1_2_1_1,m5_1_1_2_1_1).
conectado(m5_0_1_2_1_1,m5_0_2_2_1_1).
conectado(m5_0_1_2_1_1,m5_0_1_2_2_1).
conectado(m5_0_1_2_1_1,m5_0_1_2_1_2).
conectado(m5_0_1_2_1_2,m5_1_1_2_1_2).
conectado(m5_0_1_2_1_2,m5_0_2_2_1_2).
conectado(m5_0_1_2_1_2,m5_0_1_2_2_2).
conectado(m5_0_1_2_2_0,m5_1_1_2_2_0).
conectado(m5_0_1_2_2_0,m5_0_2_2_2_0).
conectado(m5_0_1_2_2_0,m5_0_1_2_2_1).
conectado(m5_0_1_2_2_1,m5_1_1_2_2_1).
conectado(m5_0_1_2_2_1,m5_0_2_2_2_1).
conectado(m5_0_1_2_2_1,m5_0_1_2_2_2).
conectado(m5_0_1_2_2_2,m5_1_1_2_2_2).
conectado(m5_0_1_2_2_2,m5_0_2_2_2_2).
conectado(m5_0_2_0_0_0,m5_1_2_0_0_0).
conectado(m5_0_2_0_0_0,m5_0_2_1_0_0).
conectado(m5_0_2_0_0_0,m5_0_2_0_1_0).
conectado(m5_0_2_0_0_0,m5_0_2_0_0_1).
conectado(m5_0_2_0_0_1,m5_1_2_0_0_1).
conectado(m5_0_2_0_0_1,m5_0_2_1_0_1).
conectado(m5_0_2_0_0_1,m5_0_2_0_1_1).
conectado(m5_0_2_0_0_1,m5_0_2_0_0_2).
conectado(m5_0_2_0_0_2,m5_1_2_0_0_2).
conectado(m5_0_2_0_0_2,m5_0_2_1_0_2).
conectado(m5_0_2_0_0_2,m5_0_2_0_1_2).
conectado(m5_0_2_0_1_0,m5_1_2_0_1_0).
conectado(m5_0_2_0_1_0,m5_0_2_1_1_0).
conectado(m5_0_2_0_1_0,m5_0_2_0_2_0).
conectado(m5_0_2_0_1_0,m5_0_2_0_1_1).
conectado(m5_0_2_0_1_1,m5_1_2_0_1_1).
conectado(m5_0_2_0_1_1,m5_0_2_1_1_1).
conectado(m5_0_2_0_1_1,m5_0_2_0_2_1).
conectado(m5_0_2_0_1_1,m5_0_2_0_1_2).
conectado(m5_0_2_0_1_2,m5_1_2_0_1_2).
conectado(m5_0_2_0_1_2,m5_0_2_1_1_2).
conectado(m5_0_2_0_1_2,m5_0_2_0_2_2).
conectado(m5_0_2_0_2_0,m5_1_2_0_2_0).
conectado(m5_0_2_0_2_0,m5_0_2_1_2_0).
conectado(m5_0_2_0_2_0,m5_0_2_0_2_1).
conectado(m5_0_2_0_2_1,m5_1_2_0_2_1).
conectado(m5_0_2_0_2_1,m5_0_2_1_2_1).
conectado(m5_0_2_0_2_1,m5_0_2_0_2_2).
conectado(m5_0_2_0_2_2,m5_1_2_0_2_2).
conectado(m5_0_2_0_2_2,m5_0_2_1_2_2).
conectado(m5_0_2_1_0_0,m5_1_2_1_0_0).
conectado(m5_0_2_1_0_0,m5_0_2_2_0_0).
conectado(m5_0_2_1_0_0,m5_0_2_1_1_0).
conectado(m5_0_2_1_0_0,m5_0_2_1_0_1).
conectado(m5_0_2_1_0_1,m5_1_2_1_0_1).
conectado(m5_0_2_1_0_1,m5_0_2_2_0_1).
conectado(m5_0_2_1_0_1,m5_0_2_1_1_1).
conectado(m5_0_2_1_0_1,m5_0_2_1_0_2).
conectado(m5_0_2_1_0_2,m5_1_2_1_0_2).
conectado(m5_0_2_1_0_2,m5_0_2_2_0_2).
conectado(m5_0_2_1_0_2,m5_0_2_1_1_2).
conectado(m5_0_2_1_1_0,m5_1_2_1_1_0).
conectado(m5_0_2_1_1_0,m5_0_2_2_1_0).
conectado(m5_0_2_1_1_0,m5_0_2_1_2_0).
conectado(m5_0_2_1_1_0,m5_0_2_1_1_1).
conectado(m5_0_2_1_1_1,m5_1_2_1_1_1).
conectado(m5_0_2_1_1_1,m5_0_2_2_1_1).
conectado(m5_0_2_1_1_1,m5_0_2_1_2_1).
conectado(m5_0_2_1_1_1,m5_0_2_1_1_2).
conectado(m5_0_2_1_1_2,m5_1_2_1_1_2).
conectado(m5_0_2_1_1_2,m5_0_2_2_1_2).
conectado(m5_0_2_1_1_2,m5_0_2_1_2_2).
conectado(m5_0_2_1_2_0,m5_1_2_1_2_0).
conectado(m5_0_2_1_2_0,m5_0_2_2_2_0).
conectado(m5_0_2_1_2_0,m5_0_2_1_2_1).
conectado(m5_0_2_1_2_1,m5_1_2_1_2_1).
conectado(m5_0_2_1_2_1,m5_0_2_2_2_1).
conectado(m5_0_2_1_2_1,m5_0_2_1_2_2).
conectado(m5_0_2_1_2_2,m5_1_2_1_2_2).
conectado(m5_0_2_1_2_2,m5_0_2_2_2_2).
conectado(m5_0_2_2_0_0,m5_1_2_2_0_0).
conectado(m5_0_2_2_0_0,m5_0_2_2_1_0).
conectado(m5_0_2_2_0_0,m5_0_2_2_0_1).
conectado(m5_0_2_2_0_1,m5_1_2_2_0_1).
conectado(m5_0_2_2_0_1,m5_0_2_2_1_1).
conectado(m5_0_2_2_0_1,m5_0_2_2_0_2).
conectado(m5_0_2_2_0_2,m5_1_2_2_0_2).
conectado(m5_0_2_2_0_2,m5_0_2_2_1_2).
conectado(m5_0_2_2_1_0,m5_1_2_2_1_0).
conectado(m5_0_2_2_1_0,m5_0_2_2_2_0).
conectado(m5_0_2_2_1_0,m5_0_2_2_1_1).
conectado(m5_0_2_2_1_1,m5_1_2_2_1_1).
conectado(m5_0_2_2_1_1,m5_0_2_2_2_1).
conectado(m5_0_2_2_1_1,m5_0_2_2_1_2).
conectado(m5_0_2_2_1_2,m5_1_2_2_1_2).
conectado(m5_0_2_2_1_2,m5_0_2_2_2_2).
conectado(m5_0_2_2_2_0,m5_1_2_2_2_0).
conectado(m5_0_2_2_2_0,m5_0_2_2_2_1).
conectado(m5_0_2_2_2_1,m5_1_2_2_2_1).
conectado(m5_0_2_2_2_1,m5_0_2_2_2_2).
conectado(m5_0_2_2_2_2,m5_1_2_2_2_2).
conectado(m5_1_0_0_0_0,m5_2_0_0_0_0).
conectado(m5_1_0_0_0_0,m5_1_1_0_0_0).
conectado(m5_1_0_0_0_0,m5_1_0_1_0_0).
conectado(m5_1_0_0_0_0,m5_1_0_0_1_0).
conectado(m5_1_0_0_0_0,m5_1_0_0_0_1).
conectado(m5_1_0_0_0_1,m5_2_0_0_0_1).
conectado(m5_1_0_0_0_1,m5_1_1_0_0_1).
conectado(m5_1_0_0_0_1,m5_1_0_1_0_1).
conectado(m5_1_0_0_0_1,m5_1_0_0_1_1).
conectado(m5_1_0_0_0_1,m5_1_0_0_0_2).
conectado(m5_1_0_0_0_2,m5_2_0_0_0_2).
conectado(m5_1_0_0_0_2,m5_1_1_0_0_2).
conectado(m5_1_0_0_0_2,m5_1_0_1_0_2).
conectado(m5_1_0_0_0_2,m5_1_0_0_1_2).
conectado(m5_1_0_0_1_0,m5_2_0_0_1_0).
conectado(m5_1_0_0_1_0,m5_1_1_0_1_0).
conectado(m5_1_0_0_1_0,m5_1_0_1_1_0).
conectado(m5_1_0_0_1_0,m5_1_0_0_2_0).
conectado(m5_1_0_0_1_0,m5_1_0_0_1_1).
conectado(m5_1_0_0_1_1,m5_2_0_0_1_1).
conectado(m5_1_0_0_1_1,m5_1_1_0_1_1).
conectado(m5_1_0_0_1_1,m5_1_0_1_1_1).
conectado(m5_1_0_0_1_1,m5_1_0_0_2_1).
conectado(m5_1_0_0_1_1,m5_1_0_0_1_2).
conectado(m5_1_0_0_1_2,m5_2_0_0_1_2).
conectado(m5_1_0_0_1_2,m5_1_1_0_1_2).
conectado(m5_1_0_0_1_2,m5_1_0_1_1_2).
conectado(m5_1_0_0_1_2,m5_1_0_0_2_2).
conectado(m5_1_0_0_2_0,m5_2_0_0_2_0).
conectado(m5_1_0_0_2_0,m5_1_1_0_2_0).
conectado(m5_1_0_0_2_0,m5_1_0_1_2_0).
conectado(m5_1_0_0_2_0,m5_1_0_0_2_1).
conectado(m5_1_0_0_2_1,m5_2_0_0_2_1).
conectado(m5_1_0_0_2_1,m5_1_1_0_2_1).
conectado(m5_1_0_0_2_1,m5_1_0_1_2_1).
conectado(m5_1_0_0_2_1,m5_1_0_0_2_2).
conectado(m5_1_0_0_2_2,m5_2_0_0_2_2).
conectado(m5_1_0_0_2_2,m5_1_1_0_2_2).
conectado(m5_1_0_0_2_2,m5_1_0_1_2_2).
conectado(m5_1_0_1_0_0,m5_2_0_1_0_0).
conectado(m5_1_0_1_0_0,m5_1_1_1_0_0).
conectado(m5_1_0_1_0_0,m5_1_0_2_0_0).
conectado(m5_1_0_1_0_0,m5_1_0_1_1_0).
conectado(m5_1_0_1_0_0,m5_1_0_1_0_1).
conectado(m5_1_0_1_0_1,m5_2_0_1_0_1).
conectado(m5_1_0_1_0_1,m5_1_1_1_0_1).
conectado(m5_1_0_1_0_1,m5_1_0_2_0_1).
conectado(m5_1_0_1_0_1,m5_1_0_1_1_1).
conectado(m5_1_0_1_0_1,m5_1_0_1_0_2).
conectado(m5_1_0_1_0_2,m5_2_0_1_0_2).
conectado(m5_1_0_1_0_2,m5_1_1_1_0_2).
conectado(m5_1_0_1_0_2,m5_1_0_2_0_2).
conectado(m5_1_0_1_0_2,m5_1_0_1_1_2).
conectado(m5_1_0_1_1_0,m5_2_0_1_1_0).
conectado(m5_1_0_1_1_0,m5_1_1_1_1_0).
conectado(m5_1_0_1_1_0,m5_1_0_2_1_0).
conectado(m5_1_0_1_1_0,m5_1_0_1_2_0).
conectado(m5_1_0_1_1_0,m5_1_0_1_1_1).
conectado(m5_1_0_1_1_1,m5_2_0_1_1_1).
conectado(m5_1_0_1_1_1,m5_1_1_1_1_1).
conectado(m5_1_0_1_1_1,m5_1_0_2_1_1).
conectado(m5_1_0_1_1_1,m5_1_0_1_2_1).
conectado(m5_1_0_1_1_1,m5_1_0_1_1_2).
conectado(m5_1_0_1_1_2,m5_2_0_1_1_2).
conectado(m5_1_0_1_1_2,m5_1_1_1_1_2).
conectado(m5_1_0_1_1_2,m5_1_0_2_1_2).
conectado(m5_1_0_1_1_2,m5_1_0_1_2_2).
conectado(m5_1_0_1_2_0,m5_2_0_1_2_0).
conectado(m5_1_0_1_2_0,m5_1_1_1_2_0).
conectado(m5_1_0_1_2_0,m5_1_0_2_2_0).
conectado(m5_1_0_1_2_0,m5_1_0_1_2_1).
conectado(m5_1_0_1_2_1,m5_2_0_1_2_1).
conectado(m5_1_0_1_2_1,m5_1_1_1_2_1).
conectado(m5_1_0_1_2_1,m5_1_0_2_2_1).
conectado(m5_1_0_1_2_1,m5_1_0_1_2_2).
conectado(m5_1_0_1_2_2,m5_2_0_1_2_2).
conectado(m5_1_0_1_2_2,m5_1_1_1_2_2).
conectado(m5_1_0_1_2_2,m5_1_0_2_2_2).
conectado(m5_1_0_2_0_0,m5_2_0_2_0_0).
conectado(m5_1_0_2_0_0,m5_1_1_2_0_0).
conectado(m5_1_0_2_0_0,m5_1_0_2_1_0).
conectado(m5_1_0_2_0_0,m5_1_0_2_0_1).
conectado(m5_1_0_2_0_1,m5_2_0_2_0_1).
conectado(m5_1_0_2_0_1,m5_1_1_2_0_1).
conectado(m5_1_0_2_0_1,m5_1_0_2_1_1).
conectado(m5_1_0_2_0_1,m5_1_0_2_0_2).
conectado(m5_1_0_2_0_2,m5_2_0_2_0_2).
conectado(m5_1_0_2_0_2,m5_1_1_2_0_2).
conectado(m5_1_0_2_0_2,m5_1_0_2_1_2).
conectado(m5_1_0_2_1_0,m5_2_0_2_1_0).
conectado(m5_1_0_2_1_0,m5_1_1_2_1_0).
conectado(m5_1_0_2_1_0,m5_1_0_2_2_0).
conectado(m5_1_0_2_1_0,m5_1_0_2_1_1).
conectado(m5_1_0_2_1_1,m5_2_0_2_1_1).
conectado(m5_1_0_2_1_1,m5_1_1_2_1_1).
conectado(m5_1_0_2_1_1,m5_1_0_2_2_1).
conectado(m5_1_0_2_1_1,m5_1_0_2_1_2).
conectado(m5_1_0_2_1_2,m5_2_0_2_1_2).
conectado(m5_1_0_2_1_2,m5_1_1_2_1_2).
conectado(m5_1_0_2_1_2,m5_1_0_2_2_2).
conectado(m5_1_0_2_2_0,m5_2_0_2_2_0).
conectado(m5_1_0_2_2_0,m5_1_1_2_2_0).
conectado(m5_1_0_2_2_0,m5_1_0_2_2_1).
conectado(m5_1_0_2_2_1,m5_2_0_2_2_1).
conectado(m5_1_0_2_2_1,m5_1_1_2_2_1).
conectado(m5_1_0_2_2_1,m5_1_0_2_2_2).
conectado(m5_1_0_2_2_2,m5_2_0_2_2_2).
conectado(m5_1_0_2_2_2,m5_1_1_2_2_2).
conectado(m5_1_1_0_0_0,m5_2_1_0_0_0).
conectado(m5_1_1_0_0_0,m5_1_2_0_0_0).
conectado(m5_1_1_0_0_0,m5_1_1_1_0_0).
conectado(m5_1_1_0_0_0,m5_1_1_0_1_0).
conectado(m5_1_1_0_0_0,m5_1_1_0_0_1).
conectado(m5_1_1_0_0_1,m5_2_1_0_0_1).
conectado(m5_1_1_0_0_1,m5_1_2_0_0_1).
conectado(m5_1_1_0_0_1,m5_1_1_1_0_1).
conectado(m5_1_1_0_0_1,m5_1_1_0_1_1).
conectado(m5_1_1_0_0_1,m5_1_1_0_0_2).
conectado(m5_1_1_0_0_2,m5_2_1_0_0_2).
conectado(m5_1_1_0_0_2,m5_1_2_0_0_2).
conectado(m5_1_1_0_0_2,m5_1_1_1_0_2).
conectado(m5_1_1_0_0_2,m5_1_1_0_1_2).
conectado(m5_1_1_0_1_0,m5_2_1_0_1_0).
conectado(m5_1_1_0_1_0,m5_1_2_0_1_0).
conectado(m5_1_1_0_1_0,m5_1_1_1_1_0).
conectado(m5_1_1_0_1_0,m5_1_1_0_2_0).
conectado(m5_1_1_0_1_0,m5_1_1_0_1_1).
conectado(m5_1_1_0_1_1,m5_2_1_0_1_1).
conectado(m5_1_1_0_1_1,m5_1_2_0_1_1).
conectado(m5_1_1_0_1_1,m5_1_1_1_1_1).
conectado(m5_1_1_0_1_1,m5_1_1_0_2_1).
conectado(m5_1_1_0_1_1,m5_1_1_0_1_2).
conectado(m5_1_1_0_1_2,m5_2_1_0_1_2).
conectado(m5_1_1_0_1_2,m5_1_2_0_1_2).
conectado(m5_1_1_0_1_2,m5_1_1_1_1_2).
conectado(m5_1_1_0_1_2,m5_1_1_0_2_2).
conectado(m5_1_1_0_2_0,m5_2_1_0_2_0).
conectado(m5_1_1_0_2_0,m5_1_2_0_2_0).
conectado(m5_1_1_0_2_0,m5_1_1_1_2_0).
conectado(m5_1_1_0_2_0,m5_1_1_0_2_1).
conectado(m5_1_1_0_2_1,m5_2_1_0_2_1).
conectado(m5_1_1_0_2_1,m5_1_2_0_2_1).
conectado(m5_1_1_0_2_1,m5_1_1_1_2_1).
conectado(m5_1_1_0_2_1,m5_1_1_0_2_2).
conectado(m5_1_1_0_2_2,m5_2_1_0_2_2).
conectado(m5_1_1_0_2_2,m5_1_2_0_2_2).
conectado(m5_1_1_0_2_2,m5_1_1_1_2_2).
conectado(m5_1_1_1_0_0,m5_2_1_1_0_0).
conectado(m5_1_1_1_0_0,m5_1_2_1_0_0).
conectado(m5_1_1_1_0_0,m5_1_1_2_0_0).
conectado(m5_1_1_1_0_0,m5_1_1_1_1_0).
conectado(m5_1_1_1_0_0,m5_1_1_1_0_1).
conectado(m5_1_1_1_0_1,m5_2_1_1_0_1).
conectado(m5_1_1_1_0_1,m5_1_2_1_0_1).
conectado(m5_1_1_1_0_1,m5_1_1_2_0_1).
conectado(m5_1_1_1_0_1,m5_1_1_1_1_1).
conectado(m5_1_1_1_0_1,m5_1_1_1_0_2).
conectado(m5_1_1_1_0_2,m5_2_1_1_0_2).
conectado(m5_1_1_1_0_2,m5_1_2_1_0_2).
conectado(m5_1_1_1_0_2,m5_1_1_2_0_2).
conectado(m5_1_1_1_0_2,m5_1_1_1_1_2).
conectado(m5_1_1_1_1_0,m5_2_1_1_1_0).
conectado(m5_1_1_1_1_0,m5_1_2_1_1_0).
conectado(m5_1_1_1_1_0,m5_1_1_2_1_0).
conectado(m5_1_1_1_1_0,m5_1_1_1_2_0).
conectado(m5_1_1_1_1_0,m5_1_1_1_1_1).
conectado(m5_1_1_1_1_1,m5_2_1_1_1_1).
conectado(m5_1_1_1_1_1,m5_1_2_1_1_1).
conectado(m5_1_1_1_1_1,m5_1_1_2_1_1).
conectado(m5_1_1_1_1_1,m5_1_1_1_2_1).
conectado(m5_1_1_1_1_1,m5_1_1_1_1_2).
conectado(m5_1_1_1_1_2,m5_2_1_1_1_2).
conectado(m5_1_1_1_1_2,m5_1_2_1_1_2).
conectado(m5_1_1_1_1_2,m5_1_1_2_1_2).
conectado(m5_1_1_1_1_2,m5_1_1_1_2_2).
conectado(m5_1_1_1_2_0,m5_2_1_1_2_0).
conectado(m5_1_1_1_2_0,m5_1_2_1_2_0).
conectado(m5_1_1_1_2_0,m5_1_1_2_2_0).
conectado(m5_1_1_1_2_0,m5_1_1_1_2_1).
conectado(m5_1_1_1_2_1,m5_2_1_1_2_1).
conectado(m5_1_1_1_2_1,m5_1_2_1_2_1).
conectado(m5_1_1_1_2_1,m5_1_1_2_2_1).
conectado(m5_1_1_1_2_1,m5_1_1_1_2_2).
conectado(m5_1_1_1_2_2,m5_2_1_1_2_2).
conectado(m5_1_1_1_2_2,m5_1_2_1_2_2).
conectado(m5_1_1_1_2_2,m5_1_1_2_2_2).
conectado(m5_1_1_2_0_0,m5_2_1_2_0_0).
conectado(m5_1_1_2_0_0,m5_1_2_2_0_0).
conectado(m5_1_1_2_0_0,m5_1_1_2_1_0).
conectado(m5_1_1_2_0_0,m5_1_1_2_0_1).
conectado(m5_1_1_2_0_1,m5_2_1_2_0_1).
conectado(m5_1_1_2_0_1,m5_1_2_2_0_1).
conectado(m5_1_1_2_0_1,m5_1_1_2_1_1).
conectado(m5_1_1_2_0_1,m5_1_1_2_0_2).
conectado(m5_1_1_2_0_2,m5_2_1_2_0_2).
conectado(m5_1_1_2_0_2,m5_1_2_2_0_2).
conectado(m5_1_1_2_0_2,m5_1_1_2_1_2).
conectado(m5_1_1_2_1_0,m5_2_1_2_1_0).
conectado(m5_1_1_2_1_0,m5_1_2_2_1_0).
conectado(m5_1_1_2_1_0,m5_1_1_2_2_0).
conectado(m5_1_1_2_1_0,m5_1_1_2_1_1).
conectado(m5_1_1_2_1_1,m5_2_1_2_1_1).
conectado(m5_1_1_2_1_1,m5_1_2_2_1_1).
conectado(m5_1_1_2_1_1,m5_1_1_2_2_1).
conectado(m5_1_1_2_1_1,m5_1_1_2_1_2).
conectado(m5_1_1_2_1_2,m5_2_1_2_1_2).
conectado(m5_1_1_2_1_2,m5_1_2_2_1_2).
conectado(m5_1_1_2_1_2,m5_1_1_2_2_2).
conectado(m5_1_1_2_2_0,m5_2_1_2_2_0).
conectado(m5_1_1_2_2_0,m5_1_2_2_2_0).
conectado(m5_1_1_2_2_0,m5_1_1_2_2_1).
conectado(m5_1_1_2_2_1,m5_2_1_2_2_1).
conectado(m5_1_1_2_2_1,m5_1_2_2_2_1).
conectado(m5_1_1_2_2_1,m5_1_1_2_2_2).
conectado(m5_1_1_2_2_2,m5_2_1_2_2_2).
conectado(m5_1_1_2_2_2,m5_1_2_2_2_2).
conectado(m5_1_2_0_0_0,m5_2_2_0_0_0).
conectado(m5_1_2_0_0_0,m5_1_2_1_0_0).
conectado(m5_1_2_0_0_0,m5_1_2_0_1_0).
conectado(m5_1_2_0_0_0,m5_1_2_0_0_1).
conectado(m5_1_2_0_0_1,m5_2_2_0_0_1).
conectado(m5_1_2_0_0_1,m5_1_2_1_0_1).
conectado(m5_1_2_0_0_1,m5_1_2_0_1_1).
conectado(m5_1_2_0_0_1,m5_1_2_0_0_2).
conectado(m5_1_2_0_0_2,m5_2_2_0_0_2).
conectado(m5_1_2_0_0_2,m5_1_2_1_0_2).
conectado(m5_1_2_0_0_2,m5_1_2_0_1_2).
conectado(m5_1_2_0_1_0,m5_2_2_0_1_0).
conectado(m5_1_2_0_1_0,m5_1_2_1_1_0).
conectado(m5_1_2_0_1_0,m5_1_2_0_2_0).
conectado(m5_1_2_0_1_0,m5_1_2_0_1_1).
conectado(m5_1_2_0_1_1,m5_2_2_0_1_1).
conectado(m5_1_2_0_1_1,m5_1_2_1_1_1).
conectado(m5_1_2_0_1_1,m5_1_2_0_2_1).
conectado(m5_1_2_0_1_1,m5_1_2_0_1_2).
conectado(m5_1_2_0_1_2,m5_2_2_0_1_2).
conectado(m5_1_2_0_1_2,m5_1_2_1_1_2).
conectado(m5_1_2_0_1_2,m5_1_2_0_2_2).
conectado(m5_1_2_0_2_0,m5_2_2_0_2_0).
conectado(m5_1_2_0_2_0,m5_1_2_1_2_0).
conectado(m5_1_2_0_2_0,m5_1_2_0_2_1).
conectado(m5_1_2_0_2_1,m5_2_2_0_2_1).
conectado(m5_1_2_0_2_1,m5_1_2_1_2_1).
conectado(m5_1_2_0_2_1,m5_1_2_0_2_2).
conectado(m5_1_2_0_2_2,m5_2_2_0_2_2).
conectado(m5_1_2_0_2_2,m5_1_2_1_2_2).
conectado(m5_1_2_1_0_0,m5_2_2_1_0_0).
conectado(m5_1_2_1_0_0,m5_1_2_2_0_0).
conectado(m5_1_2_1_0_0,m5_1_2_1_1_0).
conectado(m5_1_2_1_0_0,m5_1_2_1_0_1).
conectado(m5_1_2_1_0_1,m5_2_2_1_0_1).
conectado(m5_1_2_1_0_1,m5_1_2_2_0_1).
conectado(m5_1_2_1_0_1,m5_1_2_1_1_1).
conectado(m5_1_2_1_0_1,m5_1_2_1_0_2).
conectado(m5_1_2_1_0_2,m5_2_2_1_0_2).
conectado(m5_1_2_1_0_2,m5_1_2_2_0_2).
conectado(m5_1_2_1_0_2,m5_1_2_1_1_2).
conectado(m5_1_2_1_1_0,m5_2_2_1_1_0).
conectado(m5_1_2_1_1_0,m5_1_2_2_1_0).
conectado(m5_1_2_1_1_0,m5_1_2_1_2_0).
conectado(m5_1_2_1_1_0,m5_1_2_1_1_1).
conectado(m5_1_2_1_1_1,m5_2_2_1_1_1).
conectado(m5_1_2_1_1_1,m5_1_2_2_1_1).
conectado(m5_1_2_1_1_1,m5_1_2_1_2_1).
conectado(m5_1_2_1_1_1,m5_1_2_1_1_2).
conectado(m5_1_2_1_1_2,m5_2_2_1_1_2).
conectado(m5_1_2_1_1_2,m5_1_2_2_1_2).
conectado(m5_1_2_1_1_2,m5_1_2_1_2_2).
conectado(m5_1_2_1_2_0,m5_2_2_1_2_0).
conectado(m5_1_2_1_2_0,m5_1_2_2_2_0).
conectado(m5_1_2_1_2_0,m5_1_2_1_2_1).
conectado(m5_1_2_1_2_1,m5_2_2_1_2_1).
conectado(m5_1_2_1_2_1,m5_1_2_2_2_1).
conectado(m5_1_2_1_2_1,m5_1_2_1_2_2).
conectado(m5_1_2_1_2_2,m5_2_2_1_2_2).
conectado(m5_1_2_1_2_2,m5_1_2_2_2_2).
conectado(m5_1_2_2_0_0,m5_2_2_2_0_0).
conectado(m5_1_2_2_0_0,m5_1_2_2_1_0).
conectado(m5_1_2_2_0_0,m5_1_2_2_0_1).
conectado(m5_1_2_2_0_1,m5_2_2_2_0_1).
conectado(m5_1_2_2_0_1,m5_1_2_2_1_1).
conectado(m5_1_2_2_0_1,m5_1_2_2_0_2).
conectado(m5_1_2_2_0_2,m5_2_2_2_0_2).
conectado(m5_1_2_2_0_2,m5_1_2_2_1_2).
conectado(m5_1_2_2_1_0,m5_2_2_2_1_0).
conectado(m5_1_2_2_1_0,m5_1_2_2_2_0).
conectado(m5_1_2_2_1_0,m5_1_2_2_1_1).
conectado(m5_1_2_2_1_1,m5_2_2_2_1_1).
conectado(m5_1_2_2_1_1,m5_1_2_2_2_1).
conectado(m5_1_2_2_1_1,m5_1_2_2_1_2).
conectado(m5_1_2_2_1_2,m5_2_2_2_1_2).
conectado(m5_1_2_2_1_2,m5_1_2_2_2_2).
conectado(m5_1_2_2_2_0,m5_2_2_2_2_0).
conectado(m5_1_2_2_2_0,m5_1_2_2_2_1).
conectado(m5_1_2_2_2_1,m5_2_2_2_2_1).
conectado(m5_1_2_2_2_1,m5_1_2_2_2_2).
conectado(m5_1_2_2_2_2,m5_2_2_2_2_2).
conectado(m5_2_0_0_0_0,m5_2_1_0_0_0).
conectado(m5_2_0_0_0_0,m5_2_0_1_0_0).
conectado(m5_2_0_0_0_0,m5_2_0_0_1_0).
conectado(m5_2_0_0_0_0,m5_2_0_0_0_1).
conectado(m5_2_0_0_0_1,m5_2_1_0_0_1).
conectado(m5_2_0_0_0_1,m5_2_0_1_0_1).
conectado(m5_2_0_0_0_1,m5_2_0_0_1_1).
conectado(m5_2_0_0_0_1,m5_2_0_0_0_2).
conectado(m5_2_0_0_0_2,m5_2_1_0_0_2).
conectado(m5_2_0_0_0_2,m5_2_0_1_0_2).
conectado(m5_2_0_0_0_2,m5_2_0_0_1_2).
conectado(m5_2_0_0_1_0,m5_2_1_0_1_0).
conectado(m5_2_0_0_1_0,m5_2_0_1_1_0).
conectado(m5_2_0_0_1_0,m5_2_0_0_2_0).
conectado(m5_2_0_0_1_0,m5_2_0_0_1_1).
conectado(m5_2_0_0_1_1,m5_2_1_0_1_1).
conectado(m5_2_0_0_1_1,m5_2_0_1_1_1).
conectado(m5_2_0_0_1_1,m5_2_0_0_2_1).
conectado(m5_2_0_0_1_1,m5_2_0_0_1_2).
conectado(m5_2_0_0_1_2,m5_2_1_0_1_2).
conectado(m5_2_0_0_1_2,m5_2_0_1_1_2).
conectado(m5_2_0_0_1_2,m5_2_0_0_2_2).
conectado(m5_2_0_0_2_0,m5_2_1_0_2_0).
conectado(m5_2_0_0_2_0,m5_2_0_1_2_0).
conectado(m5_2_0_0_2_0,m5_2_0_0_2_1).
conectado(m5_2_0_0_2_1,m5_2_1_0_2_1).
conectado(m5_2_0_0_2_1,m5_2_0_1_2_1).
conectado(m5_2_0_0_2_1,m5_2_0_0_2_2).
conectado(m5_2_0_0_2_2,m5_2_1_0_2_2).
conectado(m5_2_0_0_2_2,m5_2_0_1_2_2).
conectado(m5_2_0_1_0_0,m5_2_1_1_0_0).
conectado(m5_2_0_1_0_0,m5_2_0_2_0_0).
conectado(m5_2_0_1_0_0,m5_2_0_1_1_0).
conectado(m5_2_0_1_0_0,m5_2_0_1_0_1).
conectado(m5_2_0_1_0_1,m5_2_1_1_0_1).
conectado(m5_2_0_1_0_1,m5_2_0_2_0_1).
conectado(m5_2_0_1_0_1,m5_2_0_1_1_1).
conectado(m5_2_0_1_0_1,m5_2_0_1_0_2).
conectado(m5_2_0_1_0_2,m5_2_1_1_0_2).
conectado(m5_2_0_1_0_2,m5_2_0_2_0_2).
conectado(m5_2_0_1_0_2,m5_2_0_1_1_2).
conectado(m5_2_0_1_1_0,m5_2_1_1_1_0).
conectado(m5_2_0_1_1_0,m5_2_0_2_1_0).
conectado(m5_2_0_1_1_0,m5_2_0_1_2_0).
conectado(m5_2_0_1_1_0,m5_2_0_1_1_1).
conectado(m5_2_0_1_1_1,m5_2_1_1_1_1).
conectado(m5_2_0_1_1_1,m5_2_0_2_1_1).
conectado(m5_2_0_1_1_1,m5_2_0_1_2_1).
conectado(m5_2_0_1_1_1,m5_2_0_1_1_2).
conectado(m5_2_0_1_1_2,m5_2_1_1_1_2).
conectado(m5_2_0_1_1_2,m5_2_0_2_1_2).
conectado(m5_2_0_1_1_2,m5_2_0_1_2_2).
conectado(m5_2_0_1_2_0,m5_2_1_1_2_0).
conectado(m5_2_0_1_2_0,m5_2_0_2_2_0).
conectado(m5_2_0_1_2_0,m5_2_0_1_2_1).
conectado(m5_2_0_1_2_1,m5_2_1_1_2_1).
conectado(m5_2_0_1_2_1,m5_2_0_2_2_1).
conectado(m5_2_0_1_2_1,m5_2_0_1_2_2).
conectado(m5_2_0_1_2_2,m5_2_1_1_2_2).
conectado(m5_2_0_1_2_2,m5_2_0_2_2_2).
conectado(m5_2_0_2_0_0,m5_2_1_2_0_0).
conectado(m5_2_0_2_0_0,m5_2_0_2_1_0).
conectado(m5_2_0_2_0_0,m5_2_0_2_0_1).
conectado(m5_2_0_2_0_1,m5_2_1_2_0_1).
conectado(m5_2_0_2_0_1,m5_2_0_2_1_1).
conectado(m5_2_0_2_0_1,m5_2_0_2_0_2).
conectado(m5_2_0_2_0_2,m5_2_1_2_0_2).
conectado(m5_2_0_2_0_2,m5_2_0_2_1_2).
conectado(m5_2_0_2_1_0,m5_2_1_2_1_0).
conectado(m5_2_0_2_1_0,m5_2_0_2_2_0).
conectado(m5_2_0_2_1_0,m5_2_0_2_1_1).
conectado(m5_2_0_2_1_1,m5_2_1_2_1_1).
conectado(m5_2_0_2_1_1,m5_2_0_2_2_1).
conectado(m5_2_0_2_1_1,m5_2_0_2_1_2).
conectado(m5_2_0_2_1_2,m5_2_1_2_1_2).
conectado(m5_2_0_2_1_2,m5_2_0_2_2_2).
conectado(m5_2_0_2_2_0,m5_2_1_2_2_0).
conectado(m5_2_0_2_2_0,m5_2_0_2_2_1).
conectado(m5_2_0_2_2_1,m5_2_1_2_2_1).
conectado(m5_2_0_2_2_1,m5_2_0_2_2_2).
conectado(m5_2_0_2_2_2,m5_2_1_2_2_2).
conectado(m5_2_1_0_0_0,m5_2_2_0_0_0).
conectado(m5_2_1_0_0_0,m5_2_1_1_0_0).
conectado(m5_2_1_0_0_0,m5_2_1_0_1_0).
conectado(m5_2_1_0_0_0,m5_2_1_0_0_1).
conectado(m5_2_1_0_0_1,m5_2_2_0_0_1).
conectado(m5_2_1_0_0_1,m5_2_1_1_0_1).
conectado(m5_2_1_0_0_1,m5_2_1_0_1_1).
conectado(m5_2_1_0_0_1,m5_2_1_0_0_2).
conectado(m5_2_1_0_0_2,m5_2_2_0_0_2).
conectado(m5_2_1_0_0_2,m5_2_1_1_0_2).
conectado(m5_2_1_0_0_2,m5_2_1_0_1_2).
conectado(m5_2_1_0_1_0,m5_2_2_0_1_0).
conectado(m5_2_1_0_1_0,m5_2_1_1_1_0).
conectado(m5_2_1_0_1_0,m5_2_1_0_2_0).
conectado(m5_2_1_0_1_0,m5_2_1_0_1_1).
conectado(m5_2_1_0_1_1,m5_2_2_0_1_1).
conectado(m5_2_1_0_1_1,m5_2_1_1_1_1).
conectado(m5_2_1_0_1_1,m5_2_1_0_2_1).
conectado(m5_2_1_0_1_1,m5_2_1_0_1_2).
conectado(m5_2_1_0_1_2,m5_2_2_0_1_2).
conectado(m5_2_1_0_1_2,m5_2_1_1_1_2).
conectado(m5_2_1_0_1_2,m5_2_1_0_2_2).
conectado(m5_2_1_0_2_0,m5_2_2_0_2_0).
conectado(m5_2_1_0_2_0,m5_2_1_1_2_0).
conectado(m5_2_1_0_2_0,m5_2_1_0_2_1).
conectado(m5_2_1_0_2_1,m5_2_2_0_2_1).
conectado(m5_2_1_0_2_1,m5_2_1_1_2_1).
conectado(m5_2_1_0_2_1,m5_2_1_0_2_2).
conectado(m5_2_1_0_2_2,m5_2_2_0_2_2).
conectado(m5_2_1_0_2_2,m5_2_1_1_2_2).
conectado(m5_2_1_1_0_0,m5_2_2_1_0_0).
conectado(m5_2_1_1_0_0,m5_2_1_2_0_0).
conectado(m5_2_1_1_0_0,m5_2_1_1_1_0).
conectado(m5_2_1_1_0_0,m5_2_1_1_0_1).
conectado(m5_2_1_1_0_1,m5_2_2_1_0_1).
conectado(m5_2_1_1_0_1,m5_2_1_2_0_1).
conectado(m5_2_1_1_0_1,m5_2_1_1_1_1).
conectado(m5_2_1_1_0_1,m5_2_1_1_0_2).
conectado(m5_2_1_1_0_2,m5_2_2_1_0_2).
conectado(m5_2_1_1_0_2,m5_2_1_2_0_2).
conectado(m5_2_1_1_0_2,m5_2_1_1_1_2).
conectado(m5_2_1_1_1_0,m5_2_2_1_1_0).
conectado(m5_2_1_1_1_0,m5_2_1_2_1_0).
conectado(m5_2_1_1_1_0,m5_2_1_1_2_0).
conectado(m5_2_1_1_1_0,m5_2_1_1_1_1).
conectado(m5_2_1_1_1_1,m5_2_2_1_1_1).
conectado(m5_2_1_1_1_1,m5_2_1_2_1_1).
conectado(m5_2_1_1_1_1,m5_2_1_1_2_1).
conectado(m5_2_1_1_1_1,m5_2_1_1_1_2).
conectado(m5_2_1_1_1_2,m5_2_2_1_1_2).
conectado(m5_2_1_1_1_2,m5_2_1_2_1_2).
conectado(m5_2_1_1_1_2,m5_2_1_1_2_2).
conectado(m5_2_1_1_2_0,m5_2_2_1_2_0).
conectado(m5_2_1_1_2_0,m5_2_1_2_2_0).
conectado(m5_2_1_1_2_0,m5_2_1_1_2_1).
conectado(m5_2_1_1_2_1,m5_2_2_1_2_1).
conectado(m5_2_1_1_2_1,m5_2_1_2_2_1).
conectado(m5_2_1_1_2_1,m5_2_1_1_2_2).
conectado(m5_2_1_1_2_2,m5_2_2_1_2_2).
conectado(m5_2_1_1_2_2,m5_2_1_2_2_2).
conectado(m5_2_1_2_0_0,m5_2_2_2_0_0).
conectado(m5_2_1_2_0_0,m5_2_1_2_1_0).
conectado(m5_2_1_2_0_0,m5_2_1_2_0_1).
conectado(m5_2_1_2_0_1,m5_2_2_2_0_1).
conectado(m5_2_1_2_0_1,m5_2_1_2_1_1).
conectado(m5_2_1_2_0_1,m5_2_1_2_0_2).
conectado(m5_2_1_2_0_2,m5_2_2_2_0_2).
conectado(m5_2_1_2_0_2,m5_2_1_2_1_2).
conectado(m5_2_1_2_1_0,m5_2_2_2_1_0).
conectado(m5_2_1_2_1_0,m5_2_1_2_2_0).
conectado(m5_2_1_2_1_0,m5_2_1_2_1_1).
conectado(m5_2_1_2_1_1,m5_2_2_2_1_1).
conectado(m5_2_1_2_1_1,m5_2_1_2_2_1).
conectado(m5_2_1_2_1_1,m5_2_1_2_1_2).
conectado(m5_2_1_2_1_2,m5_2_2_2_1_2).
conectado(m5_2_1_2_1_2,m5_2_1_2_2_2).
conectado(m5_2_1_2_2_0,m5_2_2_2_2_0).
conectado(m5_2_1_2_2_0,m5_2_1_2_2_1).
conectado(m5_2_1_2_2_1,m5_2_2_2_2_1).
conectado(m5_2_1_2_2_1,m5_2_1_2_2_2).
conectado(m5_2_1_2_2_2,m5_2_2_2_2_2).
conectado(m5_2_2_0_0_0,m5_2_2_1_0_0).
conectado(m5_2_2_0_0_0,m5_2_2_0_1_0).
conectado(m5_2_2_0_0_0,m5_2_2_0_0_1).
conectado(m5_2_2_0_0_1,m5_2_2_1_0_1).
conectado(m5_2_2_0_0_1,m5_2_2_0_1_1).
conectado(m5_2_2_0_0_1,m5_2_2_0_0_2).
conectado(m5_2_2_0_0_2,m5_2_2_1_0_2).
conectado(m5_2_2_0_0_2,m5_2_2_0_1_2).
conectado(m5_2_2_0_1_0,m5_2_2_1_1_0).
conectado(m5_2_2_0_1_0,m5_2_2_0_2_0).
conectado(m5_2_2_0_1_0,m5_2_2_0_1_1).
conectado(m5_2_2_0_1_1,m5_2_2_1_1_1).
conectado(m5_2_2_0_1_1,m5_2_2_0_2_1).
conectado(m5_2_2_0_1_1,m5_2_2_0_1_2).
conectado(m5_2_2_0_1_2,m5_2_2_1_1_2).
conectado(m5_2_2_0_1_2,m5_2_2_0_2_2).
conectado(m5_2_2_0_2_0,m5_2_2_1_2_0).
conectado(m5_2_2_0_2_0,m5_2_2_0_2_1).
conectado(m5_2_2_0_2_1,m5_2_2_1_2_1).
conectado(m5_2_2_0_2_1,m5_2_2_0_2_2).
conectado(m5_2_2_0_2_2,m5_2_2_1_2_2).
conectado(m5_2_2_1_0_0,m5_2_2_2_0_0).
conectado(m5_2_2_1_0_0,m5_2_2_1_1_0).
conectado(m5_2_2_1_0_0,m5_2_2_1_0_1).
conectado(m5_2_2_1_0_1,m5_2_2_2_0_1).
conectado(m5_2_2_1_0_1,m5_2_2_1_1_1).
conectado(m5_2_2_1_0_1,m5_2_2_1_0_2).
conectado(m5_2_2_1_0_2,m5_2_2_2_0_2).
conectado(m5_2_2_1_0_2,m5_2_2_1_1_2).
conectado(m5_2_2_1_1_0,m5_2_2_2_1_0).
conectado(m5_2_2_1_1_0,m5_2_2_1_2_0).
conectado(m5_2_2_1_1_0,m5_2_2_1_1_1).
conectado(m5_2_2_1_1_1,m5_2_2_2_1_1).
conectado(m5_2_2_1_1_1,m5_2_2_1_2_1).
conectado(m5_2_2_1_1_1,m5_2_2_1_1_2).
conectado(m5_2_2_1_1_2,m5_2_2_2_1_2).
conectado(m5_2_2_1_1_2,m5_2_2_1_2_2).
conectado(m5_2_2_1_2_0,m5_2_2_2_2_0).
conectado(m5_2_2_1_2_0,m5_2_2_1_2_1).
conectado(m5_2_2_1_2_1,m5_2_2_2_2_1).
conectado(m5_2_2_1_2_1,m5_2_2_1_2_2).
conectado(m5_2_2_1_2_2,m5_2_2_2_2_2).
conectado(m5_2_2_2_0_0,m5_2_2_2_1_0).
conectado(m5_2_2_2_0_0,m5_2_2_2_0_1).
conectado(m5_2_2_2_0_1,m5_2_2_2_1_1).
conectado(m5_2_2_2_0_1,m5_2_2_2_0_2).
conectado(m5_2_2_2_0_2,m5_2_2_2_1_2).
conectado(m5_2_2_2_1_0,m5_2_2_2_2_0).
conectado(m5_2_2_2_1_0,m5_2_2_2_1_1).
conectado(m5_2_2_2_1_1,m5_2_2_2_2_1).
conectado(m5_2_2_2_1_1,m5_2_2_2_1_2).
conectado(m5_2_2_2_1_2,m5_2_2_2_2_2).
conectado(m5_2_2_2_2_0,m5_2_2_2_2_1).
conectado(m5_2_2_2_2_1,m5_2_2_2_2_2).

% =========================================================
% TESOUROS
% =========================================================

tesouro(reliquia_norte, m5_2_2_2_2_2,
    [cartao_norte, chave_norte, token_norte]).

tesouro(diamante_sul, m5_0_2_2_2_2,
    [mapa_sul, broca_sul, senha_sul, luva_sul]).

tesouro(coroa_leste, m5_2_0_2_2_2,
    [anel_leste, codigo_leste, cortador_leste, bateria_leste]).

tesouro(arquivo_oeste, m5_2_2_2_2_0,
    [pendrive_oeste, badge_oeste, rota_oeste, decoder_oeste, selo_oeste]).

tesouro(mascara_central, m5_1_1_1_1_1,
    [espelho_central, chave_central, cifra_central, lente_central, cabo_central]).

tesouro(orbe_final, m5_0_1_2_2_2,
    [runa_final, cristal_final, agulha_final, pergaminho_final, motor_final, selo_final]).

% =========================================================
% ITENS
% =========================================================

item(cartao_norte, m5_1_2_1_0_1,
    []).

item(chave_norte, m5_0_2_1_2_2,
    [mini_chave_norte]).

item(mini_chave_norte, m5_1_0_2_1_1,
    []).

item(token_norte, m5_2_1_0_0_0,
    []).

item(mapa_sul, m5_0_0_2_0_0,
    []).

item(broca_sul, m5_2_2_1_1_1,
    [combustivel_sul]).

item(combustivel_sul, m5_2_0_0_0_1,
    []).

item(senha_sul, m5_1_1_1_0_2,
    []).

item(luva_sul, m5_0_1_0_1_0,
    [fibra_sul]).

item(fibra_sul, m5_1_2_2_1_2,
    []).

item(anel_leste, m5_0_2_2_0_1,
    []).

item(codigo_leste, m5_2_1_1_1_2,
    []).

item(cortador_leste, m5_1_0_0_0_0,
    [bateria_leste]).

item(bateria_leste, m5_2_2_2_0_2,
    []).

item(bateria_leste, m5_2_2_2_0_2,
    []).

item(pendrive_oeste, m5_1_1_2_1_0,
    []).

item(badge_oeste, m5_0_1_1_0_2,
    []).

item(rota_oeste, m5_2_0_1_1_0,
    []).

item(decoder_oeste, m5_1_2_0_0_1,
    [chip_oeste]).

item(chip_oeste, m5_2_1_2_0_0,
    []).

item(selo_oeste, m5_0_2_0_1_2,
    [carimbo_oeste]).

item(carimbo_oeste, m5_1_0_1_1_1,
    []).

item(espelho_central, m5_0_0_1_0_0,
    []).

item(chave_central, m5_2_2_0_1_1,
    [pino_central]).

item(pino_central, m5_1_2_1_1_2,
    []).

item(cifra_central, m5_1_1_0_0_2,
    []).

item(lente_central, m5_0_1_2_1_0,
    [polidor_central]).

item(polidor_central, m5_0_2_1_0_1,
    []).

item(cabo_central, m5_2_0_2_0_1,
    []).

item(runa_final, m5_2_1_0_1_2,
    [tinta_final]).

item(tinta_final, m5_2_0_0_1_0,
    []).

item(cristal_final, m5_1_0_2_2_0,
    []).

item(agulha_final, m5_0_0_2_1_1,
    [ima_final]).

item(ima_final, m5_1_2_2_2_1,
    []).

item(pergaminho_final, m5_2_2_1_2_2,
    []).

item(motor_final, m5_1_1_1_1_0,
    [bobina_final]).

item(bobina_final, m5_0_2_2_1_2,
    []).

item(selo_final, m5_0_1_0_2_1,
    []).

% =========================================================
% LIMITE DE TURNOS
% =========================================================

max_turnos(365).
