#!/usr/bin/env python3
"""Command-line runner for thief-agent evaluation batches."""

from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
import subprocess
from collections.abc import Iterable, Sequence
from dataclasses import dataclass
from difflib import get_close_matches
from pathlib import Path
from typing import Any

from match_data import (
    DEFAULT_WEIGHTS,
    Row,
    Scenario,
    best_worst,
    parse_output,
    parse_scenario,
    score_match,
    summarize,
)

SCRIPT_PATH = Path(__file__).resolve()
TOOLS_DIR = SCRIPT_PATH.parent
PROJECT_ROOT = TOOLS_DIR.parent
MAPS_DIR = PROJECT_ROOT / "maps"
AGENTS_DIR = PROJECT_ROOT / "agents"
RESULTS_DIR = TOOLS_DIR / "results"
INTERACTOR_PATH = PROJECT_ROOT / "src" / "engine" / "Interactor.prolog"

DEFAULT_SCENARIO_PATH = MAPS_DIR / "cenario1.prolog"
DEFAULT_DETECTIVE_PATHS = (AGENTS_DIR / "random_d.pl",)
DEFAULT_OUTPUT_DIR = RESULTS_DIR
DEFAULT_ROUNDS = 50
DEFAULT_SEED_START = 1
DEFAULT_DISGUISES = 3

SWIPL_EXECUTABLE = "swipl"
CONFIG_FILENAME = "config.json"
MATCHES_FILENAME = "matches.csv"
SUMMARY_FILENAME = "summary.csv"
BEST_WORST_FILENAME = "best_worst.csv"
RAW_DIR_NAME = "raw"
RESULT_DIGEST_LENGTH = 12
RUN_ID_LENGTH = 16
PATH_SUGGESTION_LIMIT = 5
PATH_SUGGESTION_CUTOFF = 0.35

ANSI_GREEN = "\033[32m"
ANSI_RED = "\033[31m"
ANSI_RESET = "\033[0m"


@dataclass(frozen=True)
class Matchup:
    thief: Path
    detective: Path
    round_idx: int
    seed: int


def main() -> int:
    args = parse_args()
    scenario = parse_scenario(resolve_path(args.scenario))
    detectives = resolve_paths(args.detectives)
    thieves = resolve_paths(args.thieves)
    weights = weights_from_args(args)
    config = build_config(args, scenario, thieves, detectives, weights)

    out_dir = output_dir(args.output_dir, config)
    out_dir.mkdir(parents=True, exist_ok=True)
    raw_dir = out_dir / RAW_DIR_NAME
    raw_dir.mkdir(exist_ok=True)
    write_json(out_dir / CONFIG_FILENAME, config)

    all_rows: list[Row] = []
    total = len(thieves) * len(detectives) * args.rounds
    for done, match in enumerate(iter_matchups(thieves, detectives, args.rounds, args.seed_start), start=1):
        raw = run_match(scenario.path, match.thief, match.detective, match.seed, args.disguises)
        row = match_row(match, scenario, raw, weights)
        all_rows.append(row)
        write_json(raw_dir / f"{row['run_id']}.json", {"row": row, "raw": raw})
        print_progress(done, total, row)

    write_csv(out_dir / MATCHES_FILENAME, all_rows)
    write_csv(out_dir / SUMMARY_FILENAME, summarize(all_rows))
    write_csv(out_dir / BEST_WORST_FILENAME, best_worst(all_rows))

    print_win_rates(all_rows, thieves, detectives)
    print()
    print(f"Resultados salvos em: {out_dir}")
    print(f"- {out_dir / MATCHES_FILENAME}")
    print(f"- {out_dir / SUMMARY_FILENAME}")
    print(f"- {out_dir / BEST_WORST_FILENAME}")
    print(f"- {raw_dir}/")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Evaluate thief agents against detective agents.")
    parser.add_argument(
        "--rounds",
        "-n",
        type=int,
        default=DEFAULT_ROUNDS,
        help=f"numero de rodadas por detetive (padrao: {DEFAULT_ROUNDS})",
    )
    parser.add_argument(
        "--thieves",
        "--thief",
        "-t",
        nargs="+",
        required=True,
        help="arquivos .pl dos agentes ladroes a comparar",
    )
    parser.add_argument(
        "--detectives",
        "-d",
        nargs="+",
        default=[str(path) for path in DEFAULT_DETECTIVE_PATHS],
        help=f"lista de arquivos .pl dos detetives (padrao: {rel(DEFAULT_DETECTIVE_PATHS[0])})",
    )
    parser.add_argument(
        "--scenario",
        default=str(DEFAULT_SCENARIO_PATH),
        help=f"cenario .prolog (padrao: {rel(DEFAULT_SCENARIO_PATH)})",
    )
    parser.add_argument(
        "--output-dir",
        default=str(DEFAULT_OUTPUT_DIR),
        help=f"diretorio base dos resultados (padrao: {rel(DEFAULT_OUTPUT_DIR)})",
    )
    parser.add_argument("--seed-start", type=int, default=DEFAULT_SEED_START, help="primeira seed usada na bateria")
    parser.add_argument(
        "--disguises",
        type=int,
        default=DEFAULT_DISGUISES,
        help="quantidade de disfarces passada ao engine",
    )
    parser.add_argument("--w-vit", type=float, default=DEFAULT_WEIGHTS["vit"])
    parser.add_argument("--w-turn", type=float, default=DEFAULT_WEIGHTS["turn"])
    parser.add_argument("--w-pist", type=float, default=DEFAULT_WEIGHTS["pist"])
    parser.add_argument("--w-risk", type=float, default=DEFAULT_WEIGHTS["risk"])
    parser.add_argument("--w-mov", type=float, default=DEFAULT_WEIGHTS["mov"])
    return parser.parse_args()


def weights_from_args(args: argparse.Namespace) -> dict[str, float]:
    return {
        "vit": args.w_vit,
        "turn": args.w_turn,
        "pist": args.w_pist,
        "risk": args.w_risk,
        "mov": args.w_mov,
    }


def build_config(
    args: argparse.Namespace,
    scenario: Scenario,
    thieves: list[Path],
    detectives: list[Path],
    weights: dict[str, float],
) -> dict[str, Any]:
    return {
        "scenario": rel(scenario.path),
        "thieves": [rel(path) for path in thieves],
        "detectives": [rel(path) for path in detectives],
        "rounds": args.rounds,
        "seed_start": args.seed_start,
        "qdis": args.disguises,
        "weights": weights,
    }


def iter_matchups(
    thieves: list[Path],
    detectives: list[Path],
    rounds: int,
    seed_start: int,
) -> Iterable[Matchup]:
    for thief, detective in itertools.product(thieves, detectives):
        for round_idx in range(1, rounds + 1):
            seed = seed_start + round_idx - 1
            yield Matchup(thief=thief, detective=detective, round_idx=round_idx, seed=seed)


def match_row(match: Matchup, scenario: Scenario, raw: dict, weights: dict[str, float]) -> Row:
    return {
        "run_id": run_id(match.thief, match.detective, scenario.path, match.seed),
        "round": match.round_idx,
        "seed": match.seed,
        "scenario": rel(scenario.path),
        "thief_agent": rel(match.thief),
        "detective_agent": rel(match.detective),
        **score_match(raw, scenario, weights),
    }


def run_match(scenario: Path, thief: Path, detective: Path, seed: int, disguises: int) -> dict:
    goal = (
        f"set_random(seed({seed})),"
        f"consult({prolog_atom(INTERACTOR_PATH)}),"
        f"gameStart({prolog_atom(scenario_arg(scenario))},{disguises},{prolog_atom(thief)},{prolog_atom(detective)},S,V),"
        "nl,write('__STATE__='),write_canonical(S),"
        "nl,write('__RESULT__='),write(V),nl,"
        "halt."
    )
    proc = subprocess.run(
        [SWIPL_EXECUTABLE, "-q", "-g", goal],
        cwd=PROJECT_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"SWI-Prolog falhou\nSTDERR:\n{proc.stderr}\nSTDOUT:\n{proc.stdout}")
    return parse_output(proc.stdout, proc.stderr, seed)


def resolve_paths(values: Sequence[str | Path]) -> list[Path]:
    return [resolve_path(value) for value in values]


def resolve_path(value: str | Path, *, must_exist: bool = True) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    path = path.resolve()
    if must_exist and not path.exists():
        raise SystemExit(missing_path_message(path))
    return path


def missing_path_message(path: Path) -> str:
    lines = [
        f"Arquivo nao encontrado: {path}",
        f"Diretorio do projeto: {PROJECT_ROOT}",
    ]
    suggestions = similar_paths(path)
    if suggestions:
        lines.append("Arquivos parecidos:")
        lines.extend(f"- {rel(suggestion)}" for suggestion in suggestions)
    return "\n".join(lines)


def similar_paths(path: Path) -> list[Path]:
    if not path.parent.is_dir():
        return []
    candidates = [candidate.name for candidate in path.parent.iterdir() if candidate.is_file()]
    matches = get_close_matches(
        path.name,
        candidates,
        n=PATH_SUGGESTION_LIMIT,
        cutoff=PATH_SUGGESTION_CUTOFF,
    )
    return [path.parent / match for match in matches]


def rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(PROJECT_ROOT))
    except ValueError:
        return str(path.resolve())


def output_dir(base: str, config: dict) -> Path:
    base_path = resolve_path(base, must_exist=False)
    digest = hashlib.sha256(json.dumps(config, sort_keys=True).encode("utf-8")).hexdigest()[:RESULT_DIGEST_LENGTH]
    thieves = slug("-".join(Path(path).stem for path in config["thieves"]))
    detectors = slug("-".join(Path(path).stem for path in config["detectives"]))
    name = f"{Path(config['scenario']).stem}__{thieves}__vs__{detectors}__n{config['rounds']}__seed{config['seed_start']}__{digest}"
    return base_path / name


def slug(value: str) -> str:
    clean = "".join(char if char.isalnum() or char in "_.-" else "-" for char in value).strip("-")
    return clean or "agent"


def run_id(thief: Path, detective: Path, scenario: Path, seed: int) -> str:
    payload = f"{rel(thief)}|{rel(detective)}|{rel(scenario)}|{seed}"
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:RUN_ID_LENGTH]


def prolog_atom(path: Path) -> str:
    return "'" + str(path).replace("\\", "\\\\").replace("'", "\\'") + "'"


def scenario_arg(path: Path) -> Path:
    return path.with_suffix("")


def print_progress(done: int, total: int, row: Row) -> None:
    print(
        f"[{done:03d}/{total:03d}] {row['thief_agent']} vs {row['detective_agent']} "
        f"seed={row['seed']} score={float(row['score']):.2f} winner={row['winner']}"
    )


def print_win_rates(rows: list[Row], thieves: list[Path], detectives: list[Path]) -> None:
    print()
    print("Win rates:")

    for thief in thieves:
        thief_name = rel(thief)
        thief_rows = [row for row in rows if row["thief_agent"] == thief_name]
        print(f"- {thief_name}")

        for detective in detectives:
            detective_name = rel(detective)
            matchup = [row for row in thief_rows if row["detective_agent"] == detective_name]
            print_win_rate_line(f"  vs {detective_name}", matchup)

        print_win_rate_line("  GLOBAL", thief_rows)

    print_win_rate_line("- GLOBAL GERAL", rows)


def print_win_rate_line(label: str, rows: list[Row]) -> None:
    total_matches = len(rows)
    wins = sum(int(row["won"]) for row in rows)
    losses = sum(int(row["lost"]) for row in rows)
    draws = total_matches - wins - losses
    decided_matches = wins + losses

    win_rate_text = f"{wins / decided_matches:.2%}" if decided_matches else "N/A"
    loss_rate_text = f"{losses / decided_matches:.2%}" if decided_matches else "N/A"
    draw_rate = draws / total_matches if total_matches else 0.0

    print(
        f"{label}: "
        f"{ANSI_GREEN}vitórias {win_rate_text} ({wins}){ANSI_RESET} | "
        f"{ANSI_RED}derrotas {loss_rate_text} ({losses}){ANSI_RESET} | "
        f"empates {draw_rate:.2%} ({draws}) | "
        f"total {total_matches}"
    )


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    fieldnames = list(rows[0].keys())
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, data: Any) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
