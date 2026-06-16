% =========================================================
%  CENARIO 1
%
%  10 cidades
%  3 tesouros
%  Cadeias de requisitos
%  10 suspeitos
%  5 caracteristicas por suspeito
% =========================================================

:- dynamic item/3.
:- dynamic tesouro/3.
:- dynamic roubado/2.

% =========================================================
% SUSPEITOS
% =========================================================

procurado(0,'Helena Fox',
    aparencia([
        altura(alta),
        genero(gen2),
        cor_olhos(verde),
        cor_cabelo(preto),
        marca(cicatriz_rosto)
    ])).

procurado(1,'Victor Graves',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(castanho),
        cor_cabelo(loiro),
        nariz(longo)
    ])).

procurado(2,'Luna Mirage',
    aparencia([
        altura(baixa),
        genero(gen2),
        cor_olhos(azul),
        cor_cabelo(ruivo),
        tatuagem(braco_direito)
    ])).

procurado(3,'Dante Crow',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(escuro),
        cor_cabelo(preto),
        barba
    ])).

procurado(4,'Selene Noir',
    aparencia([
        altura(media),
        genero(gen2),
        cor_olhos(verde),
        cor_cabelo(castanho),
        piercing(nariz)
    ])).

procurado(5,'Otto Kane',
    aparencia([
        altura(alta),
        genero(gen1),
        cor_olhos(azul),
        cor_cabelo(grisalho),
        marca(tatuagem_pescoco)
    ])).

procurado(6,'Bianca Vale',
    aparencia([
        altura(baixa),
        genero(gen2),
        cor_olhos(castanho),
        cor_cabelo(preto),
        oculos
    ])).

procurado(7,'Marcus Reed',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(verde),
        cor_cabelo(ruivo),
        nariz(curto)
    ])).

procurado(8,'Nina Frost',
    aparencia([
        altura(alta),
        genero(gen2),
        cor_olhos(azul),
        cor_cabelo(loiro),
        cicatriz(sobrancelha)
    ])).

procurado(9,'Edgar Wolfe',
    aparencia([
        altura(media),
        genero(gen1),
        cor_olhos(escuro),
        cor_cabelo(castanho),
        atletico
    ])).

% =========================================================
% CIDADES
% =========================================================

cidade(a).
cidade(b).
cidade(c).
cidade(d).
cidade(e).
cidade(f).
cidade(g).
cidade(h).
cidade(i).
cidade(j).

% =========================================================
% CONEXOES
% =========================================================

conectado(a,b).
conectado(a,c).

conectado(b,d).
conectado(b,e).

conectado(c,f).
conectado(c,g).

conectado(d,h).
conectado(e,h).

conectado(f,i).
conectado(g,i).

conectado(h,j).
conectado(i,j).

conectado(e,f).
conectado(d,g).

% =========================================================
% TESOUROS
% =========================================================

% tesouro(Nome, Cidade, Requisitos)

tesouro(coroa_real, j,
    [chave_real, codigo_cofre, luvas_laser, mapa_sigilo]).

tesouro(diamante_azul, h,
    [cartao_magnetico, broca_termica, senha_banco]).

tesouro(reliquia_antiga, i,
    [amuleto_sagrado, pergaminho, chave_catacumba,
     lanterna_uv, pe_de_cabra]).

% =========================================================
% ITENS
% =========================================================

item(chave_real, d,
    [mini_chave]).

item(codigo_cofre, e,
    []).

item(luvas_laser, b,
    [bateria]).

item(mapa_sigilo, c,
    []).

item(cartao_magnetico, f,
    []).

item(broca_termica, g,
    [combustivel]).

item(senha_banco, a,
    []).

item(amuleto_sagrado, h,
    [livro_ritual]).

item(pergaminho, i,
    []).

item(chave_catacumba, j,
    [gazua]).

item(lanterna_uv, c,
    []).

item(pe_de_cabra, e,
    []).

% =========================================================
% SUB-REQUISITOS
% =========================================================

item(mini_chave, a,
    []).

item(bateria, d,
    []).

item(combustivel, b,
    []).

item(livro_ritual, f,
    []).

item(gazua, g,
    []).

% =========================================================
% LIMITE DE TURNOS
% =========================================================

max_turnos(28).
