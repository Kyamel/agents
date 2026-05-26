:- module('agenteG',[detetive_action/3,detetive_preload/5]).


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
