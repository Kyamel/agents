%  a ----- b
%  |       |
%  |       |
%  c-------d----e
%

:- dynamic item/3.
:- dynamic tesouro/3.
:- dynamic roubado/2.

procurado(0,'Dick Vigarista' , aparencia([altura(180), genero(gen1), corpulento, cor_olhos(escuro), cor_cabelo(escuro), ton_pele(cor1), nariz(longo), marca(bochecha_esqerda)] )).
procurado(1,'Penelope Mao Leve', aparencia([altura(120), genero(gen2), magro, cor_olhos(amarelo), cor_cabelo(escuro), ton_pele(cor2), nariz(curto), cicatriz(sobrancelha_esquerda) ] )).
procurado(2,'Clepto Maniaco', aparencia([altura(160), genero(gen1), atletico, cor_olhos(verde), cor_cabelo(castanho), ton_pele(cor2), nariz(medio), tatuagem(testa)] )).

cidade(a).
cidade(b).
cidade(c).
cidade(d).
cidade(e).

conectado(a,b).
conectado(a,c).
conectado(b,d).
conectado(c,b).
conectado(d,e).
conectado(d,c).


% tesouro(NomeDoItem, Cidade, Lista de pré-requsitos)
% item(NomeDoItem, Cidade, Lista de pré-requsitos)

tesouro(cx_joias,a,[chave]).
item(chave,c,[cartao_cofre]).
item(cartao_cofre,e,[]).


max_turnos(20). %% 12* (6^2) = 432
