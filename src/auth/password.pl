:- module(password, [
    hash_password/2,
    verify_password/2
]).

:- use_module(library(crypto)).

hash_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).

% Com Hash ligado, crypto_password_hash/2 valida a senha contra ele.
verify_password(Plain, Hash) :-
    crypto_password_hash(Plain, Hash).
