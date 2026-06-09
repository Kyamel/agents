:- module(resend_client, [
    send_verification_email/3
]).

:- use_module(library(http/http_client)).
:- use_module(library(http/http_json)).
:- use_module('../config').

%!  send_verification_email(+ToEmail, +VerifyUrl, -Response) is det.
%
%   Envia email transacional de verificação via API do Resend.
send_verification_email(ToEmail, VerifyUrl, Response) :-
    config:resend_api_key(ApiKey),
    config:resend_from(From),

    Payload = _{
        from: From,
        to: [ToEmail],
        subject: "Verify your account",
        html: "<p>Click to verify your account:</p><p><a href=\"" + VerifyUrl + "\">Verify email</a></p>"
    },

    format(string(AuthHeader), 'Bearer ~s', [ApiKey]),

    http_post(
        'https://api.resend.com/emails',
        json(Payload),
        Response,
        [ request_header('Authorization'=AuthHeader),
          json_object(dict),
          timeout(10)
        ]
    ).
