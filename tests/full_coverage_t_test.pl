:- begin_tests(full_coverage_t).

:- use_module('../agents/full_coverage_t').

reset_agents :-
    full_coverage_t:limpar_memoria.

single_suspect([
    procurado(
        0,
        'Teste',
        aparencia([
            altura(alta),
            genero(gen1),
            cor_olhos(verde),
            marca(cicatriz)
        ])
    )
]).

test(ignores_treasures_with_missing_dependencies,
     [setup(reset_agents), cleanup(reset_agents)]) :-
    Graph = [adj(a, b)],
    single_suspect(Suspects),
    Items = [item(chave, b, [])],
    Treasures = [
        tesouro(quebrado, a, [inexistente]),
        tesouro(valido, b, [chave]),
        tesouro(valido, b, [chave])
    ],
    full_coverage_t:ladrao_preload(
        Graph,
        Suspects,
        Items,
        Treasures,
        pronto,
        Id,
        Target
    ),
    assertion(Id == 0),
    assertion(Target == valido),
    State = thief(
        loc(a),
        Id,
        aparencia([altura(alta)]),
        Target,
        [],
        0
    ),
    full_coverage_t:ladrao_action([], State, Action),
    assertion(Action == move(a, b)).

test(disguise_uses_full_budget,
     [setup(reset_agents), cleanup(reset_agents)]) :-
    Graph = [adj(a, b)],
    single_suspect(Suspects),
    Items = [item(chave, b, [])],
    Treasures = [tesouro(valido, b, [chave])],
    full_coverage_t:ladrao_preload(
        Graph,
        Suspects,
        Items,
        Treasures,
        pronto,
        Id,
        Target
    ),
    Suspects = [procurado(Id, _, Appearance)],
    State = thief(loc(a), Id, Appearance, Target, [], 3),
    full_coverage_t:ladrao_action(
        [],
        State,
        disfarce(Modifications)
    ),
    length(Modifications, Used),
    assertion(Used == 3).

test(uses_only_one_low_cost_bait,
     [setup(reset_agents), cleanup(reset_agents)]) :-
    Graph = [adj(a, b), adj(b, c)],
    single_suspect(Suspects),
    Items = [
        item(chave_real, c, []),
        item(chave_isca, b, [])
    ],
    Treasures = [
        tesouro(alvo, c, [chave_real]),
        tesouro(isca, b, [chave_isca])
    ],
    full_coverage_t:ladrao_preload(
        Graph,
        Suspects,
        Items,
        Treasures,
        pronto,
        Id,
        alvo
    ),
    StateA = thief(
        loc(a),
        Id,
        aparencia([altura(alta)]),
        alvo,
        [],
        0
    ),
    full_coverage_t:ladrao_action([], StateA, MoveToBait),
    assertion(MoveToBait == move(a, b)),
    StateB = thief(
        loc(b),
        Id,
        aparencia([altura(alta)]),
        alvo,
        [],
        0
    ),
    full_coverage_t:ladrao_action([], StateB, StealBait),
    assertion(StealBait == roubar(chave_isca)),
    StateAfterBait = thief(
        loc(b),
        Id,
        aparencia([altura(alta)]),
        alvo,
        [chave_isca],
        0
    ),
    full_coverage_t:ladrao_action([], StateAfterBait, ResumeTarget),
    assertion(ResumeTarget == move(b, c)).

:- end_tests(full_coverage_t).
