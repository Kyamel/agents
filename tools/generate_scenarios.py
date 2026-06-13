#!/usr/bin/env python3
"""Generate large ternary metro scenarios for the Prolog engine.

The generated maps are k-dimensional 3-ary grids: 3^3 through 3^7 cities. They
are intentionally bigger than cenario1.prolog and keep the same fact schema
expected by src/engine/Interactor.prolog.
"""

from __future__ import annotations

from itertools import product
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "scenarios"


SUSPECTS = [
    (0, "Ariadne Vale", ["altura(alta)", "genero(gen2)", "cor_olhos(verde)", "cor_cabelo(preto)", "marca(cicatriz_rosto)", "passo(rapido)"]),
    (1, "Bruno Knox", ["altura(media)", "genero(gen1)", "cor_olhos(castanho)", "cor_cabelo(loiro)", "nariz(longo)", "passo(lento)"]),
    (2, "Celia Flux", ["altura(baixa)", "genero(gen2)", "cor_olhos(azul)", "cor_cabelo(ruivo)", "tatuagem(braco)", "mochila(cinza)"]),
    (3, "Dario Pike", ["altura(alta)", "genero(gen1)", "cor_olhos(escuro)", "cor_cabelo(preto)", "barba", "casaco(azul)"]),
    (4, "Elena Mist", ["altura(media)", "genero(gen2)", "cor_olhos(verde)", "cor_cabelo(castanho)", "piercing(nariz)", "luvas(pretas)"]),
    (5, "Felix Ward", ["altura(alta)", "genero(gen1)", "cor_olhos(azul)", "cor_cabelo(grisalho)", "marca(tatuagem_pescoco)", "mala(vermelha)"]),
    (6, "Gaia Stone", ["altura(baixa)", "genero(gen2)", "cor_olhos(castanho)", "cor_cabelo(preto)", "oculos", "cachecol(roxo)"]),
    (7, "Hugo Reed", ["altura(media)", "genero(gen1)", "cor_olhos(verde)", "cor_cabelo(ruivo)", "nariz(curto)", "chapeu(preto)"]),
    (8, "Iris Frost", ["altura(alta)", "genero(gen2)", "cor_olhos(azul)", "cor_cabelo(loiro)", "cicatriz(sobrancelha)", "casaco(branco)"]),
    (9, "Jonas Wolfe", ["altura(media)", "genero(gen1)", "cor_olhos(escuro)", "cor_cabelo(castanho)", "atletico", "mochila(preta)"]),
    (10, "Kira North", ["altura(baixa)", "genero(gen2)", "cor_olhos(verde)", "cor_cabelo(loiro)", "luvas(pretas)", "passo(rapido)"]),
    (11, "Luca Voss", ["altura(alta)", "genero(gen1)", "cor_olhos(castanho)", "cor_cabelo(preto)", "oculos", "casaco(cinza)"]),
    (12, "Mina Cross", ["altura(media)", "genero(gen2)", "cor_olhos(escuro)", "cor_cabelo(ruivo)", "piercing(orelha)", "mala(azul)"]),
    (13, "Noah Flint", ["altura(baixa)", "genero(gen1)", "cor_olhos(azul)", "cor_cabelo(castanho)", "barba", "cachecol(verde)"]),
    (14, "Orion Lake", ["altura(alta)", "genero(gen1)", "cor_olhos(verde)", "cor_cabelo(grisalho)", "nariz(longo)", "chapeu(cinza)"]),
]


BASE_PLANS = [
    ("reliquia_norte", ["cartao_norte", "chave_norte", "token_norte"]),
    ("diamante_sul", ["mapa_sul", "broca_sul", "senha_sul", "luva_sul"]),
    ("coroa_leste", ["anel_leste", "codigo_leste", "cortador_leste", "bateria_leste"]),
    ("arquivo_oeste", ["pendrive_oeste", "badge_oeste", "rota_oeste", "decoder_oeste", "selo_oeste"]),
    ("mascara_central", ["espelho_central", "chave_central", "cifra_central", "lente_central", "cabo_central"]),
    ("orbe_final", ["runa_final", "cristal_final", "agulha_final", "pergaminho_final", "motor_final", "selo_final"]),
]


SUBREQS = {
    "chave_norte": ["mini_chave_norte"],
    "broca_sul": ["combustivel_sul"],
    "luva_sul": ["fibra_sul"],
    "cortador_leste": ["bateria_leste"],
    "decoder_oeste": ["chip_oeste"],
    "selo_oeste": ["carimbo_oeste"],
    "chave_central": ["pino_central"],
    "lente_central": ["polidor_central"],
    "runa_final": ["tinta_final"],
    "agulha_final": ["ima_final"],
    "motor_final": ["bobina_final"],
}


def city(dim: int, coord: tuple[int, ...]) -> str:
    return "m" + str(dim) + "_" + "_".join(str(x) for x in coord)


def coord_for_index(dim: int, index: int, salt: int = 0) -> tuple[int, ...]:
    coords = []
    n = index + salt * 7
    for axis in range(dim):
        coords.append((n + axis * 2 + salt) % 3)
        n //= 3
    return tuple(coords)


def spread_coords(dim: int, count: int, salt: int = 0) -> list[tuple[int, ...]]:
    total = 3**dim
    step = max(1, total // (count + 1))
    return [coord_for_index(dim, (i + 1) * step, salt + i) for i in range(count)]


def treasure_coords(dim: int, count: int) -> list[tuple[int, ...]]:
    seeds = [
        tuple([2] * dim),
        tuple([0] + [2] * (dim - 1)),
        tuple([2, 0] + [2] * (dim - 2)),
        tuple([2] * (dim - 1) + [0]),
        tuple([1] * dim),
        tuple([0, 1] + [2] * (dim - 2)),
    ]
    return seeds[:count]


def emit_list(items: list[str]) -> str:
    return "[" + ", ".join(items) + "]"


def generate(dim: int) -> str:
    coords = list(product(range(3), repeat=dim))
    treasure_count = min(len(BASE_PLANS), dim + 1)
    plans = BASE_PLANS[:treasure_count]

    all_items = []
    for _treasure, reqs in plans:
        all_items.extend(reqs)
        for req in reqs:
            all_items.extend(SUBREQS.get(req, []))
    item_positions = dict(zip(all_items, spread_coords(dim, len(all_items), salt=dim)))

    lines: list[str] = []
    lines.extend([
        "% =========================================================",
        f"%  METRO 3^{dim}",
        "%",
        f"%  {3**dim} cidades",
        f"%  {dim}-dimensional ternary metro grid",
        "%  Gerado por tools/generate_metro_scenarios.py",
        "% =========================================================",
        "",
        ":- dynamic item/3.",
        ":- dynamic tesouro/3.",
        ":- dynamic roubado/2.",
        "",
        "% =========================================================",
        "% SUSPEITOS",
        "% =========================================================",
        "",
    ])

    for sid, name, attrs in SUSPECTS:
        lines.append(f"procurado({sid},'{name}',")
        lines.append("    aparencia([")
        for idx, attr in enumerate(attrs):
            comma = "," if idx < len(attrs) - 1 else ""
            lines.append(f"        {attr}{comma}")
        lines.append("    ])).")
        lines.append("")

    lines.extend([
        "% =========================================================",
        "% CIDADES",
        "% =========================================================",
        "",
    ])
    for coord in coords:
        lines.append(f"cidade({city(dim, coord)}).")

    lines.extend([
        "",
        "% =========================================================",
        "% CONEXOES",
        "% =========================================================",
        "",
    ])
    for coord in coords:
        for axis in range(dim):
            if coord[axis] < 2:
                other = list(coord)
                other[axis] += 1
                lines.append(f"conectado({city(dim, coord)},{city(dim, tuple(other))}).")

    lines.extend([
        "",
        "% =========================================================",
        "% TESOUROS",
        "% =========================================================",
        "",
    ])
    for (treasure, reqs), coord in zip(plans, treasure_coords(dim, treasure_count)):
        lines.append(f"tesouro({treasure}, {city(dim, coord)},")
        lines.append(f"    {emit_list(reqs)}).")
        lines.append("")

    lines.extend([
        "% =========================================================",
        "% ITENS",
        "% =========================================================",
        "",
    ])
    emitted = set()
    for _treasure, reqs in plans:
        for req in reqs:
            emitted.add(req)
            subreqs = SUBREQS.get(req, [])
            lines.append(f"item({req}, {city(dim, item_positions[req])},")
            lines.append(f"    {emit_list(subreqs)}).")
            lines.append("")
            for sub in subreqs:
                if sub in emitted:
                    continue
                emitted.add(sub)
                lines.append(f"item({sub}, {city(dim, item_positions[sub])},")
                lines.append("    []).")
                lines.append("")

    max_turns = 90 + dim * 55
    lines.extend([
        "% =========================================================",
        "% LIMITE DE TURNOS",
        "% =========================================================",
        "",
        f"max_turnos({max_turns}).",
        "",
    ])
    return "\n".join(lines)


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for dim in (3, 4, 5, 6, 7, 8, 9):
        path = OUT_DIR / f"metro_3_{dim}.prolog"
        path.write_text(generate(dim), encoding="utf-8")
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
