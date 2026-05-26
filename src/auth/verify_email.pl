:- module(verify_email, [
    issue_verification_token/3,
    token_hash/2,
    expiry_iso/2
]).

:- use_module(library(crypto)).
:- use_module(library(dcg/basics)).

%!  issue_verification_token(+UserId, -PlainToken, -TokenHash) is det.
%
%   Emite token de verificação e hash persistível para ativação de conta.
issue_verification_token(_UserId, PlainToken, TokenHash) :-
    random_token(32, PlainToken),
    token_hash(PlainToken, TokenHash).

%!  token_hash(+Token, -Hash) is det.
%
%   Calcula hash SHA-256 de token de verificação.
token_hash(Token, Hash) :-
    crypto_data_hash(Token, Hash, [algorithm(sha256)]).

%!  expiry_iso(+Minutes, -ExpiresAt) is det.
%
%   Calcula expiração em UTC no formato ISO-8601.
expiry_iso(Minutes, ExpiresAt) :-
    get_time(Now),
    Exp is Now + Minutes * 60,
    format_time(string(ExpiresAt), '%FT%TZ', Exp).

%!  random_token(+NBytes, -Token) is det.
%
%   Gera token hexadecimal a partir de bytes criptograficamente aleatórios.
random_token(NBytes, Token) :-
    crypto_n_random_bytes(NBytes, Bytes),
    phrase(hex_list(Bytes), Codes),
    string_codes(Token, Codes).

%!  hex_list(+Bytes)// is det.
%
%   DCG que serializa bytes em hexadecimal.
hex_list([]) --> [].
hex_list([B|Bs]) -->
    { format(string(H), '~|~`0t~16r~2+', [B]), string_codes(H, HC) },
    HC,
    hex_list(Bs).
