:- module(auth, []).

% Fachada do pacote de autenticacao. Reexporta o que e usado fora de auth/:
% cadastro/login/verificacao (account) e os helpers de token de sessao
% (session_token). password, verify_email e mail sao internos ao account.

:- reexport(account).
:- reexport(session_token).
