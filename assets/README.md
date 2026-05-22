# assets/

Arquivos estáticos servidos pelo backend em `/assets/...`
(handler em [src/http/routes/static.pl](../src/http/routes/static.pl)).

## Logo da UFOP

O rodapé espera o arquivo:

```
assets/logo-ufop.png
```

Coloque aqui o PNG do logo oficial da UFOP com esse nome exato.
Enquanto o arquivo não existir, o rodapé exibe um fallback textual
("UFOP" em vermelho) — veja `ufop_logo/1` em
[src/components/page.pl](../src/components/page.pl).
