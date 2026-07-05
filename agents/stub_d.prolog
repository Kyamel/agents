% ============================================================
% DETETIVE: stub_d
%
% Stub minimo (exemplo/template). Regra fixa e hardcoded: se vir um
% roubo na cidade `e`, fecha a cidade `d`; caso contrario, nao faz nada.
% Nao generaliza para nenhum mapa — serve so como esqueleto de interface
% detetive_preload/detetive_action.
% ============================================================

:- module(stub_d,[detetive_action/3,detetive_preload/5]).


detetive_preload(_, %Grafo
                  _, % Lista de Suspeitos
                  _, % Lista de Itens
                  _, % Lista de Tesouros,
                  pronto).
%%Events lista de roubo(Item,Cidade,[AS])
%% AS é uma lista de algumas (pelo menos uma) características do ladrão.

detetive_action([],detective(_,_,_), nada).
detetive_action([roubo(_,e,_)],detective(_,_,_), fechar(d)).
detetive_action(_,detective(_,_,_), nada).
