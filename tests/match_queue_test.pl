:- begin_tests(match_queue).

:- use_module('../src/engine/match_queue').
:- use_module(library(http/json)).

test(reads_worker_error_message) :-
    setup_call_cleanup(
        tmp_file_stream(text, File, Stream),
        read_worker_error(Stream, File),
        cleanup_temp_result(Stream, File)
    ).

test(formats_prolog_error) :-
    match_queue:failure_message(
        error(existence_error(procedure, missing/1), _),
        Message
    ),
    assertion(string(Message)),
    assertion(Message \== "").

test(truncates_long_error_message) :-
    length(Codes, 2100),
    maplist(=(0'x), Codes),
    string_codes(LongMessage, Codes),
    match_queue:failure_message(LongMessage, Message),
    string_length(Message, 2000),
    sub_string(Message, 1997, 3, 0, "...").

test(decodes_persisted_error_message) :-
    matches_repo:match_row_dict(
        row(10, 20, 30, mapa, '', '', error,
            '2026-07-06T00:00:00Z', '$null$',
            '2026-07-06T00:01:00Z', 'Falha persistida.'),
        Match
    ),
    assertion(Match.status == "error"),
    assertion(Match.error_message == "Falha persistida.").

read_worker_error(Stream, File) :-
    json_write_dict(Stream, _{error: "Falha produzida pelo agente."}),
    close(Stream),
    match_queue:result_error_message(File, Message),
    assertion(Message == "Falha produzida pelo agente.").

cleanup_temp_result(Stream, File) :-
    catch(close(Stream), _, true),
    catch(delete_file(File), _, true).

:- end_tests(match_queue).
