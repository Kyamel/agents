:- begin_tests(agent_profile).

:- use_module('../src/services/agents').

test(calculates_performance_stats) :-
    performance_stats(
        _{wins: 5, losses: 3, draws: 2},
        Stats
    ),
    assertion(Stats.total == 10),
    assertion(Stats.win_rate =:= 50.0),
    assertion(Stats.wins == 5),
    assertion(Stats.losses == 3),
    assertion(Stats.draws == 2).

test(handles_agent_without_completed_matches) :-
    performance_stats(
        _{wins: 0, losses: 0, draws: 0},
        Stats
    ),
    assertion(Stats.total == 0),
    assertion(Stats.win_rate =:= 0.0).

test(contextualizes_thief_victory) :-
    sample_match("done", "thief", Match),
    agents:agent_match(10, Match, Rich),
    assertion(Rich.agent_side == "thief"),
    assertion(Rich.agent_result == "win"),
    assertion(Rich.opponent_id == 20),
    assertion(Rich.opponent_name == "detetive").

test(contextualizes_detective_loss) :-
    sample_match("done", "thief", Match),
    agents:agent_match(20, Match, Rich),
    assertion(Rich.agent_side == "detective"),
    assertion(Rich.agent_result == "loss"),
    assertion(Rich.opponent_id == 10),
    assertion(Rich.opponent_name == "ladrao").

test(contextualizes_unfinished_match) :-
    sample_match("error", "", Match),
    agents:agent_match(10, Match, Rich),
    assertion(Rich.agent_result == "not_completed").

sample_match(Status, Winner, _{
    id: 1,
    thief_agent_id: 10,
    thief_agent_name: "ladrao",
    detective_agent_id: 20,
    detective_agent_name: "detetive",
    scenario: "mapa",
    winner: Winner,
    status: Status,
    created_at: "2026-01-01T00:00:00Z",
    started_at: "",
    finished_at: ""
}).

:- end_tests(agent_profile).
