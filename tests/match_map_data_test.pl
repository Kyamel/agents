:- begin_tests(match_map_data).

:- use_module('../src/server/views/match_map_data').

test(projects_frames_in_replay_order) :-
    Setup = _{
        thief_start: "a",
        detective_start: "b",
        lock_mode: "single",
        appearance: ["altura(alta)"]
    },
    Turns = [
        _{
            turn: 1,
            thief_position: "-",
            detective_position: "-",
            thief_action: "-",
            thief_status: "OK",
            detective_action: "inspecionar",
            detective_status: "OK",
            events: []
        },
        _{
            turn: 2,
            thief_position: "c",
            detective_position: "d",
            thief_action:
                "disfarce([trocar(altura(alta),altura(baixa))])",
            thief_status: "OK",
            detective_action:
                "pedir_mandato(suspeito1, [altura(baixa)])",
            detective_status: "OK",
            events: [
                _{
                    type: "robbery",
                    item: "chave",
                    city: "c",
                    revealed: ["altura(baixa)"]
                }
            ]
        }
    ],
    Objective = _{city: "c", requirements: ["chave"]},
    replay_frames(Setup, Turns, Objective, Frames),
    Frames = [Initial, Turn2, Turn1],
    assertion(Initial.label == "Início"),
    assertion(Turn2.label == "Turno 2"),
    assertion(Turn2.collected == ["chave"]),
    assertion(Turn2.revealed == ["altura(baixa)"]),
    assertion(Turn2.objectiveReady == true),
    assertion(Turn2.appearance = [
        _{original: "altura(alta)", current: "altura(baixa)"}
    ]),
    assertion(Turn1.t == "c"),
    assertion(Turn1.d == "d"),
    frame_events(Frames, Events),
    maplist(event_type, Events, EventTypes),
    assertion(EventTypes == [
        "robbery",
        "disguise",
        "mandate",
        "inspection"
    ]),
    maplist(event_agent, Events, EventAgents),
    assertion(EventAgents == [
        "thief",
        "thief",
        "detective",
        "detective"
    ]).

test(accumulates_and_releases_locks) :-
    Setup = _{
        thief_start: "a",
        detective_start: "b",
        lock_mode: "accumulate",
        appearance: []
    },
    turn(3, "fechar(a)", Turn3Input),
    turn(2, "fechar(b)", Turn2Input),
    turn(1, "liberar(a)", Turn1Input),
    Turns = [Turn3Input, Turn2Input, Turn1Input],
    Objective = _{city: null, requirements: []},
    replay_frames(Setup, Turns, Objective, Frames),
    Frames = [_, Turn3, Turn2, Turn1],
    assertion(Turn3.blocked == ["a"]),
    assertion(Turn2.blocked == ["a", "b"]),
    assertion(Turn1.blocked == ["b"]).

test(resolves_thief_identity_from_scenario) :-
    Replay = _{
        setup: _{
            thief_id: 3,
            thief_start: "0_0_0",
            detective_start: "0_0_1",
            target: "coroa",
            appearance: []
        },
        turns: [
            _{
                turn: 1,
                thief_position: "-",
                detective_position: "-",
                thief_action: "-",
                thief_status: "OK",
                detective_action: "pedir_mandato(12, [])",
                detective_status: "OK",
                events: []
            }
        ]
    },
    map_data("./maps/metro_3_3.prolog", Replay, Data),
    assertion(Data.thiefIdentity.id == 3),
    assertion(Data.thiefIdentity.name == "Dario Pike"),
    Data.frames = [_, Turn1],
    assertion(Turn1.mandate.suspect == 12),
    assertion(Turn1.mandate.suspectName == "Mina Cross").

turn(Number, DetectiveAction, Turn) :-
    Turn = _{
        turn: Number,
        thief_position: "-",
        detective_position: "-",
        thief_action: "-",
        thief_status: "OK",
        detective_action: DetectiveAction,
        detective_status: "OK",
        events: []
    }.

event_type(Event, Type) :-
    get_dict(type, Event, Type).

event_agent(Event, Agent) :-
    get_dict(agent, Event, Agent).

:- end_tests(match_map_data).
