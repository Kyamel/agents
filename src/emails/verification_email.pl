:- module(verification_email, [
    send_verification_email/3
]).

:- use_module('../infra/mail').

% "Preenche as lacunas" do email de verificacao: define assunto e corpo e delega
% o envio ao servico infra/mail.

%!  send_verification_email(+To, +VerifyUrl, -Status) is det.
send_verification_email(To, VerifyUrl, Status) :-
    Subject = "Verify your account",
    format(string(Html),
           "<p>Click to verify your account:</p><p><a href=\"~w\">Verify email</a></p>",
           [VerifyUrl]),
    mail:send_email(To, Subject, Html, Status).
