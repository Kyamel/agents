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
    read_dotenv_line(Line, In).

%!  read_dotenv_line(+Line, +In) is det.
%
%   Aplica a linha lida e segue para a próxima, parando em fim de arquivo.
read_dotenv_line(end_of_file, _In) :-
    !.
read_dotenv_line(Line, In) :-
    apply_dotenv_line(Line),
    read_dotenv_lines(In).

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
    unquote(Value1, Value).

%!  unquote(+Quoted, -Bare) is det.
%
%   Retira um par de aspas simples ou duplas envolvendo o texto.
unquote(Quoted, Bare) :-
    sub_string(Quoted, 0, 1, _, "\""),
    !,
    sub_string(Quoted, 1, _, 1, Bare).
unquote(Quoted, Bare) :-
    sub_string(Quoted, 0, 1, _, "'"),
    !,
    sub_string(Quoted, 1, _, 1, Bare).
unquote(Bare, Bare).

%!  env_string(+Key, +Default, -Value) is det.
%
%   Obtém variável de ambiente como string ou devolve `Default` se ausente.
env_string(Key, Default, Value) :-
    atom(Key),
    env_string_value(Key, Default, Value).

%!  env_string_value(+Key, +Default, -Value) is det.
%
%   Lê a variável `Key`, caindo para `Default` quando não definida.
env_string_value(Key, _Default, Value) :-
    getenv(Key, Raw),
    !,
    atom_string(Raw, Value).
env_string_value(_Key, Default, Default).

%!  env_required_string(+Key, -Value) is det.
%
%   Obtém variável obrigatória; lança erro se não estiver definida.
env_required_string(Key, Value) :-
    env_string(Key, "", Value),
    require_nonempty(Key, Value).

%!  require_nonempty(+Key, +Value) is det.
%
%   Lança `existence_error` quando `Value` é a string vazia.
require_nonempty(Key, "") :-
    !,
    existence_error(environment_variable, Key).
require_nonempty(_Key, _Value).

%!  env_int(+Key, +Default, -Value) is det.
%
%   Lê variável de ambiente inteira, com fallback em `Default`.
env_int(Key, Default, Value) :-
    must_be(integer, Default),
    env_string(Key, "", Raw),
    parse_int_env(Key, Raw, Default, Value).

%!  parse_int_env(+Key, +Raw, +Default, -Value) is det.
%
%   Converte o texto cru em inteiro, com fallback e erro de domínio.
parse_int_env(_Key, "", Default, Default) :-
    !.
parse_int_env(_Key, Raw, _Default, Value) :-
    catch(number_string(Value, Raw), _, fail),
    integer(Value),
    !.
parse_int_env(Key, Raw, _Default, _Value) :-
    domain_error(integer_env_value, Key=Raw).

%!  env_bool(+Key, +Default, -Value) is det.
%
%   Lê variável booleana em formatos textuais comuns (`true/false`, `1/0`).
env_bool(Key, Default, Value) :-
    must_be(boolean, Default),
    env_string(Key, "", Raw0),
    string_lower(Raw0, Raw),
    parse_bool_env(Key, Raw, Raw0, Default, Value).

%!  parse_bool_env(+Key, +Raw, +Raw0, +Default, -Value) is det.
%
%   Interpreta `Raw` como booleano; `Raw0` é o texto original para o erro.
parse_bool_env(_Key, "", _Raw0, Default, Default) :-
    !.
parse_bool_env(_Key, Raw, _Raw0, _Default, true) :-
    memberchk(Raw, ["1", "true", "yes", "on"]),
    !.
parse_bool_env(_Key, Raw, _Raw0, _Default, false) :-
    memberchk(Raw, ["0", "false", "no", "off"]),
    !.
parse_bool_env(Key, _Raw, Raw0, _Default, _Value) :-
    domain_error(boolean_env_value, Key=Raw0).
