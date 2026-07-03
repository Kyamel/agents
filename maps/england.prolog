% =========================================================
% TESOUROS
% =========================================================

% Os requisitos são compartilhados entre diferentes tesouros.
%
% chave_mestra:
%   joias_da_coroa, arquivos_confidenciais, obra_de_arte
%
% passe_seguranca:
%   arquivos_confidenciais, ouro_do_banco, obra_de_arte
%
% codigo_alarme:
%   joias_da_coroa, ouro_do_banco
%
% disfarce:
%   joias_da_coroa, arquivos_confidenciais
%
% mapa_tuneis:
%   ouro_do_banco, obra_de_arte

tesouro(joias_da_coroa, tower_of_london,
    [
        chave_mestra,
        codigo_alarme,
        disfarce
    ]).

tesouro(arquivos_confidenciais, scotland_yard,
    [
        chave_mestra,
        passe_seguranca,
        disfarce
    ]).

tesouro(ouro_do_banco, liverpool_street,
    [
        codigo_alarme,
        passe_seguranca,
        mapa_tuneis
    ]).

tesouro(obra_de_arte, covent_garden,
    [
        chave_mestra,
        passe_seguranca,
        mapa_tuneis
    ]).


% =========================================================
% ITENS
% =========================================================

% Itens principais usados diretamente nos roubos.

item(chave_mestra, baker_street,
    [jogo_gazuas]).

item(codigo_alarme, whitechapel,
    [radio_policial]).

item(passe_seguranca, victoria_station,
    [documento_falso]).

item(disfarce, camden_town,
    [documento_falso]).

item(mapa_tuneis, waterloo_station,
    [radio_policial]).


% Itens auxiliares.
%
% documento_falso é necessário para:
%   passe_seguranca e disfarce
%
% radio_policial é necessário para:
%   codigo_alarme e mapa_tuneis

item(jogo_gazuas, soho,
    []).

item(documento_falso, piccadilly_circus,
    []).

item(radio_policial, kings_cross,
    []).


% =========================================================
% CIDADES
% =========================================================

cidade(baker_street).
cidade(scotland_yard).
cidade(westminster).
cidade(victoria_station).
cidade(trafalgar_square).
cidade(charing_cross).
cidade(piccadilly_circus).
cidade(oxford_circus).
cidade(soho).
cidade(covent_garden).
cidade(waterloo_station).
cidade(london_bridge).
cidade(tower_of_london).
cidade(liverpool_street).
cidade(whitechapel).
cidade(kings_cross).
cidade(camden_town).
cidade(regents_park).
cidade(paddington_station).
cidade(hyde_park).


% =========================================================
% CONEXOES
% =========================================================

% Região noroeste e centro-norte

conectado(baker_street, regents_park).
conectado(baker_street, oxford_circus).
conectado(baker_street, paddington_station).
conectado(baker_street, kings_cross).

conectado(kings_cross, camden_town).
conectado(kings_cross, regents_park).
conectado(kings_cross, covent_garden).
conectado(kings_cross, liverpool_street).

conectado(camden_town, regents_park).

conectado(regents_park, oxford_circus).
conectado(regents_park, soho).
conectado(regents_park, paddington_station).

conectado(paddington_station, hyde_park).


% Região oeste e centro

conectado(hyde_park, oxford_circus).
conectado(hyde_park, victoria_station).

conectado(oxford_circus, piccadilly_circus).
conectado(oxford_circus, soho).

conectado(piccadilly_circus, soho).
conectado(piccadilly_circus, trafalgar_square).
conectado(piccadilly_circus, victoria_station).

conectado(soho, covent_garden).


% Região governamental e centro-sul

conectado(scotland_yard, westminster).
conectado(scotland_yard, victoria_station).
conectado(scotland_yard, trafalgar_square).

conectado(victoria_station, westminster).

conectado(westminster, trafalgar_square).
conectado(westminster, waterloo_station).

conectado(trafalgar_square, charing_cross).
conectado(trafalgar_square, covent_garden).

conectado(charing_cross, covent_garden).
conectado(charing_cross, waterloo_station).


% Região sul e leste

conectado(waterloo_station, london_bridge).

conectado(covent_garden, london_bridge).

conectado(london_bridge, tower_of_london).
conectado(london_bridge, liverpool_street).

conectado(tower_of_london, liverpool_street).
conectado(tower_of_london, whitechapel).

conectado(liverpool_street, whitechapel).