#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from pathlib import Path


CSV_HEADER = [
    "Account",
    "Funding Account",
    "Date",
    "Shares",
    "Price",
    "Amount",
    "Tax",
    "Note",
]

OFFICIAL_SOURCES = [
    (
        "twse",
        "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL",
        "Code",
        "Name",
    ),
    (
        "tpex",
        "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes",
        "SecuritiesCompanyCode",
        "CompanyName",
    ),
    (
        "esb",
        "https://www.tpex.org.tw/openapi/v1/tpex_esb_latest_statistics",
        "SecuritiesCompanyCode",
        "CompanyName",
    ),
]

SUPPORTED_SUFFIXES = {".pdf", ".csv"}

TRADE_LINE_RE = re.compile(
    r"^(?P<date>\d{3}/\d{2}/\d{2})\s+"
    r"(?P<cd>\S+)\s+"
    r"(?P<name>.+?)\s+"
    r"(?P<shares>[\d,]+)\s+"
    r"(?P<price>[\d,]+(?:\.\d+)?)\s+"
    r"(?P<rest>.+?)\s+"
    r"(?P<net>[\d,]+)\((?P<direction>收|付)\)\s+"
    r"(?P<order>\S+)$"
)

ORDER_RE = re.compile(r"\b[A-Za-z0-9]-[A-Za-z0-9]+-\d+\b")


@dataclass(frozen=True)
class CathayTrade:
    date: str
    cd: str
    name: str
    shares: int
    price: Decimal
    amount: int
    tax: int
    net: int
    order: str
    source: str


class ConversionError(Exception):
    pass


def warn(message: str) -> None:
    print(f"warning: {message}", file=sys.stderr)


def normalize_name(value: str) -> str:
    return re.sub(r"\s+", "", value.strip().replace("\u3000", " "))


def parse_int(value: str) -> int:
    return int(value.replace(",", "").strip())


def parse_decimal(value: str) -> Decimal:
    try:
        return Decimal(value.replace(",", "").strip())
    except InvalidOperation as exc:
        raise ConversionError(f"invalid decimal: {value}") from exc


def format_decimal(value: Decimal) -> str:
    text = format(value, "f")
    if "." in text:
        text = text.rstrip("0").rstrip(".")
    return text


def canonical_int_text(value: str) -> str:
    try:
        return str(parse_int(value))
    except ValueError:
        return value.strip()


def canonical_decimal_text(value: str) -> str:
    try:
        return format_decimal(parse_decimal(value))
    except ConversionError:
        return value.strip()


def roc_date_to_iso(value: str) -> str:
    year_s, month_s, day_s = value.split("/")
    return f"{int(year_s) + 1911:04d}-{int(month_s):02d}-{int(day_s):02d}"


def expand_inputs(paths: list[Path], recursive: bool = True) -> list[Path]:
    expanded: list[Path] = []
    for raw_path in paths:
        path = raw_path.expanduser()
        if not path.exists():
            raise ConversionError(f"input does not exist: {path}")
        if path.is_dir():
            iterator = path.rglob("*") if recursive else path.glob("*")
            for child in iterator:
                if child.is_file() and child.suffix.lower() in SUPPORTED_SUFFIXES:
                    expanded.append(child)
        elif path.is_file() and path.suffix.lower() in SUPPORTED_SUFFIXES:
            expanded.append(path)
        else:
            warn(f"ignored unsupported input: {path}")

    unique_sorted = sorted(dict.fromkeys(expanded), key=lambda p: str(p))
    if not unique_sorted:
        raise ConversionError("no PDF or CSV inputs found")
    return unique_sorted


def extract_pdf_text_with_pdfkit(path: Path) -> str:
    swift_code = r'''
import Foundation
import PDFKit

guard let path = ProcessInfo.processInfo.environment["PDF_PATH"] else {
    fputs("PDF_PATH is missing\n", stderr)
    exit(2)
}

guard let doc = PDFDocument(url: URL(fileURLWithPath: path)) else {
    fputs("Cannot open PDF: \(path)\n", stderr)
    exit(3)
}

for i in 0..<doc.pageCount {
    if let page = doc.page(at: i), let text = page.string {
        print(text)
    }
}
'''
    env = dict(os.environ)
    env["PDF_PATH"] = str(path)
    try:
        result = subprocess.run(
            ["swift", "-e", swift_code],
            env=env,
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise ConversionError("swift/PDFKit is unavailable") from exc

    if result.returncode != 0:
        raise ConversionError(
            f"PDFKit extraction failed for {path}: {result.stderr.strip()}"
        )
    return result.stdout


def extract_pdf_text_with_pdftotext(path: Path) -> str:
    if not shutil.which("pdftotext"):
        raise ConversionError("pdftotext is unavailable")

    result = subprocess.run(
        ["pdftotext", "-layout", str(path), "-"],
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        raise ConversionError(
            f"pdftotext extraction failed for {path}: {result.stderr.strip()}"
        )
    return result.stdout


def extract_pdf_text(path: Path) -> str:
    errors = []
    for extractor in (extract_pdf_text_with_pdfkit, extract_pdf_text_with_pdftotext):
        try:
            text = extractor(path)
        except ConversionError as exc:
            errors.append(str(exc))
            continue
        if text.strip():
            return text
        errors.append(f"{extractor.__name__} returned no text")

    raise ConversionError(
        "cannot extract PDF text; on macOS use Swift/PDFKit, or on Linux install "
        f"poppler/pdftotext. Tried: {'; '.join(errors)}"
    )


def parse_cathay_pdf(path: Path) -> list[CathayTrade]:
    text = extract_pdf_text(path)
    trades: list[CathayTrade] = []

    for line in text.splitlines():
        line = line.strip()
        match = TRADE_LINE_RE.match(line)
        if not match:
            continue

        cd = match.group("cd")
        if not (cd.endswith("買") or cd.endswith("賣")):
            continue

        rest_numbers = [parse_int(token) for token in match.group("rest").split()]
        if len(rest_numbers) < 2:
            raise ConversionError(f"cannot parse fee/amount columns: {line}")

        gross_amount = rest_numbers[-1]
        tax_and_fees = sum(rest_numbers[:-1])
        signed_shares = parse_int(match.group("shares"))
        if cd.endswith("賣"):
            signed_shares *= -1

        trades.append(
            CathayTrade(
                date=roc_date_to_iso(match.group("date")),
                cd=cd,
                name=match.group("name").strip(),
                shares=signed_shares,
                price=parse_decimal(match.group("price")),
                amount=gross_amount,
                tax=tax_and_fees,
                net=parse_int(match.group("net")),
                order=match.group("order"),
                source=str(path),
            )
        )

    if not trades:
        raise ConversionError(f"no Cathay trade rows found in {path}")
    return trades


def fetch_json(url: str) -> list[dict[str, str]]:
    request = urllib.request.Request(
        url,
        headers={"User-Agent": "cathay-synx-csv/1.0"},
    )

    def open_json(context: ssl.SSLContext | None = None) -> list[dict[str, str]]:
        with urllib.request.urlopen(request, timeout=30, context=context) as response:
            return json.loads(response.read().decode("utf-8-sig"))

    verified_error = None
    try:
        for attempt in range(1, 4):
            try:
                return open_json()
            except urllib.error.URLError as exc:
                verified_error = exc
                break
            except Exception as exc:
                verified_error = exc
                if attempt < 3:
                    warn(f"verified fetch failed for {url}; retrying: {exc}")
                    continue
                break
    except urllib.error.URLError as exc:
        verified_error = exc

    if verified_error:
        warn(
            f"verified fetch failed for {url}; retrying without certificate "
            f"verification: {verified_error}"
        )

    context = ssl._create_unverified_context()
    unverified_error = None
    for attempt in range(1, 4):
        try:
            return open_json(context)
        except Exception as exc:
            unverified_error = exc
            if attempt < 3:
                warn(f"unverified fetch failed for {url}; retrying: {exc}")

    raise ConversionError(
        f"cannot fetch official symbol data from {url}: {unverified_error}"
    )


class SymbolResolver:
    def __init__(self) -> None:
        self.by_market: dict[str, dict[str, set[str]]] = {}
        self.all_names: dict[str, set[str]] = {}

    def add(self, market: str, name: str, code: str) -> None:
        norm = normalize_name(name)
        if not norm or not code:
            return
        self.by_market.setdefault(market, {}).setdefault(norm, set()).add(code)
        self.all_names.setdefault(norm, set()).add(code)
        self.by_market.setdefault(market, {}).setdefault(code, set()).add(code)
        self.all_names.setdefault(code, set()).add(code)

    def load_official(self) -> None:
        loaded_rows = 0
        for market, url, code_key, name_key in OFFICIAL_SOURCES:
            try:
                data = fetch_json(url)
            except ConversionError as exc:
                warn(str(exc))
                continue
            for row in data:
                self.add(market, str(row.get(name_key, "")), str(row.get(code_key, "")))
                loaded_rows += 1
        if loaded_rows == 0:
            raise ConversionError("cannot load any official TWSE/TPEx symbol data")

    def load_manual_csv(self, path: Path) -> None:
        try:
            handle = path.open("r", newline="", encoding="utf-8-sig")
        except FileNotFoundError as exc:
            raise ConversionError(f"mapping CSV does not exist: {path}") from exc

        with handle:
            reader = csv.DictReader(handle)
            for row in reader:
                name = (
                    row.get("name")
                    or row.get("Name")
                    or row.get("股票名稱")
                    or row.get("stock_name")
                )
                code = (
                    row.get("code")
                    or row.get("Code")
                    or row.get("股票代號")
                    or row.get("symbol")
                )
                if name and code:
                    self.add("manual", name, code)

    def resolve(self, name: str, cd: str) -> str:
        norm = normalize_name(name)

        if cd.startswith("集"):
            preferred_markets = ["manual", "twse", "tpex", "esb"]
        elif cd.startswith("OT"):
            preferred_markets = ["manual", "tpex", "esb", "twse"]
        else:
            preferred_markets = ["manual", "twse", "tpex", "esb"]

        for market in preferred_markets:
            codes = self.by_market.get(market, {}).get(norm, set())
            if len(codes) == 1:
                return next(iter(codes))

        codes = self.all_names.get(norm, set())
        if len(codes) == 1:
            return next(iter(codes))
        if len(codes) > 1:
            raise ConversionError(f"ambiguous stock name {name}: {sorted(codes)}")
        raise ConversionError(f"unresolved stock name: {name}")


def synx_row_from_trade(
    trade: CathayTrade,
    resolver: SymbolResolver,
    funding_account: str,
) -> dict[str, str]:
    account = resolver.resolve(trade.name, trade.cd)
    return {
        "Account": account,
        "Funding Account": funding_account,
        "Date": trade.date,
        "Shares": str(trade.shares),
        "Price": format_decimal(trade.price),
        "Amount": str(trade.amount),
        "Tax": str(trade.tax),
        "Note": f"Cathay {trade.cd} {trade.name} {trade.order}",
    }


def extract_order_id(note: str) -> str:
    note = note or ""
    match = ORDER_RE.search(note or "")
    if match:
        return match.group(0)

    parts = note.strip().split()
    if parts and parts[0] == "Cathay":
        return parts[-1]
    return ""


def dedupe_base_key(row: dict[str, str]) -> tuple[str, ...]:
    return (
        row.get("Date", "").strip(),
        row.get("Account", "").strip(),
        canonical_int_text(row.get("Shares", "")),
        canonical_decimal_text(row.get("Price", "")),
        canonical_int_text(row.get("Amount", "")),
        canonical_int_text(row.get("Tax", "").strip() or "0"),
    )


def dedupe_rows(rows: list[dict[str, str]]) -> tuple[list[dict[str, str]], int]:
    rows_with_order: dict[tuple[str, ...], dict[str, str]] = {}
    rows_without_order: dict[tuple[str, ...], dict[str, str]] = {}
    bases_with_order: set[tuple[str, ...]] = set()
    duplicate_count = 0

    for row in rows:
        base = dedupe_base_key(row)
        order_id = extract_order_id(row.get("Note", ""))
        if order_id:
            key = (*base, order_id)
            if key in rows_with_order:
                duplicate_count += 1
                continue
            if base in rows_without_order:
                del rows_without_order[base]
                duplicate_count += 1
            rows_with_order[key] = row
            bases_with_order.add(base)
            continue

        if base in rows_without_order or base in bases_with_order:
            duplicate_count += 1
            continue
        rows_without_order[base] = row

    return [*rows_without_order.values(), *rows_with_order.values()], duplicate_count


def read_existing_synx_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        reader = csv.DictReader(handle)
        missing = [field for field in CSV_HEADER if field not in (reader.fieldnames or [])]
        if missing:
            raise ConversionError(f"{path} is missing Synx columns: {missing}")
        rows = []
        for row in reader:
            clean = {field: (row.get(field) or "").strip() for field in CSV_HEADER}
            clean["Tax"] = clean["Tax"] or "0"
            rows.append(clean)
        return rows


def sort_key(row: dict[str, str]) -> tuple[str, str, str, str, str]:
    return (
        row["Date"],
        row["Account"],
        row["Shares"].lstrip("-"),
        row["Price"],
        extract_order_id(row.get("Note", "")),
    )


def write_synx_csv(path: Path, rows: list[dict[str, str]], bom: bool) -> None:
    encoding = "utf-8-sig" if bom else "utf-8"
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            "w",
            newline="",
            encoding=encoding,
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle:
            temp_path = Path(handle.name)
            writer = csv.DictWriter(handle, fieldnames=CSV_HEADER)
            writer.writeheader()
            writer.writerows(rows)
        temp_path.replace(path)
    finally:
        if temp_path and temp_path.exists():
            temp_path.unlink()


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Convert Cathay Securities transaction-detail PDFs to Synx CSV.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=r"""
Examples:
  Convert one PDF:
    python3 cathay_pdf_to_synx_csv.py -o ~/Downloads/cathay-synx.csv \
      ~/Downloads/交易明細表-蔡○師-20260619194525-1.pdf

  Convert every PDF/CSV inside a folder, recursively, then de-dupe:
    python3 cathay_pdf_to_synx_csv.py -o ~/Downloads/cathay-synx.csv \
      ~/Downloads/cathay-pdfs

  Merge old Synx CSV with new overlapping Cathay PDFs:
    python3 cathay_pdf_to_synx_csv.py -o ~/Downloads/cathay-synx-merged.csv \
      ~/Downloads/old-cathay-synx.csv ~/Downloads/cathay-pdfs

  Add manual stock-name mapping when official data cannot resolve a name:
    python3 cathay_pdf_to_synx_csv.py --mapping ~/Downloads/name-map.csv \
      -o ~/Downloads/cathay-synx.csv ~/Downloads/cathay-pdfs

Manual mapping CSV format:
  name,code
  舊股票名稱,1234

Synx prerequisites:
  - Create investment accounts named by stock code, for example 0050 or 2330.
  - Create a non-investment funding account named 國泰交割戶, unless you pass
    --funding-account with a different existing Synx account name.
""",
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        type=Path,
        help="Cathay PDF files, existing Synx CSV files, or folders containing them.",
    )
    parser.add_argument(
        "-o",
        "--output",
        required=True,
        type=Path,
        help="Output Synx CSV path.",
    )
    parser.add_argument(
        "--funding-account",
        default="國泰交割戶",
        help="Synx non-investment funding account name. Default: 國泰交割戶.",
    )
    parser.add_argument(
        "--mapping",
        action="append",
        type=Path,
        default=[],
        help="Manual name-to-code CSV. Columns: name,code. Can be repeated.",
    )
    parser.add_argument(
        "--no-network",
        action="store_true",
        help="Do not fetch TWSE/TPEx symbol data. Use only manual mapping.",
    )
    parser.add_argument(
        "--skip-unresolved",
        action="store_true",
        help="Skip rows whose stock names cannot be resolved instead of failing.",
    )
    parser.add_argument(
        "--no-recursive",
        action="store_true",
        help="When an input is a folder, only scan files directly inside it.",
    )
    parser.add_argument(
        "--bom",
        action="store_true",
        help="Write UTF-8 BOM for easier opening in Excel. Synx does not require it.",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    input_paths = expand_inputs(args.inputs, recursive=not args.no_recursive)

    resolver = SymbolResolver()
    for mapping_path in args.mapping:
        resolver.load_manual_csv(mapping_path.expanduser())
    if not args.no_network:
        resolver.load_official()

    rows: list[dict[str, str]] = []
    unresolved: list[str] = []
    pdf_count = 0
    csv_count = 0

    for path in input_paths:
        suffix = path.suffix.lower()
        if suffix == ".pdf":
            pdf_count += 1
            for trade in parse_cathay_pdf(path):
                try:
                    rows.append(
                        synx_row_from_trade(
                            trade,
                            resolver,
                            funding_account=args.funding_account,
                        )
                    )
                except ConversionError as exc:
                    if args.skip_unresolved:
                        unresolved.append(f"{trade.name} ({trade.source})")
                        continue
                    raise exc
        elif suffix == ".csv":
            csv_count += 1
            rows.extend(read_existing_synx_csv(path))

    deduped_rows, duplicate_count = dedupe_rows(rows)
    output_rows = sorted(deduped_rows, key=sort_key)
    write_synx_csv(args.output.expanduser(), output_rows, bom=args.bom)

    print(
        f"wrote {len(output_rows)} rows to {args.output.expanduser()} "
        f"from {pdf_count} PDF(s), {csv_count} CSV(s); "
        f"removed {duplicate_count} duplicate row(s)",
        file=sys.stderr,
    )

    if unresolved:
        warn("skipped unresolved names:")
        for item in sorted(set(unresolved)):
            warn(f"  {item}")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except ConversionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
