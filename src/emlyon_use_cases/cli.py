import argparse
import json
import sys
from pathlib import Path
from zipfile import BadZipFile

from openpyxl.utils.exceptions import InvalidFileException

from emlyon_use_cases.converter import prepare_datasets
from emlyon_use_cases.degrade import degrade_use_case, profile_source
from emlyon_use_cases.manifest import load_manifest
from emlyon_use_cases.sqlgen import generate_sql


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="emlyon-use-cases",
        description="CLI tool for dataset preparation and pipeline automation (emlyon BI & DataViz course)",
    )
    subparsers = parser.add_subparsers(dest="command", help="Available subcommands")

    # Command: prepare
    prepare_parser = subparsers.add_parser(
        "prepare",
        help="Converts Excel files (.xlsx) and prepares the ./data directory for cloud upload",
    )
    prepare_parser.add_argument(
        "--src",
        type=Path,
        default=Path("./use_cases"),
        help="Source directory for raw use cases (default: ./use_cases)",
    )
    prepare_parser.add_argument(
        "--dst",
        type=Path,
        default=Path("./data"),
        help="Destination directory for output CSVs (default: ./data)",
    )

    # Command: degrade
    degrade_parser = subparsers.add_parser(
        "degrade",
        help="Builds the degraded CSVs of a use case from its manifest.yaml",
    )
    degrade_parser.add_argument("--manifest", type=Path, required=True)
    degrade_parser.add_argument("--dst", type=Path, default=Path("./data"))

    # Command: generate-sql
    sql_parser = subparsers.add_parser(
        "generate-sql",
        help="Generates the Databricks and Snowflake scripts of a use case from its generated CSVs",
    )
    sql_parser.add_argument("--manifest", type=Path, required=True)
    sql_parser.add_argument("--data", type=Path, default=Path("./data"))
    sql_parser.add_argument("--dst", type=Path, default=Path("./script"))

    # Command: profile
    profile_parser = subparsers.add_parser(
        "profile",
        help="Prints a JSON description of the columns of a raw .csv/.xlsx source",
    )
    profile_parser.add_argument("--src", type=Path, required=True)
    profile_parser.add_argument(
        "--sheet", default=None, help="Worksheet name (.xlsx only)"
    )

    args = parser.parse_args()

    if args.command in ("degrade", "generate-sql", "profile"):
        try:
            if args.command == "generate-sql":
                use_case = load_manifest(args.manifest)
                for path in generate_sql(use_case, args.data, args.dst):
                    print(f"-> {path}")
            elif args.command == "degrade":
                use_case = load_manifest(args.manifest)
                result = degrade_use_case(use_case, args.dst)
                print(f"=== Success: {len(result)} files generated in {args.dst}/ ===")
            else:
                print(
                    json.dumps(
                        profile_source(args.src, args.sheet),
                        indent=2,
                        ensure_ascii=False,
                    )
                )
        except (OSError, ValueError, BadZipFile, InvalidFileException) as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)
        return

    # Default to 'prepare' subcommand if none is provided
    if args.command is None or args.command == "prepare":
        src_dir = getattr(args, "src", Path("./use_cases"))
        dst_dir = getattr(args, "dst", Path("./data"))
        print("=== emlyon Dataset Preparation ===")
        print(f"Source      : {src_dir}")
        print(f"Destination : {dst_dir}")
        print()
        try:
            generated = prepare_datasets(src_dir, dst_dir)
            print()
            print(f"=== Success: {len(generated)} files generated in {dst_dir}/ ===")
            print(
                "Next step: run 'bash script/databricks/02_upload_files.sh' or 'bash script/snowflake/02_upload_files.sh'"
            )
        except (OSError, ValueError, BadZipFile, InvalidFileException) as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
