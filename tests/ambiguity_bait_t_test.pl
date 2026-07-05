:- begin_tests(ambiguity_bait_t).

:- use_module('../agents/ambiguity_bait_t').

reset_agent :-
    ambiguity_bait_t:limpar_memoria,
    ambiguity_bait_t:limpar_memoria_local.

test(fallback_uses_full_disguise_budget,
     [setup(reset_agent), cleanup(reset_agent)]) :-
    Appearance = [
        altura(alta),
        genero(gen1),
        cor_olhos(verde),
        marca(cicatriz)
    ],
    assertz(ambiguity_bait_t:disfarces_usados(0)),
    State = thief(
        loc(a),
        0,
        aparencia(Appearance),
        tesouro,
        [],
        3
    ),
    ambiguity_bait_t:ladrao_action(
        [],
        State,
        disfarce(Modifications)
    ),
    assertion(Modifications == [
        omitir(altura(alta)),
        omitir(genero(gen1)),
        omitir(cor_olhos(verde))
    ]).

test(strong_plan_is_completed_to_full_budget,
     [setup(reset_agent), cleanup(reset_agent)]) :-
    Appearance = [
        altura(alta),
        genero(gen1),
        cor_olhos(verde),
        marca(cicatriz)
    ],
    assertz(ambiguity_bait_t:disfarces_usados(0)),
    assertz(ambiguity_bait_t:plano_disfarce_forte(
        100,
        1,
        [trocar(altura(alta), altura(baixa))]
    )),
    State = thief(
        loc(a),
        0,
        aparencia(Appearance),
        tesouro,
        [],
        3
    ),
    ambiguity_bait_t:ladrao_action(
        [],
        State,
        disfarce(Modifications)
    ),
    assertion(Modifications == [
        trocar(altura(alta), altura(baixa)),
        omitir(genero(gen1)),
        omitir(cor_olhos(verde))
    ]).

test(strong_plan_handles_different_attribute_functors) :-
    ambiguity_bait_t:construir_plano_disfarce(
        [altura(alta), barba, chapeu(preto)],
        [altura(baixa), oculos, chapeu(preto)],
        Plan
    ),
    assertion(Plan == [
        trocar(altura(alta), altura(baixa)),
        omitir(barba),
        adicionar(oculos)
    ]).

:- end_tests(ambiguity_bait_t).
