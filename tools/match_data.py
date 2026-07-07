"""Parsing, normalization, and scoring helpers for match evaluation data."""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from statistics import mean
from typing import Any


DEFAULT_WEIGHTS: dict[str, float] = {
    "vit": 1000.0,
    "turn": 10.0,
    "pist": 15.0,
    "risk": 25.0,
    "mov": 5.0,
}

LOG_RE = re.compile(r"^(?P<turn>\d+)\s+(?P<role>ladrao|detetive):\s+(?P<action>.*)\[(?P<status>OK|Ilegal)\]$")
EVENT_RE = re.compile(r"^>>>> Evento (?P<event>roubo\(.*\))$")
RESULT_RE = re.compile(r"^__RESULT__=(?P<winner>\w+)$")
STATE_RE = re.compile(r"^__STATE__=(?P<state>gSt\(.*\))$")
MOVE_RE = re.compile(r"^move\((?P<from>[^,]+),(?P<to>[^)]+)\)$")
ROBBERY_RE = re.compile(r"^roubo\((?P<item>.*),(?P<city>[^,]+),\[(?P<attrs>.*)\]\)$")

Row = dict[str, Any]


@dataclass(frozen=True)
class Scenario:
    path: Path
    cities: list[str]
    edges: list[tuple[str, str]]
    suspects: dict[int, list[str]]
    max_turns: int


def parse_output(stdout: str, stderr: str, seed: int) -> dict:
    logs = []
    events = []
    state = ""
    winner = "unknown"
    pending_events = []

    for raw_line in stdout.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        state_match = STATE_RE.match(line)
        if state_match:
            state = state_match.group("state")
            continue
        result_match = RESULT_RE.match(line)
        if result_match:
            winner = result_match.group("winner")
            continue
        event_match = EVENT_RE.match(line)
        if event_match:
            event = parse_robbery(event_match.group("event"))
            pending_events.append(event)
            events.append(event)
            continue
        log_match = LOG_RE.match(line)
        if log_match:
            entry = log_match.groupdict()
            entry["turn"] = int(entry["turn"])
            entry["events"] = pending_events
            pending_events = []
            logs.append(entry)

    return {
        "seed": seed,
        "winner": winner,
        "state": state,
        "setup": parse_initial_state(state),
        "logs": logs,
        "events": events,
        "stderr": stderr,
        "stdout": stdout,
    }


def parse_robbery(text: str) -> dict:
    match = ROBBERY_RE.match(text)
    if not match:
        return {"type": "unknown", "raw": text}
    attrs = split_top_level(match.group("attrs")) if match.group("attrs") else []
    return {
        "type": "robbery",
        "item": match.group("item"),
        "city": match.group("city"),
        "revealed": attrs,
        "raw": text,
    }


def parse_initial_state(state: str) -> dict[str, object]:
    if not state.startswith("gSt("):
        return {}
    args = split_top_level(state[4:-1])
    if len(args) < 7:
        return {}
    thief = args[0]
    detective = args[1]
    setup: dict[str, object] = {"max_turns": int(args[6]) if args[6].isdigit() else 0}
    thief_match = re.match(r"^thief\(loc\(([^)]+)\),([^,]+),aparencia\((\[.*\])\),([^,]+),", thief)
    if thief_match:
        setup["thief_start"] = thief_match.group(1)
        setup["thief_id"] = thief_match.group(2)
        setup["appearance"] = split_list(thief_match.group(3))
        setup["target"] = thief_match.group(4)
    det_match = re.match(r"^detective\(loc\(([^)]+)\),", detective)
    if det_match:
        setup["detective_start"] = det_match.group(1)
    return setup


def split_list(text: str) -> list[str]:
    if not (text.startswith("[") and text.endswith("]")):
        return []
    inner = text[1:-1]
    if not inner:
        return []
    return split_top_level(inner)


def split_top_level(text: str) -> list[str]:
    parts = []
    start = 0
    depth = 0
    for idx, char in enumerate(text):
        if char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif char == "," and depth == 0:
            parts.append(text[start:idx].strip())
            start = idx + 1
    tail = text[start:].strip()
    if tail:
        parts.append(tail)
    return parts


def parse_scenario(path_value: str | Path) -> Scenario:
    path = Path(path_value).resolve()
    text = path.read_text(encoding="utf-8")
    cities = re.findall(r"^\s*cidade\(([^)]+)\)\.", text, re.MULTILINE)
    edges = re.findall(r"^\s*conectado\(([^,]+),([^)]+)\)\.", text, re.MULTILINE)
    max_turns_match = re.search(r"^\s*max_turnos\((\d+)\)\.", text, re.MULTILINE)
    suspects = parse_suspects(text)
    return Scenario(
        path=path,
        cities=cities,
        edges=[(a.strip(), b.strip()) for a, b in edges],
        suspects=suspects,
        max_turns=int(max_turns_match.group(1)) if max_turns_match else 0,
    )


def parse_suspects(text: str) -> dict[int, list[str]]:
    suspects = {}
    pos = 0
    marker = "procurado("
    while True:
        idx = text.find(marker, pos)
        if idx == -1:
            break
        end = find_fact_end(text, idx)
        if end == -1:
            break
        fact = text[idx:end]
        id_match = re.match(r"procurado\((\d+),", fact.strip())
        attrs_start = fact.find("aparencia([")
        if id_match and attrs_start != -1:
            list_start = fact.find("[", attrs_start)
            list_end = find_matching(fact, list_start, "[", "]")
            if list_end != -1:
                suspects[int(id_match.group(1))] = split_top_level(fact[list_start + 1:list_end])
        pos = end + 1
    return suspects


def find_fact_end(text: str, start: int) -> int:
    depth = 0
    for idx in range(start, len(text)):
        char = text[idx]
        if char in "([":
            depth += 1
        elif char in ")]":
            depth -= 1
        elif char == "." and depth == 0:
            return idx
    return -1


def find_matching(text: str, start: int, open_char: str, close_char: str) -> int:
    depth = 0
    for idx in range(start, len(text)):
        char = text[idx]
        if char == open_char:
            depth += 1
        elif char == close_char:
            depth -= 1
            if depth == 0:
                return idx
    return -1


def score_match(raw: dict, scenario: Scenario, weights: dict[str, float]) -> dict:
    logs = raw["logs"]
    events = raw["events"]
    setup = raw["setup"]
    winner = raw["winner"]
    real_attrs = set(setup.get("appearance", []))
    articulation = articulation_points(scenario.cities, scenario.edges)

    thief_logs = [log for log in logs if log["role"] == "ladrao"]
    detective_logs = [log for log in logs if log["role"] == "detetive"]
    turns_spent = len(thief_logs)
    won = 1 if winner == "ladrao" else 0
    draw = 1 if winner == "empate" else 0
    lost = 1 if winner == "detetive" else 0

    real_revealed_total = sum(1 for event in events for attr in event.get("revealed", []) if attr in real_attrs)
    total_revealed = sum(len(event.get("revealed", [])) for event in events)
    illegal_actions = sum(1 for log in logs if log["status"] == "Ilegal")
    disguises_used = sum(1 for log in thief_logs if log["action"].startswith("disfarce(") and log["status"] == "OK")
    robberies = len(events)

    positions = thief_positions(setup.get("thief_start", ""), thief_logs)
    bottleneck_turns = sum(1 for city in positions if city in articulation)
    recent_city_turns = count_recent_revealed_city_turns(setup.get("thief_start", ""), thief_logs)
    mandate_risk_events = count_mandate_risk_events(events, scenario.suspects, real_attrs)
    risk = bottleneck_turns + recent_city_turns + mandate_risk_events
    no_progress_moves = count_no_progress_moves(setup.get("thief_start", ""), thief_logs)

    score = (
        weights["vit"] * won
        - weights["turn"] * turns_spent
        - weights["pist"] * real_revealed_total
        - weights["risk"] * risk
        - weights["mov"] * no_progress_moves
    )

    return {
        "winner": winner,
        "won": won,
        "draw": draw,
        "lost": lost,
        "score": round(score, 4),
        "turns_spent": turns_spent,
        "robberies": robberies,
        "revealed_attrs_total": total_revealed,
        "real_revealed_attrs": real_revealed_total,
        "risk": risk,
        "bottleneck_turns": bottleneck_turns,
        "recent_revealed_city_turns": recent_city_turns,
        "mandate_risk_events": mandate_risk_events,
        "no_progress_moves": no_progress_moves,
        "illegal_actions": illegal_actions,
        "disguises_used": disguises_used,
        "thief_start": setup.get("thief_start", ""),
        "detective_start": setup.get("detective_start", ""),
        "thief_id": setup.get("thief_id", ""),
        "target": setup.get("target", ""),
        "loss_reason": loss_reason(winner, thief_logs, detective_logs),
    }


def thief_positions(start: str, thief_logs: list[dict]) -> list[str]:
    city = start
    positions = []
    for log in thief_logs:
        move = MOVE_RE.match(log["action"])
        if log["status"] == "OK" and move:
            city = move.group("to")
        positions.append(city)
    return positions


def count_recent_revealed_city_turns(start: str, thief_logs: list[dict]) -> int:
    city = start
    recent = []
    count = 0
    for log in thief_logs:
        move = MOVE_RE.match(log["action"])
        if log["status"] == "OK" and move:
            city = move.group("to")
        if city in recent:
            count += 1
        for event in log.get("events", []):
            if event.get("type") == "robbery":
                recent.append(event["city"])
        recent = recent[-2:]
    return count


def count_no_progress_moves(start: str, thief_logs: list[dict]) -> int:
    city = start
    visited = {city} if city else set()
    no_progress = 0
    for log in thief_logs:
        if log["action"] == "nada" and log["status"] == "OK":
            no_progress += 1
            continue
        move = MOVE_RE.match(log["action"])
        if log["status"] == "OK" and move:
            city = move.group("to")
            if city in visited:
                no_progress += 1
            visited.add(city)
    return no_progress


def count_mandate_risk_events(events: list[dict], suspects: dict[int, list[str]], real_attrs: set[str]) -> int:
    accumulated = []
    count = 0
    for event in events:
        for attr in event.get("revealed", []):
            if attr in real_attrs and attr not in accumulated:
                accumulated.append(attr)
        if accumulated and len(compatible_suspects(accumulated, suspects)) <= 2:
            count += 1
    return count


def compatible_suspects(attrs: list[str], suspects: dict[int, list[str]]) -> list[int]:
    result = []
    for suspect_id, suspect_attrs in suspects.items():
        if all(attr in suspect_attrs for attr in attrs):
            result.append(suspect_id)
    return result


def loss_reason(winner: str, thief_logs: list[dict], detective_logs: list[dict]) -> str:
    if winner == "ladrao":
        return ""
    if winner == "empate":
        return "timeout"
    last_detective = detective_logs[-1]["action"] if detective_logs else ""
    last_thief = thief_logs[-1]["action"] if thief_logs else ""
    if last_detective == "inspecionar":
        return "inspection"
    if last_thief.startswith("move("):
        return "closed_city"
    return "detective"


def articulation_points(cities: list[str], edges: list[tuple[str, str]]) -> set[str]:
    graph: dict[str, set[str]] = {city: set() for city in cities}
    for a, b in edges:
        graph.setdefault(a, set()).add(b)
        graph.setdefault(b, set()).add(a)

    sys.setrecursionlimit(max(sys.getrecursionlimit(), len(graph) * 2 + 100))

    time = 0
    disc: dict[str, int] = {}
    low: dict[str, int] = {}
    parent: dict[str, str] = {}
    points: set[str] = set()

    def dfs(u: str) -> None:
        nonlocal time
        children = 0
        time += 1
        disc[u] = low[u] = time
        for v in graph.get(u, []):
            if v not in disc:
                parent[v] = u
                children += 1
                dfs(v)
                low[u] = min(low[u], low[v])
                if u not in parent and children > 1:
                    points.add(u)
                if u in parent and low[v] >= disc[u]:
                    points.add(u)
            elif parent.get(u) != v:
                low[u] = min(low[u], disc[v])

    for city in graph:
        if city not in disc:
            dfs(city)
    return points


def summarize(rows: list[Row]) -> list[Row]:
    grouped: defaultdict[tuple[Any, Any, Any], list[Row]] = defaultdict(list)
    for row in rows:
        grouped[(row["thief_agent"], row["detective_agent"], row["scenario"])].append(row)
        grouped[(row["thief_agent"], "ALL", row["scenario"])].append(row)

    summary: list[Row] = []
    for (thief, detective, scenario), group in grouped.items():
        scores = [float(row["score"]) for row in group]
        summary.append({
            "thief_agent": thief,
            "detective_agent": detective,
            "scenario": scenario,
            "rounds": len(group),
            "score_mean": round(mean(scores), 4),
            "score_best": round(max(scores), 4),
            "score_worst": round(min(scores), 4),
            "win_rate": round(mean(int(row["won"]) for row in group), 4),
            "draw_rate": round(mean(int(row["draw"]) for row in group), 4),
            "loss_rate": round(mean(int(row["lost"]) for row in group), 4),
            "turns_mean": round(mean(int(row["turns_spent"]) for row in group), 4),
            "robberies_mean": round(mean(int(row["robberies"]) for row in group), 4),
            "real_revealed_attrs_mean": round(mean(int(row["real_revealed_attrs"]) for row in group), 4),
            "risk_mean": round(mean(int(row["risk"]) for row in group), 4),
            "no_progress_moves_mean": round(mean(int(row["no_progress_moves"]) for row in group), 4),
            "best_run_id": max(group, key=lambda row: float(row["score"]))["run_id"],
            "worst_run_id": min(group, key=lambda row: float(row["score"]))["run_id"],
        })
    return summary


def best_worst(rows: list[Row]) -> list[Row]:
    grouped: defaultdict[tuple[Any, Any, Any], list[Row]] = defaultdict(list)
    for row in rows:
        grouped[(row["thief_agent"], row["detective_agent"], row["scenario"])].append(row)
        grouped[(row["thief_agent"], "ALL", row["scenario"])].append(row)
    output: list[Row] = []
    for (thief, detective, scenario), group in grouped.items():
        best = dict(max(group, key=lambda row: float(row["score"])))
        worst = dict(min(group, key=lambda row: float(row["score"])))
        best["thief_agent"] = thief
        best["detective_agent"] = detective
        best["scenario"] = scenario
        worst["thief_agent"] = thief
        worst["detective_agent"] = detective
        worst["scenario"] = scenario
        best["kind"] = "best"
        worst["kind"] = "worst"
        output.extend([best, worst])
    return output

