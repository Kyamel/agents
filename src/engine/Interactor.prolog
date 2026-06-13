
:- dynamic fechado/1.
:- dynamic pistas/3.
:- dynamic roubo_pendente/2.

insert(X,[],[X]).
insert(X,[Y|YS],[X,Y|YS]).
insert(X,[Y|YS],[Y|ZS]) :- insert(X,YS,ZS).

diff([],_,[]) :- !.
diff(XS,[],XS) :- !.
diff([X|XS],YS,WS) :- insert(X,ZS,YS),!,diff(XS,ZS,WS).
diff([X|XS],YS,ZS) :- diff(XS,YS,[X|ZS]).

allGround([]).
allGround([X|XS]) :- ground(X), !, allGround(XS).

% estadoDetetive(loc,Mandato,Pistas)

validarDisfarce([],_).
validarDisfarce([ trocar(X,Y) | Ls],Attrs ) :- ground(X),ground(Y), member(X,Attrs), functor(X,F,K), functor(Y,F,K), !, validarDisfarce(Ls,Attrs).
validarDisfarce([ omitir(X) | Ls],Attrs ) :- ground(X),member(X,Attrs),!, validarDisfarce(Ls,Attrs).
validarDisfarce([ adicionar(X) | Ls],Attrs ) :- ground(X), \+member(X,Attrs), !,validarDisfarce(Ls,Attrs).


validar(move(A,B),thief(loc(A),_,_,_,_,_),t)  :- atomic(A), atomic(B), cidade(A), cidade(B),(conectado(A,B);conectado(B,A)),!.
validar(roubar(I),thief(loc(A),_,_,_,YS,_),t) :- atomic(A), cidade(A), ground(I), tesouro(I,A,XS), diff(XS,YS,[]),!.
validar(roubar(I),thief(loc(A),_,_,_,YS,_),t) :- atomic(A), cidade(A), ground(I), item(I,A,XS), diff(XS,YS,[]),!.
validar(disfarce(Ls),thief(_,_,aparencia(Atts),_,_,N),t) :- N > 0, allGround(Ls), length(Ls,K), K =< N, allGround(Atts), validarDisfarce(Ls,Atts), !.
validar(despir_disfarce,thief(_,_,_,_,_,_),t).

validar(move(A,B),detective(loc(A),_,_),t) :- atomic(A), atomic(B), cidade(A),cidade(B),(conectado(A,B);conectado(B,A)),!.
validar(pedir_mandato(S,Atts),detective(_,_,PS),t) :- number(S),
                                                          allGround(Atts),
                                                          diff(Atts,PS,[]),
                                                          suspects(Atts,TS),
                                                          length(TS,K),
                                                          K =< 2,
                                                          member(S,TS),!.
validar(inspecionar,detective(loc(A),_,_),t) :- atomic(A),cidade(A),!.
validar(fechar(C),detective(_,_,_),t)  :- atomic(C),cidade(C),!.
validar(liberar(C),detective(_,_,_),t) :- atomic(C),cidade(C),!.
validar(nada,_,t).
validar(state,_,t).
validar(_,_,f).


action(move(A,B),thf, GameSt, GameSt1) :-
       getSt(thf,GameSt,thief(loc(A),Id,Appear,Target,Itens,Dsg)),
       (getlocks(GameSt,Lck),
        member(A,Lck),!,
        caugth(GameSt,GameSt1);
        setSt(thf,thief(loc(B),Id,Appear,Target,Itens,Dsg),GameSt,GameSt1)).

action(roubar(I),thf , GSt ,GSt1) :-
  getSt(thf,GSt,thief(loc(A),Id,Appear,Target,XS,Dsg)),
  item(I,A,_),!,
  retract(item(I,A,_)),
  setSt(thf,thief(loc(A),Id,Appear,Target,[I|XS],Dsg),GSt,TMP),
  aparencia(AS) = Appear,
  length(XS,NR),
  length(AS,K),
  N is min(NR+1,K),
  takeAttr(N,AS,ZS),
  atrasarEventoRoubo(roubo(I,A,ZS)),
  GSt1 = TMP.

action(roubar(I),thf , GSt ,GSt1) :-
  getSt(thf,GSt,thief(loc(A),Id,Appear,Target,XS,Dsg)),
  tesouro(I,A,WS),!,
  retract(tesouro(I,A,WS)),
  assertz(roubado(I,A)),
  setSt(thf,thief(loc(A),Id,Appear,Target,[I|XS],Dsg),GSt,TMP),
  aparencia(AS) = Appear,
  length(XS,NR),
  length(AS,K),
  N is min(NR+1,K),
  takeAttr(N,AS,ZS),
  atrasarEventoRoubo(roubo(I,A,ZS)),
  GSt1 = TMP.


action(disfarce(LS),thf, GSt, GSt1) :-
   getSt(thf,GSt,thief(L,Id,aparencia(AS),Target,Itens,Dsg)),
   vestir(LS,AS,AS1),
   Dsg1 is Dsg-1,
   setSt(thf,thief(L,Id,aparencia(AS1),Target,Itens,Dsg1),GSt,GSt1).

action(despir_disfarce,thf, GSt, GSt1) :-
   getSt(thf,GSt,thief(L,Id,aparencia(AS),Target,Itens,Dsg)),
   despir(AS,AS1),
   setSt(thf,thief(L,Id,aparencia(AS1),Target,Itens,Dsg),GSt,GSt1).


action(move(A,B),det, GameSt, GameSt1) :-  getSt(det,GameSt,detective(loc(A),Mand,Clues)),
                                           setSt(det,detective(loc(B),Mand,Clues),GameSt,GameSt1).
action(inspecionar,det,GSt, GSt1) :-
   getSt(det,GSt,detective(loc(A),M,Clues)),
   getSt(thf,GSt,thief(loc(B),Id,_,_,_,_)),
   (A = B,
    M = mandato(Id),!,
    caugth(GSt,GSt1)
    ;
    setSt(det,detective(loc(A),M,Clues),GSt,GSt1)).

action(fechar(C),det,gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt,Tobj,[C|Locks],BOs,Caugth,Turn)) :- \+member(C,Locks),!.
action(fechar(C),det,gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn)) :- member(C,Locks),!.
action(liberar(C),det,gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt,Tobj,Locks1,BOs,Caugth,Turn)) :-
           append(XS,[C|YS],Locks),!,
           append(XS,YS,Locks1).
action(liberar(C),det,gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn)) :- \+member(C,Locks),!.

action(pedir_mandato(S,_),det,Gst,Gst1) :-
    getSt(det,Gst,detective(L,nenhum,Clues)),
    setSt(det,detective(L,mandato(S),Clues),Gst,Gst1).

action(nada,_,GSt,GSt).

getSt(thf, gSt(TSt, _,_,_,_,_,_),TSt).
getSt(det, gSt( _ ,Dst,_,_,_,_,_),Dst).
turnos(gSt( _ ,_,_,_,_,_,T),T).
setSt(thf,TSt1, gSt(_,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt1,DSt,Tobj,Locks,BOs,Caugth,Turn)).
setSt(det,DSt1, gSt(TSt,_,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt1,Tobj,Locks,BOs,Caugth,Turn)).
caugth(gSt(TSt,DSt,Tobj,Locks,BOs,_,Turn),gSt(TSt,DSt,Tobj,Locks,BOs,capturado,Turn) ).
stepTurn(gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn),gSt(TSt,DSt,Tobj,Locks,BOs,Caugth,Turn1)) :- Turn > 0, Turn1 is Turn -1.
getEvents(gSt(_,_,_,_,EV,_,_),EV).

% ALTERACAO: eventos de roubo agora tem delay de um turno do ladrao.
% O roubo nao entra em BOs imediatamente; ele fica pendente no turno em que
% acontece e so e publicado depois da proxima acao do ladrao, antes da acao do
% detetive. Ex.: ladrao rouba no turno 20, detetive nao ve no 20; ladrao age no
% turno 19, entao o roubo do turno 20 passa a ficar visivel ao detetive.
atrasarEventoRoubo(E) :-
   assertz(roubo_pendente(E,2)).

publicarEventosPendentes(GSt,GSt1) :-
   findall(E-D,roubo_pendente(E,D),Pendentes),
   retractall(roubo_pendente(_,_)),
   publicarEventosPendentes_(Pendentes,GSt,GSt1).

publicarEventosPendentes_([],GSt,GSt).
publicarEventosPendentes_([E-D|Ps],GSt,GSt2) :-
   (D =< 1,
    !,
    emitirEvento(GSt,E,GSt1)
   ;
    D1 is D - 1,
    assertz(roubo_pendente(E,D1)),
    GSt1 = GSt
   ),
   publicarEventosPendentes_(Ps,GSt1,GSt2).

emitirEvento(gSt(TSt,detective(L,M,CS),Tobj,Locks,BOs,Caugth,Turn),E,gSt(TSt,detective(L,M,CS1),Tobj,Locks,[E|BOs],Caugth,Turn)) :-
   collect(E,ZS),
   write('\n  >>>> Evento '), write(E), nl,
   union(CS,ZS,CS1).

getlocks(gSt(_,_,_,Locks,_,_,_),Locks).
getCaugth(gSt(_,_,_,_,_,C,_),C).

% gSt(ThiefSt,DetectiveSt,ThiefObj,Locks,BOs,Caugth,Turn)
%
% Aparência do Ladrão:
% aparencia(altura(180), {magro,corpulento,atletico}, attribtos )
%
%

functors([],[]).
functors([L|LS],[F|ZS]) :- functor(L,F,_),!,functors(LS,ZS).


attrZiper(AName,Value,AS,XS,ZS) :- Z =.. [AName,Value],
                                    append(XS,[Z|ZS],AS).


vestir([],XS,XS).
vestir([adicionar(X)|Ds],AS,[disfarce(X,none)|AS1]) :- !,vestir(Ds,AS,AS1).
vestir([trocar(X,Y)|Ds],AS,AS1) :-  X =.. [Aname,Avalue],
                                    attrZiper(Aname,Avalue,AS,PREV,NEXT),
                                    append(PREV,[disfarce(Y,X)|NEXT],TEMP),
                                    !,vestir(Ds,TEMP,AS1).
vestir([omitir(X)|Ds],AS,AS1) :-  X =.. [Aname,Avalue],
                                    attrZiper(Aname,Avalue,AS,PREV,NEXT),
                                    append(PREV,[disfarce(none,X)|NEXT],TEMP),
                                    !,vestir(Ds,TEMP,AS1).
vestir([_|Ds],AS,AS1) :- vestir(Ds,AS,AS1).



despir([],[]):- !.
despir([disfarce(_,none)|XS],ZS):- !, despir(XS,ZS).
despir([disfarce(_,Y)|XS],[Y|ZS]):- !, despir(XS,ZS).
despir([X|XS],[X|ZS]):- !, despir(XS,ZS).


suspects(Atts,TS) :- findall(I,matchSuspect(Atts,I),TS).
matchSuspect(Atts, I) :- procurado(I,_,aparencia(XS)), diff(Atts,XS,[]).

collect(roubo(_,_,ZS),ZS).


takeAttr(_,[],[]).
takeAttr(0,[_|_],[]).
takeAttr(N,[disfarce(X,_)|XS],[X|YS]) :- N > 0, K is N -1, !, takeAttr(K,XS,YS).
takeAttr(N,[X|XS],[X|YS]) :- N > 0, K is N -1, takeAttr(K,XS,YS).

loadCenario(C) :- atomic(C),
                  name(C,XS),
                  name('.prolog',E),
                  append(XS,E,YS),
                  name(FN,YS),
                  consult(FN).


gameStart(Cenario,Qdis,ThfModule,DetModule,State,V) :-
    retractall(roubo_pendente(_,_)),
    loadCenario(Cenario),
    loadThiefAgent(ThfModule),
    loadDetectiveAgent(DetModule),
    setof(X,cidade(X),CS),
    findall(adj(X,Y), conectado(X,Y), G),
    findall(procurado(ID,AP),procurado(ID,_,AP), SUS),
    findall(item(I,C,XS),item(I,C,XS),Itens),
    findall(tesouro(I,C,XS),tesouro(I,C,XS),Tesouros),
    % write('Graph'),nl, write(G),nl,
    % write('Sus'),nl, write(SUS),nl,
    % write('Intens'),nl, write(Itens),nl,
    % write('Tesouros'),nl, write(Tesouros),nl,
    detetive_preload(G,SUS,Itens,Tesouros,pronto),
    ladrao_preload(G,SUS,Itens,Tesouros,pronto,ThiefID,ThiefObj),!,
    buildInitalState(CS,ThiefID,ThiefObj,Qdis,State),
    agentMove(thf,State,V).

idx(0,[X|_],X) :- !.
idx(N,[_|XS],X) :- N > 0,!, M is N - 1, idx(M,XS,X).

buildInitalState(CS,ThiefID,ThiefObj, Qdis,State)
    :- length(CS,K),
       K1 is K-1,
       random_between(0,K1,R),
       random_between(0,K1,R1),
       idx(R,CS,C1),
       idx(R1,CS,C2),
       procurado(ThiefID,_,AP),
       ThSt = thief(loc(C1),ThiefID,AP,ThiefObj,[],Qdis),
       DSt = detective(loc(C2),nenhum,[]),
       max_turnos(MT),
       State=gSt(ThSt,DSt,ThiefObj,[],[],livre,MT).

loadThiefAgent(ThfModule) :- atomic(ThfModule), use_module(ThfModule).
loadDetectiveAgent(DetModule) :- atomic(DetModule), use_module(DetModule).


agentMove(_,S,V) :- termino(S,V),!.
agentMove(thf,S,V) :-
       getSt(thf,S,TSt),
       getEvents(S,EV),
       (ladrao_action(EV,TSt,A),!; A=nada),!,
       validar(A,TSt,R),
       turnos(S,T),
       (R = t, !, action(A,thf,S,S1) ,logar(T,thf,A,'OK') ; logar(T,thf,A,'Ilegal'),S1 = S),!,
       publicarEventosPendentes(S1,S2),!,
       agentMove(det,S2,V).

agentMove(det,S,V) :-
       getSt(det,S,DSt),
       getEvents(S,EV),
       (detetive_action(EV,DSt,A),!; A=nada),!,
       validar(A,DSt,R),
       turnos(S,T),
       (R=t,!,action(A,det,S,S1) ,logar(T,det,A,'OK'); logar(T,det,A,'Ilegal'), S1=S),
       stepTurn(S1,S2),!,
       agentMove(thf,S2,V).


logar(N,det,A,OBS) :- write(N),write(' '),write('detetive: '),write(A),write('['),write(OBS), write(']'),nl.
logar(N,thf,A,OBS) :- write(N),write(' '),write('ladrao: '),write(A),write('['),write(OBS), write(']'),nl.

termino(gSt(_,_,_,_,_,livre,0),empate) :- !.
termino(gSt(_,_,_,_,_,capturado,_),detetive) :- !.
termino(gSt(thief(loc(C),_,_,Target,Itens,_),_,_,_,_,_,_),ladrao):- roubado(Target,C1), C \= C1, member(Target,Itens).
