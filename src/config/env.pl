:- module(env, [
    load_dotenv/1,
    env_string/3,
    env_required_string/2,
    env_int/3,
    env_bool/3
]).

:- use_module(library(readutil)).
:- use_module(library(error)).
:- use_module(library(lists)).

%!  load_dotenv(+File) is det.
%
%   Carrega variáveis de ambiente de um arquivo `.env`, quando existente.
load_dotenv(File) :-
    exists_file(File),
    !,
    setup_call_cleanup(
        open(File, read, In),
        read_dotenv_lines(In),
        close(In)
    ).
load_dotenv(_).

%!  read_dotenv_lines(+In) is det.
%
%   Lê todas as linhas do stream `In` e aplica cada entrada de configuração.
read_dotenv_lines(In) :-
    read_line_to_string(In, Line),
    (   Line == end_of_file
    ->  true
    ;   apply_dotenv_line(Line),
        read_dotenv_lines(In)
    ).

%!  apply_dotenv_line(+Line0) is det.
%
%   Interpreta uma linha de `.env`, ignorando comentários e linhas vazias.
apply_dotenv_line(Line0) :-
    normalize_space(string(Line), Line0),
    (   Line = ""
    ;   sub_string(Line, 0, 1, _, "#")
    ),
    !.
apply_dotenv_line(Line) :-
    sub_string(Line, Sep, 1, _, "="),
    !,
    sub_string(Line, 0, Sep, _, Key0),
    Start is Sep + 1,
    sub_string(Line, Start, _, 0, Value0),
    normalize_space(string(Key1), Key0),
    strip_quotes(Value0, Value1),
    atom_string(Key, Key1),
    setenv(Key, Value1).
apply_dotenv_line(_).

%!  strip_quotes(+Value0, -Value) is det.
%
%   Remove aspas simples ou duplas envolvendo um valor textual.
strip_quotes(Value0, Value) :-
    normalize_space(string(Value1), Value0),
    (   sub_string(Value1, 0, 1, _, "\"")
    ->  sub_string(Value1, 1, _, 1, Value)
    ;   sub_string(Value1, 0, 1, _, "'")
    ->  sub_string(Value1, 1, _, 1, Value)
    ;   Value = Value1
    ).

%!  env_string(+Key, +Default, -Value) is det.
%
%   Obtém variável de ambiente como string ou devolve `Default` se ausente.
env_string(Key, Default, Value) :-
    atom(Key),
    (   getenv(Key, Raw)
    ->  atom_string(Raw, Value)
    ;   Value = Default
    ).

%!  env_required_string(+Key, -Value) is det.
%
%   Obtém variável obrigatória; lança erro se não estiver definida.
env_required_string(Key, Value) :-
    env_string(Key, "", Value),
    (   Value == ""
    ->  existence_error(environment_variable, Key)
    ;   true
    ).

%!  env_int(+Key, +Default, -Value) is det.
%
%   Lê variável de ambiente inteira, com fallback em `Default`.
env_int(Key, Default, Value) :-
    must_be(integer, Default),
    env_string(Key, "", Raw),
    (   Raw == ""
    ->  Value = Default
    ;   catch(number_string(N, Raw), _, fail),
        integer(N)
    ->  Value = N
    ;   domain_error(integer_env_value, Key=Raw)
    ).

%!  env_bool(+Key, +Default, -Value) is det.
%
%   Lê variável booleana em formatos textuais comuns (`true/false`, `1/0`).
env_bool(Key, Default, Value) :-
    must_be(boolean, Default),
    env_string(Key, "", Raw0),
    string_lower(Raw0, Raw),
    (   Raw == ""
    ->  Value = Default
    ;   memberchk(Raw, ["1", "true", "yes", "on"])
    ->  Value = true
    ;   memberchk(Raw, ["0", "false", "no", "off"])
    ->  Value = false
    ;   domain_error(boolean_env_value, Key=Raw0)
    ).
