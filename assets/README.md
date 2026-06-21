# assets/

Arquivos estáticos servidos pelo backend em `/assets/...`
(handler em [src/server/routes/web/static.pl](../src/server/routes/web/static.pl)).

## Logo da UFOP

O rodapé espera o arquivo:

```
assets/logo-ufop.png
```

Coloque aqui o PNG do logo oficial da UFOP com esse nome exato.
Enquanto o arquivo não existir, o rodapé exibe um fallback textual
("UFOP" em vermelho) — veja `ufop_logo/1` em
[src/server/views/page.pl](../src/server/views/page.pl).
