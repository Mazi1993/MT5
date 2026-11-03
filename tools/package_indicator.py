"""Build a complete single-file MT5 indicator from the modular source files.

Usage: python3 tools/package_indicator.py /workspace
This packages source only; it does not run the MetaEditor compiler.
"""

import argparse
from pathlib import Path
import re
from zipfile import ZIP_DEFLATED, ZipFile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path, help="Directory for the MQ5 and ZIP files")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    main_source = (root / "Indicators/SessionBoxes.mq5").read_text(encoding="utf-8")
    helper = (root / "Indicators/NewYorkTime.mqh").read_text(encoding="utf-8")
    include = '#include "NewYorkTime.mqh"'
    if main_source.count(include) != 1:
        raise ValueError("Expected exactly one time-helper include")
    version = re.search(r'^#property version\s+"([0-9.]+)"', main_source, re.MULTILINE)
    if not version:
        raise ValueError("Missing indicator version")
    version = version.group(1)
    source = main_source.replace(include, helper.rstrip())
    source += f"\n// End of SessionBoxes v{version} - complete indicator source.\n"
    if "#include" in source or "int OnCalculate(" not in source:
        raise ValueError("Standalone source must include its helper and OnCalculate")

    instructions = (
        f"SessionBoxes v{version} - standalone MT5 indicator\n\n"
        "1. In MT5 choose File > Open Data Folder.\n"
        "2. Copy the complete SessionBoxes.mq5 from this ZIP to MQL5/Indicators.\n"
        "   Replace the entire old file; do not append or copy only part of it.\n"
        "3. Open SessionBoxes.mq5 in MetaEditor and press F7.\n\n"
        "This standalone source does not need NewYorkTime.mqh.\n"
        "Legend times use Tehran UTC+3:30. Broker chart time defaults to UTC+2;\n"
        "change BrokerUTCOffsetMinutes if the broker clock differs.\n"
        "Native MetaEditor compilation has not been verified in this workspace.\n"
    )
    args.output.mkdir(parents=True, exist_ok=True)
    mq5 = args.output / f"SessionBoxes-v{version}.mq5"
    text_source = args.output / f"SessionBoxes-v{version}.txt"
    archive = args.output / f"MT5-SessionBoxes-v{version}.zip"
    mq5.write_text(source, encoding="utf-8")
    text_source.write_text(source, encoding="utf-8")
    with ZipFile(archive, "w", compression=ZIP_DEFLATED) as bundle:
        bundle.writestr("SessionBoxes.mq5", source.encode("utf-8"))
        bundle.writestr("INSTALL.txt", instructions.encode("utf-8"))
    with ZipFile(archive) as bundle:
        if bundle.testzip() is not None or bundle.read("SessionBoxes.mq5") != mq5.read_bytes():
            raise ValueError("Packaged indicator failed its integrity check")
    print(f"Standalone indicator: {mq5}")
    print(f"Plain-text source: {text_source}")
    print(f"Verified ZIP package: {archive}")


if __name__ == "__main__":
    main()
