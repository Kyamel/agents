:- module(tokens, [
    issue_token/2,
    token_hash/2,
    expiry_iso/2,
    now_iso/1
]).

:- use_module(library(crypto)).

%!  issue_token(-PlainToken, -TokenHash) is det.
issue_token(PlainToken, TokenHash) :-
    random_token(32, PlainToken),
    token_hash(PlainToken, TokenHash).

%!  token_hash(+Token, -Hash) is det.
token_hash(Token, Hash) :-
    crypto_data_hash(Token, Hash, [algorithm(sha256)]).

%!  expiry_iso(+Minutes, -ExpiresAt) is det.
expiry_iso(Minutes, ExpiresAt) :-
    get_time(Now),
    Exp is Now + Minutes * 60,
    format_time(string(ExpiresAt), '%FT%TZ', Exp).

%!  now_iso(-Iso) is det.
now_iso(Iso) :-
    get_time(Now),
    format_time(string(Iso), '%FT%TZ', Now).

random_token(NBytes, Token) :-
    crypto_n_random_bytes(NBytes, Bytes),
    token_hex_bytes(Bytes, Token).

token_hex_bytes([], "").
token_hex_bytes([B|Bs], Token) :-
    format(string(H), '~|~`0t~16r~2+', [B]),
    token_hex_bytes(Bs, Rest),
    string_concat(H, Rest, Token).
