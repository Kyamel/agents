:- module('agenteL',[ladrao_action/3,ladrao_preload/7]).


ladrao_preload(_, %Grafo
                  _, % Lista de Suspeitos
                  _, % Lista de Itens
                  _, % Lista de Tesouros,
                  pronto,
                  0, %ID do ladrão.
                  cx_joias). % obj do ladrão.


%ladrao_action(Evnts,     Lista de eventos
%              thief(loc(a),
%                     0,
%                     aparencia(_),
%                     cx_joias,
%                     [],
%                     Dsg) ,
%                     move(a,c)).


ladrao_action(Evnts, thief(loc(a),0,aparencia(_),cx_joias,[],Dsg) , move(a,c)).
ladrao_action(Evnts, thief(loc(b),0,aparencia(_),cx_joias,[],Dsg) , move(b,d)).
ladrao_action(Evnts, thief(loc(c),0,aparencia(_),cx_joias,[],Dsg) , move(c,d)).
ladrao_action(Evnts, thief(loc(d),0,aparencia(_),cx_joias,[],Dsg) , move(d,e)).
ladrao_action(Evnts, thief(loc(e),0,aparencia(_),cx_joias,[],Dsg) ,roubar('cartao_cofre')).
ladrao_action(Evnts, thief(loc(e),0,aparencia(_),cx_joias,IS,Dsg) ,move(e,d) ) :- member('cartao_cofre',IS).
ladrao_action(Evnts, thief(loc(d),0,aparencia(_),cx_joias,[_],Dsg) ,move(d,c) ).
ladrao_action(Evnts, thief(loc(c),0,aparencia(_),cx_joias,[_],Dsg) ,roubar(chave) ).
ladrao_action(Evnts, thief(loc(c),0,aparencia(_),cx_joias,[_,_],Dsg) , move(c,a)).
ladrao_action(Evnts, thief(loc(a),0,aparencia(_),cx_joias,[_,_],Dsg) , roubar('cx_joias')).
ladrao_action(Evnts, thief(loc(a),0,aparencia(_),cx_joias,[_,_,_],Dsg) , move(a,b)).
