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

## Apresentações

Cada apresentação servida em `/slides/<nome>?page=<id>` ocupa uma pasta em:

```text
assets/slides/<nome>/
├── 00.json
├── 01.json
└── imgs/
```

Os slides usam ids de `00` a `99`. Cada JSON contém:

```json
{
  "title": "Título",
  "subtitle": "Subtítulo",
  "image": "/assets/slides/<nome>/imgs/imagem.png",
  "image_alt": "Descrição da imagem",
  "second_image": "/assets/slides/<nome>/imgs/segunda-imagem.png",
  "second_image_alt": "Descrição da segunda imagem",
  "right_text": "Texto exibido à direita da imagem",
  "paragraph": "Texto exibido abaixo da imagem."
}
```

Somente `title` é obrigatório. Todos os outros campos podem ser omitidos,
definidos como `null` ou deixados vazios. Os caminhos de imagem devem começar
em `/`, pois são relativos à raiz do servidor.

- `image` + `second_image`: mostra duas imagens lado a lado.
- `image` + `right_text`: mostra a imagem à esquerda e o texto à direita.
- `image` sozinha: mantém a imagem centralizada.
- `paragraph`: aparece abaixo de qualquer um desses layouts.

Os layouts com duas colunas ocupam toda a largura disponível e são empilhados
em telas pequenas. A apresentação de exemplo está disponível manualmente em
`/slides/demo?page=00`.
