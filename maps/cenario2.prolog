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

procurado(0,'L1',
    aparencia([
        altura(alto),
        genero(f),
        cor_olhos(verde),
        cor_cabelo(preto),
        cicatriz(orelha),
        pinta(bochehca),
        queixo_furado,
        corte(orlha_direita)
    ])).



procurado(1,'L2',
    aparencia([
        altura(alt0),
        genero(f),
        cor_olhos(verde),
        cor_cabelo(preto),
        cicatriz(orelha),
        pinta(bochehca),
        queixo_furado,
        corte(orlha_esquerda)
    ])).


procurado(2,'L3',
    aparencia([
        altura(alto),
        genero(f),
        cor_olhos(verde),
        cor_cabelo(preto),
        cicatriz(orelha),
        pinta(bochehca),
        queixo_furado,
        torto(dedo_mindinho_esquerdo)
    ])).


procurado(3,'L4',
    aparencia([
        altura(alto),
        genero(f),
        cor_olhos(verde),
        cor_cabelo(preto),
        cicatriz(orelha),
        pinta(bochehca),
        queixo_furado,
        torto(dedo_mindinho_direito)
    ])).


procurado(4,'N1',
    aparencia([
        altura(media),
        genero(m),
        cor_olhos(castanhos),
        cor_cabelo(preto),
        marca(bochecha_esquerda),
        pinta(orelha_direita),
        bigode,
        nariz(curto)
    ])).


procurado(5,'N2',
    aparencia([
        altura(media),
        genero(m),
        cor_olhos(castanhos),
        cor_cabelo(preto),
        marca(bochecha_esquerda),
        pinta(orelha_direita),
        bigode,
        nariz(longo)
    ])).


procurado(6,'N3',
    aparencia([
        altura(media),
        genero(m),
        cor_olhos(castanhos),
        cor_cabelo(preto),
        marca(bochecha_esquerda),
        pinta(orelha_direita),
        bigode,
        nariz(chato)
    ])).


procurado(7,'N4',
    aparencia([
        altura(media),
        genero(m),
        cor_olhos(castanhos),
        cor_cabelo(preto),
        marca(bochecha_esquerda),
        pinta(orelha_direita),
        bigode,
        mancha(testa)
    ])).


% =========================================================
% CIDADES
% =========================================================

cidade(alija).
cidade(lior).
cidade(cidade_do_leste).
cidade(kakarico).
cidade(mindrel).
cidade(shindrel).
cidade(springfield).
cidade(arkham).
cidade(biquini_atoll).
cidade(relyeh).
cidade(zion).
cidade(south_park).
cidade(springwood).
cidade(crystal_lake).
cidade(amityville).
cidade(gotham).
cidade(smallvile).
cidade(mainframe).
cidade(hill_valley).
cidade(gondor).




% =========================================================
% CONEXOES
% =========================================================

conectado(alija, lior).
conectado(alija, cidade_do_leste).
conectado(alija, kakarico).
conectado(alija, mindrel).
conectado(alija, shindrel).
conectado(lior, cidade_do_leste).
conectado(lior, kakarico).
conectado(lior, mindrel).
conectado(lior, shindrel).
conectado(cidade_do_leste, kakarico).
conectado(cidade_do_leste, mindrel).
conectado(cidade_do_leste, shindrel).
conectado(kakarico, mindrel).
conectado(kakarico, shindrel).
conectado(mindrel, shindrel).
conectado(springfield, arkham).
conectado(springfield, biquini_atoll).
conectado(springfield, relyeh).
conectado(arkham, biquini_atoll).
conectado(arkham, relyeh).
conectado(biquini_atoll, relyeh).
conectado(springfield, zion).
conectado(springfield, south_park).
conectado(arkham, zion).
conectado(arkham, south_park).
conectado(zion, south_park).
conectado(amityville, springfield).
conectado(amityville, arkham).
conectado(amityville, gotham).
conectado(gotham, biquini_atoll).
conectado(gotham, relyeh).
conectado(smallvile, zion).
conectado(smallvile, south_park).
conectado(smallvile, mainframe).
conectado(mainframe, springwood).
conectado(mainframe, crystal_lake).
conectado(hill_valley, alija).
conectado(hill_valley, gondor).
conectado(hill_valley, mainframe).
conectado(gondor, lior).
conectado(gondor, amityville).
conectado(crystal_lake, mindrel).
conectado(springwood, smallvile).
conectado(crystal_lake, hill_valley).
conectado(arkham, hill_valley).
conectado(shindrel, gotham).
conectado(springwood, cidade_do_leste).

% =========================================================
% TESOUROS
% =========================================================

% tesouro(Nome, Cidade, Requisitos)
tesouro(coroa_real,alija,[chave_real]).
tesouro(livro_das_sombras,arkham,[cristal_magico]).
tesouro(espada_sagrada,cidade_do_leste,[pergaminho_sagrado]).
tesouro(cetro_imperial,springfield,[reliquia_antiga]).
tesouro(cristal_ancestral,shindrel,[codigo_final]).

% =========================================================
% ITENS
% =========================================================
item(gazua,crystal_lake,[]).

item(pe_de_cabra,
     springwood,
     [gazua]).

item(cartao_mestre,
     hill_valley,
     [pe_de_cabra]).

item(mochila,
     mainframe,
     [cartao_mestre]).

     item(kit_escavacao,
     gondor,
     [mochila]).

item(detector_metal,
     mindrel,
     [kit_escavacao]).

item(mapa_antigo,
     kakarico,
     [detector_metal]).

item(kit_hacker,
     gotham,
     [mochila]).

item(notebook,
     amityville,
     [kit_hacker]).

item(senha_mestra,
     south_park,
     [notebook]).

item(selo_real,
     lior,
     [mapa_antigo]).

item(chave_digital,
     zion,
     [senha_mestra]).

item(amuleto,
     arkham,
     [selo_real,
      chave_digital]).

item(rota_norte,
     springfield,
     [amuleto]).

item(rota_sul,
     biquini_atoll,
     [amuleto]).

item(rota_leste,
     relyeh,
     [amuleto]).

item(chave_real,
     alija,
     [rota_norte]).

tesouro(coroa_real,
         alija,
         [chave_real]).

item(cristal_magico,
     shindrel,
     [rota_sul]).

tesouro(livro_das_sombras,
         arkham,
         [cristal_magico]).

item(pergaminho_sagrado,
     cidade_do_leste,
     [rota_leste]).

tesouro(espada_sagrada,
         cidade_do_leste,
         [pergaminho_sagrado]).

tesouro(cetro_imperial,
         springfield,
         [reliquia_antiga]).

tesouro(cristal_ancestral,
         shindrel,
         [codigo_final]).

% =========================================================
% LIMITE DE TURNOS
% =========================================================

max_turnos(200).
