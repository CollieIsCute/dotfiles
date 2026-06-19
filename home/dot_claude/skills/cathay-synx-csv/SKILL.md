---
name: cathay-synx-csv
description: Converts Cathay Securities transaction-detail PDFs into Synx investment CSV, including folder input and overlapping-period de-duplication. Use when handling 國泰證券交易明細表 PDFs, Synx CSV, ETF/stocks, duplicate Cathay PDF ranges, or 國泰交割戶 imports.
---

# Cathay Synx CSV

Use this skill when the user has one or more Cathay Securities `客戶交易明細表` PDFs and wants a Synx investment CSV. This skill lives under `~/.claude/skills` so both Claude and opencode can use it.

## What It Does

- Reads Cathay Securities transaction-detail PDFs.
- Accepts PDF files, existing Synx CSV files, and folders containing PDFs/CSVs.
- Recursively scans folders by default.
- Resolves Taiwan stock/ETF names to stock codes using official TWSE/TPEx OpenAPI data.
- Converts ROC dates to ISO dates.
- Writes Synx investment CSV:

```csv
Account,Funding Account,Date,Shares,Price,Amount,Tax,Note
```

- Uses stock code as `Account`, for example `0050`, `00646`, `2330`.
- Uses `國泰交割戶` as `Funding Account` by default.
- Treats `Amount` as the actual positive `Funding Account` cash movement,
  using Cathay's 收/付 net amount.
- De-duplicates overlapping PDF ranges and existing Synx CSV rows.

## Default Command

```bash
python3 ~/.claude/skills/cathay-synx-csv/scripts/cathay_pdf_to_synx_csv.py \
  --output ~/Downloads/cathay-synx.csv \
  ~/Downloads/交易明細表-*.pdf
```

## Folder Input

Use this when a folder contains multiple overlapping Cathay PDFs.

```bash
python3 ~/.claude/skills/cathay-synx-csv/scripts/cathay_pdf_to_synx_csv.py \
  --output ~/Downloads/cathay-synx.csv \
  ~/Downloads/cathay-pdfs
```

## Merge Existing CSV

Use this when the user already has an older generated Synx CSV and wants to merge new PDFs into it.

```bash
python3 ~/.claude/skills/cathay-synx-csv/scripts/cathay_pdf_to_synx_csv.py \
  --output ~/Downloads/cathay-synx-merged.csv \
  ~/Downloads/old-cathay-synx.csv \
  ~/Downloads/cathay-pdfs
```

## Show Help

```bash
python3 ~/.claude/skills/cathay-synx-csv/scripts/cathay_pdf_to_synx_csv.py -h
```

## PDF Text Extraction

- macOS: uses the system `swift` command with PDFKit, no extra Python package needed.
- Linux: install Poppler so the `pdftotext` command is available.
- Windows is not targeted by this skill.

## Synx Setup Required

Before importing:

- Create one Synx investment account per stock code, such as `0050`, `00646`, `2330`.
- Create a non-investment Synx funding account named `國泰交割戶`.
- Ensure account start dates are earlier than the earliest CSV date.
- Ensure each investment account has the matching holding/position set up.
- Synx may display market/security names in English; CSV matching still uses
  the exact account names such as `0050`.

## Conversion Rules

| Cathay PDF | Synx CSV | Rule |
| --- | --- | --- |
| 股票名稱 | `Account` | Resolve to stock code via TWSE/TPEx official data |
| fixed | `Funding Account` | Defaults to `國泰交割戶` |
| 交易日期 | `Date` | ROC date to `yyyy-MM-dd` |
| CD + 股數 | `Shares` | Buy positive, sell negative |
| 單價 | `Price` | Unit price |
| 收付淨額 | `Amount` | Actual positive `Funding Account` cash movement from the Cathay 收/付 column |
| 手續費 + 交易稅 + other visible fees | `Tax` | Sum all numeric fee columns before 價金; kept for Synx fee/tax tracking |
| 委託書號 | `Note` | Preserved for audit and de-dupe |

## De-Dupe Rule

Rows are considered the same transaction when these fields match:

```text
Date + Account + Shares + Price + Amount + Tax + 委託書號
```

If no order number is available, the script falls back to:

```text
Date + Account + Shares + Price + Amount + Tax
```

This avoids incorrectly merging separate same-day trades that have distinct Cathay order numbers.

## Manual Mapping

If a name is missing from official open data, create a CSV:

```csv
name,code
舊股票名稱,1234
```

Then run:

```bash
python3 ~/.claude/skills/cathay-synx-csv/scripts/cathay_pdf_to_synx_csv.py \
  --mapping ~/Downloads/cathay-name-map.csv \
  --output ~/Downloads/cathay-synx.csv \
  ~/Downloads/cathay-pdfs
```

## Important Checks

- If unresolved symbols appear, do not import until they are mapped.
- Spot-check total shares by stock against Cathay or 集保.
- Spot-check `國泰交割戶` cash movement against Cathay settlement amounts.
- Avoid spreadsheet tools that may strip leading zeros from account codes like `0050`.
- Import one small date range into Synx first before importing years of data.
