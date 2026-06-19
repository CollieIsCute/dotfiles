from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = (
    Path(__file__).resolve().parents[1]
    / "scripts"
    / "cathay_pdf_to_synx_csv.py"
)

spec = importlib.util.spec_from_file_location("cathay_pdf_to_synx_csv", SCRIPT_PATH)
assert spec is not None and spec.loader is not None
cathay = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = cathay
spec.loader.exec_module(cathay)


class CathayPdfToSynxCsvTest(unittest.TestCase):
    def test_amount_uses_cathay_net_cash_movement(self) -> None:
        text = (
            "114/10/16 集買 元大台灣50 2,000 62.5 "
            "49 125,000 125,049(付) a-d099-00\n"
        )

        with patch.object(cathay, "extract_pdf_text", return_value=text):
            trades = cathay.parse_cathay_pdf(Path("statement.pdf"))

        self.assertEqual(len(trades), 1)
        self.assertEqual(trades[0].amount, 125049)
        self.assertEqual(trades[0].tax, 49)

        resolver = cathay.SymbolResolver()
        resolver.add("manual", "元大台灣50", "0050")
        row = cathay.synx_row_from_trade(
            trades[0], resolver, funding_account="國泰交割戶"
        )

        self.assertEqual(row["Account"], "0050")
        self.assertEqual(row["Amount"], "125049")
        self.assertEqual(row["Tax"], "49")

    def test_sell_amount_stays_positive_net_cash_movement(self) -> None:
        text = (
            "115/03/04 集賣 台積電 1 1000 "
            "20 3 1,000 977(收) A-1234-00\n"
        )

        with patch.object(cathay, "extract_pdf_text", return_value=text):
            trades = cathay.parse_cathay_pdf(Path("statement.pdf"))

        self.assertEqual(len(trades), 1)
        self.assertEqual(trades[0].shares, -1)
        self.assertEqual(trades[0].amount, 977)
        self.assertEqual(trades[0].tax, 23)

        resolver = cathay.SymbolResolver()
        resolver.add("manual", "台積電", "2330")
        row = cathay.synx_row_from_trade(
            trades[0], resolver, funding_account="國泰交割戶"
        )

        self.assertEqual(row["Account"], "2330")
        self.assertEqual(row["Shares"], "-1")
        self.assertEqual(row["Amount"], "977")
        self.assertEqual(row["Tax"], "23")


if __name__ == "__main__":
    unittest.main()
