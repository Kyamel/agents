:- module(password, [
    hash_password/2,
    verify_password/2
]).

:- use_module(library(crypto)).

%!  hash_password(+Plain, -Hash) is det.
%
%   Gera hash seguro de senha em texto puro.
hash_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

%!  verify_password(+Plain, +Hash) is semidet.
%
%   Verifica senha em texto puro contra hash armazenado.
verify_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).
