#!/usr/bin/env python3
"""Daily German public-procurement matcher and Slack reporter.

Uses the official Bekanntmachungsservice Open Data API.  The bulk CSV export
is filtered locally; the public notice endpoint is queried only for likely
matches so the Slack report can include deadlines and document links.
"""

from __future__ import annotations

import argparse
import csv
import io
import json
import logging
import os
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable
from zoneinfo import ZoneInfo


API_ROOT = "https://oeffentlichevergabe.de"
USER_AGENT = "ausschreibung-monitor/1.0 (+private tender notification service)"
LOG = logging.getLogger("ausschreibung-monitor")


def split_setting(name: str) -> tuple[str, ...]:
    """Read a semicolon-separated setting, preserving spaces in phrases."""
    return tuple(item.strip() for item in os.getenv(name, "").split(";") if item.strip())


def load_match_settings() -> dict[str, Any]:
    path = os.getenv("AUSSCHREIBUNG_CONFIG_FILE", "").strip()
    if not path:
        return {}
    try:
        value = json.loads(Path(path).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ValueError(f"cannot read matching configuration {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"matching configuration {path} must contain a JSON object")
    return value


def list_setting(settings: dict[str, Any], key: str, env_name: str) -> tuple[str, ...]:
    if key not in settings:
        return split_setting(env_name)
    value = settings[key]
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValueError(f"{key} must be a list of strings")
    return tuple(item.strip() for item in value if item.strip())


def int_setting(settings: dict[str, Any], key: str, env_name: str, default: int) -> int:
    try:
        return int(settings.get(key, os.getenv(env_name, str(default))))
    except ValueError as exc:
        raise ValueError(f"{key} must be an integer") from exc


@dataclass(frozen=True)
class Config:
    slack_webhook_url: str
    keywords: tuple[str, ...]
    exclude_keywords: tuple[str, ...]
    cpv_prefixes: tuple[str, ...]
    nuts_prefixes: tuple[str, ...]
    postcode_prefixes: tuple[str, ...]
    minimum_score: int
    maximum_results: int
    initial_lookback_days: int
    state_file: Path
    timezone: ZoneInfo

    @classmethod
    def from_environment(cls, *, require_slack: bool = True) -> "Config":
        settings = load_match_settings()
        webhook = os.getenv("AUSSCHREIBUNG_SLACK_WEBHOOK_URL", "").strip()
        keywords = list_setting(settings, "keywords", "AUSSCHREIBUNG_KEYWORDS")
        cpv_prefixes = tuple(
            value.replace("-", "").strip()
            for value in list_setting(settings, "cpv_prefixes", "AUSSCHREIBUNG_CPV_PREFIXES")
        )
        if require_slack and not webhook:
            raise ValueError("AUSSCHREIBUNG_SLACK_WEBHOOK_URL is not configured")
        if not keywords and not cpv_prefixes:
            raise ValueError(
                "Configure AUSSCHREIBUNG_KEYWORDS and/or AUSSCHREIBUNG_CPV_PREFIXES"
            )

        timezone_name = os.getenv("AUSSCHREIBUNG_TIMEZONE", "Europe/Berlin")
        return cls(
            slack_webhook_url=webhook,
            keywords=keywords,
            exclude_keywords=list_setting(
                settings, "exclude_keywords", "AUSSCHREIBUNG_EXCLUDE_KEYWORDS"
            ),
            cpv_prefixes=cpv_prefixes,
            nuts_prefixes=list_setting(
                settings, "nuts_prefixes", "AUSSCHREIBUNG_NUTS_PREFIXES"
            ),
            postcode_prefixes=list_setting(
                settings, "postcode_prefixes", "AUSSCHREIBUNG_POSTCODE_PREFIXES"
            ),
            minimum_score=int_setting(
                settings, "minimum_score", "AUSSCHREIBUNG_MINIMUM_SCORE", 5
            ),
            maximum_results=max(
                1,
                min(
                    int_setting(
                        settings,
                        "maximum_results",
                        "AUSSCHREIBUNG_MAXIMUM_RESULTS",
                        10,
                    ),
                    20,
                ),
            ),
            initial_lookback_days=max(
                1,
                min(
                    int_setting(
                        settings,
                        "initial_lookback_days",
                        "AUSSCHREIBUNG_INITIAL_LOOKBACK_DAYS",
                        7,
                    ),
                    31,
                ),
            ),
            state_file=Path(
                os.getenv(
                    "AUSSCHREIBUNG_STATE_FILE",
                    "/var/lib/ausschreibung-monitor/state.json",
                )
            ),
            timezone=ZoneInfo(timezone_name),
        )


def normalized(value: Any) -> str:
    text = unicodedata.normalize("NFKD", str(value or "")).casefold()
    return "".join(character for character in text if not unicodedata.combining(character))


def fetch_bytes(url: str, *, data: bytes | None = None, content_type: str | None = None) -> bytes:
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json, application/zip"}
    if content_type:
        headers["Content-Type"] = content_type
    request = urllib.request.Request(url, data=data, headers=headers, method="POST" if data else "GET")
    delays = (0, 2, 5, 15)
    last_error: Exception | None = None
    for delay in delays:
        if delay:
            time.sleep(delay)
        try:
            with urllib.request.urlopen(request, timeout=90) as response:
                return response.read()
        except (urllib.error.URLError, TimeoutError, OSError) as exc:
            last_error = exc
            LOG.warning("request failed (%s), retrying: %s", url, exc)
    assert last_error is not None
    raise last_error


def download_export(day: date) -> bytes:
    query = urllib.parse.urlencode({"pubDay": day.isoformat(), "format": "csv.zip"})
    return fetch_bytes(f"{API_ROOT}/api/notice-exports?{query}")


def csv_rows(archive: zipfile.ZipFile, filename: str) -> Iterable[dict[str, str]]:
    try:
        payload = archive.read(filename)
    except KeyError:
        return ()
    text = io.TextIOWrapper(io.BytesIO(payload), encoding="utf-8-sig", newline="")
    return csv.DictReader(text)


def append_unique(values: list[str], value: str | None) -> None:
    if value and value not in values:
        values.append(value)


def parse_export(payload: bytes) -> list[dict[str, Any]]:
    if not payload:
        return []
    with zipfile.ZipFile(io.BytesIO(payload)) as archive:
        if not archive.namelist():
            return []

        notices: dict[tuple[str, str], dict[str, Any]] = {}
        for row in csv_rows(archive, "notice.csv"):
            # competition = a new call; change = a corrected/updated call.
            if row.get("formType") not in {"competition", "change"}:
                continue
            key = (row["noticeIdentifier"], row["noticeVersion"])
            notices[key] = {
                **row,
                "titles": [],
                "descriptions": [],
                "cpv_codes": [],
                "places": [],
                "buyers": [],
                "values": [],
            }

        def candidate_for(row: dict[str, str]) -> dict[str, Any] | None:
            return notices.get((row.get("noticeIdentifier", ""), row.get("noticeVersion", "")))

        for row in csv_rows(archive, "purpose.csv"):
            candidate = candidate_for(row)
            if not candidate:
                continue
            append_unique(candidate["titles"], row.get("title"))
            append_unique(candidate["descriptions"], row.get("description"))
            value = row.get("estimatedValue")
            if value:
                append_unique(candidate["values"], f"{value} {row.get('estimatedValueCurrency', '')}".strip())

        for row in csv_rows(archive, "classification.csv"):
            candidate = candidate_for(row)
            if not candidate or row.get("classificationType") != "cpv":
                continue
            append_unique(candidate["cpv_codes"], row.get("mainClassificationCode"))
            for code in (row.get("additionalClassificationCodes") or "").replace(",", ";").split(";"):
                append_unique(candidate["cpv_codes"], code.strip())

        for row in csv_rows(archive, "placeOfPerformance.csv"):
            candidate = candidate_for(row)
            if not candidate:
                continue
            place = {
                "city": row.get("placePerformanceCity", ""),
                "postcode": row.get("placePerformancePostCode", ""),
                "nuts": row.get("placePerformanceCountrySubdivision", ""),
            }
            if place not in candidate["places"]:
                candidate["places"].append(place)

        for row in csv_rows(archive, "organisation.csv"):
            candidate = candidate_for(row)
            if candidate and row.get("organisationRole") == "buyer":
                append_unique(candidate["buyers"], row.get("organisationName"))

        return list(notices.values())


def region_matches(candidate: dict[str, Any], config: Config) -> bool:
    if not config.nuts_prefixes and not config.postcode_prefixes:
        return True
    for place in candidate["places"]:
        if any(place["nuts"].startswith(prefix) for prefix in config.nuts_prefixes):
            return True
        if any(place["postcode"].startswith(prefix) for prefix in config.postcode_prefixes):
            return True
    return False


def score_candidate(candidate: dict[str, Any], config: Config) -> tuple[int, list[str]] | None:
    if not region_matches(candidate, config):
        return None

    title = normalized(" ".join(candidate["titles"]))
    description = normalized(" ".join(candidate["descriptions"]))
    buyers = normalized(" ".join(candidate["buyers"]))
    searchable = " ".join((title, description, buyers))
    for excluded in config.exclude_keywords:
        if normalized(excluded) in searchable:
            return None

    score = 0
    reasons: list[str] = []
    for keyword in config.keywords:
        needle = normalized(keyword)
        if not needle:
            continue
        if needle in title:
            score += 8
            reasons.append(f'„{keyword}“ im Titel')
        elif needle in description:
            score += 4
            reasons.append(f'„{keyword}“ in der Beschreibung')
        elif needle in buyers:
            score += 2
            reasons.append(f'„{keyword}“ beim Auftraggeber')

    matching_cpv = sorted(
        {
            code
            for code in candidate["cpv_codes"]
            if any(code.startswith(prefix) for prefix in config.cpv_prefixes)
        }
    )
    if matching_cpv:
        score += 8
        reasons.append("CPV " + ", ".join(matching_cpv[:3]))

    if score < config.minimum_score:
        return None
    return score, reasons


def text_values(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [str(item.get("value", "")).strip() for item in value if isinstance(item, dict) and item.get("value")]


def first_deadline(lots: list[dict[str, Any]]) -> str | None:
    values: list[str] = []
    for lot in lots:
        terms = lot.get("submissionTerms") or {}
        for field in ("deadlineReceiptTenders", "deadlineReceiptRequests"):
            if terms.get(field):
                values.append(str(terms[field]))
    return min(values) if values else None


def notice_url(candidate: dict[str, Any]) -> str:
    identifier = urllib.parse.quote(candidate["noticeIdentifier"])
    version = urllib.parse.quote(candidate["noticeVersion"])
    return f"{API_ROOT}/ui/notices/{identifier}?noticeVersion={version}"


def enrich_candidate(candidate: dict[str, Any]) -> dict[str, Any]:
    identifier = urllib.parse.quote(candidate["noticeIdentifier"])
    query = urllib.parse.urlencode({"format": "domain", "noticeVersion": candidate["noticeVersion"]})
    try:
        detail = json.loads(fetch_bytes(f"{API_ROOT}/api/notices/{identifier}?{query}"))
    except Exception as exc:  # Keep the bulk-export result if one detail call fails.
        LOG.warning("could not enrich notice %s: %s", candidate["noticeIdentifier"], exc)
        candidate["url"] = notice_url(candidate)
        return candidate

    lots = detail.get("lots") or []
    purpose = detail.get("purpose") or {}
    titles = text_values(purpose.get("title"))
    descriptions = text_values(purpose.get("description"))
    document_urls: list[str] = []
    for lot in lots:
        lot_purpose = lot.get("purpose") or {}
        titles.extend(text_values(lot_purpose.get("title")))
        descriptions.extend(text_values(lot_purpose.get("description")))
        for document in lot.get("procurementDocuments") or []:
            if document.get("url"):
                append_unique(document_urls, document["url"])
        submission_url = (lot.get("submissionTerms") or {}).get("submissionUrl")
        append_unique(document_urls, submission_url)

    organisations = {
        item.get("partyIdentification"): item.get("organisationName")
        for item in detail.get("organisation") or []
        if item.get("partyIdentification") and item.get("organisationName")
    }
    buyer_names = [
        organisations[buyer.get("organisationReference")]
        for buyer in detail.get("buyers") or []
        if buyer.get("organisationReference") in organisations
    ]

    if titles:
        candidate["titles"] = list(dict.fromkeys(titles))
    if descriptions:
        candidate["descriptions"] = list(dict.fromkeys(descriptions))
    if buyer_names:
        candidate["buyers"] = list(dict.fromkeys(buyer_names))
    candidate["deadline"] = first_deadline(lots)
    candidate["documents_url"] = document_urls[0] if document_urls else None
    candidate["url"] = notice_url(candidate)
    return candidate


def deadline_is_open(candidate: dict[str, Any], now: datetime) -> bool:
    deadline = candidate.get("deadline")
    if not deadline:
        return True
    try:
        parsed = datetime.fromisoformat(deadline)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=now.tzinfo)
        return parsed > now
    except ValueError:
        return True


def format_deadline(value: str | None, timezone: ZoneInfo) -> str:
    if not value:
        return "nicht angegeben"
    try:
        parsed = datetime.fromisoformat(value)
        if parsed.tzinfo:
            parsed = parsed.astimezone(timezone)
        return parsed.strftime("%d.%m.%Y, %H:%M")
    except ValueError:
        return value


def slack_escape(value: str) -> str:
    return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def build_slack_payload(matches: list[dict[str, Any]], start: date, end: date, config: Config) -> dict[str, Any]:
    period = end.isoformat() if start == end else f"{start.isoformat()} bis {end.isoformat()}"
    if not matches:
        text = f"Ausschreibungen: keine passenden neuen Bekanntmachungen ({period})."
        return {
            "text": text,
            "blocks": [
                {"type": "header", "text": {"type": "plain_text", "text": "Ausschreibungen: keine Treffer"}},
                {"type": "section", "text": {"type": "mrkdwn", "text": slack_escape(f"Zeitraum: {period}")}},
            ],
        }

    shown = matches[: config.maximum_results]
    text = f"Ausschreibungen: {len(matches)} passende neue Bekanntmachung(en) ({period})."
    blocks: list[dict[str, Any]] = [
        {"type": "header", "text": {"type": "plain_text", "text": f"Ausschreibungen: {len(matches)} Treffer"}},
        {"type": "context", "elements": [{"type": "mrkdwn", "text": slack_escape(f"Zeitraum: {period} · sortiert nach Relevanz")}]},
    ]
    for candidate in shown:
        title = slack_escape((candidate["titles"] or ["Ohne Titel"])[0][:240])
        url = candidate.get("url") or notice_url(candidate)
        buyer = slack_escape(", ".join(candidate["buyers"][:2]) or "Auftraggeber nicht angegeben")
        places = ", ".join(
            filter(None, (" ".join(filter(None, (place["postcode"], place["city"]))).strip() for place in candidate["places"][:3]))
        ) or "Ort nicht angegeben"
        why = slack_escape("; ".join(candidate["reasons"][:4]))
        deadline = slack_escape(format_deadline(candidate.get("deadline"), config.timezone))
        document_link = ""
        if candidate.get("documents_url"):
            document_link = f" · <{candidate['documents_url']}|Vergabeunterlagen>"
        body = (
            f"*<{url}|{title}>*  `Score {candidate['score']}`\n"
            f"{buyer} · {slack_escape(places)}\n"
            f"*Frist:* {deadline}{document_link}\n"
            f"*Treffergrund:* {why}"
        )
        blocks.append({"type": "section", "text": {"type": "mrkdwn", "text": body}})
        blocks.append({"type": "divider"})
    if len(matches) > len(shown):
        blocks.append({
            "type": "context",
            "elements": [{"type": "mrkdwn", "text": f"{len(matches) - len(shown)} weitere Treffer wegen Berichtslimit ausgelassen."}],
        })
    return {"text": text, "blocks": blocks[:50]}


def load_state(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        return {}
    except (json.JSONDecodeError, OSError) as exc:
        raise RuntimeError(f"cannot read state file {path}: {exc}") from exc


def save_state(path: Path, end: date) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(
        json.dumps({"last_processed_date": end.isoformat()}, indent=2) + "\n",
        encoding="utf-8",
    )
    temporary.replace(path)


def date_range(start: date, end: date) -> Iterable[date]:
    current = start
    while current <= end:
        yield current
        current += timedelta(days=1)


def post_to_slack(webhook: str, payload: dict[str, Any]) -> None:
    response = fetch_bytes(
        webhook,
        data=json.dumps(payload, ensure_ascii=False).encode("utf-8"),
        content_type="application/json; charset=utf-8",
    )
    if response.strip() != b"ok":
        raise RuntimeError(f"Slack webhook returned unexpected response: {response[:200]!r}")


def run(args: argparse.Namespace) -> int:
    config = Config.from_environment(require_slack=not args.dry_run)
    now = datetime.now(config.timezone)
    end = date.fromisoformat(args.day) if args.day else now.date() - timedelta(days=1)

    if args.source_zip:
        start = end
        exports = [(end, Path(args.source_zip).read_bytes())]
    else:
        state = load_state(config.state_file)
        if state.get("last_processed_date"):
            start = date.fromisoformat(state["last_processed_date"]) + timedelta(days=1)
        else:
            start = end - timedelta(days=config.initial_lookback_days - 1)
        if start > end:
            LOG.info("already processed through %s", end)
            return 0
        exports = []
        for day in date_range(start, end):
            LOG.info("downloading notices for %s", day)
            exports.append((day, download_export(day)))

    candidates: list[dict[str, Any]] = []
    for day, payload in exports:
        parsed = parse_export(payload)
        LOG.info("%s: %d open or changed notices", day, len(parsed))
        candidates.extend(parsed)

    matches: list[dict[str, Any]] = []
    for candidate in candidates:
        result = score_candidate(candidate, config)
        if result:
            candidate["score"], candidate["reasons"] = result
            matches.append(candidate)
    matches.sort(key=lambda item: (-item["score"], item["noticeIdentifier"]))

    # Limit detail calls while leaving room for notices whose deadline has passed.
    enriched = [enrich_candidate(item) for item in matches[: config.maximum_results * 3]]
    matches = [item for item in enriched if deadline_is_open(item, now)]
    matches.sort(key=lambda item: (-item["score"], item.get("deadline") or "9999"))

    payload = build_slack_payload(matches, start, end, config)
    if args.dry_run:
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0

    post_to_slack(config.slack_webhook_url, payload)
    save_state(config.state_file, end)
    LOG.info("reported %d matches and advanced state through %s", len(matches), end)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="print the Slack payload without posting or updating state")
    parser.add_argument("--source-zip", help="read one CSV export ZIP instead of downloading")
    parser.add_argument("--day", help="publication day (YYYY-MM-DD); defaults to yesterday")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    try:
        return run(args)
    except Exception as exc:
        LOG.exception("monitor failed: %s", exc)
        return 1


if __name__ == "__main__":
    sys.exit(main())
