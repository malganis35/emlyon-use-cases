import argparse
from pathlib import Path
import sys
from emlyon_use_cases.converter import prepare_datasets


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

    args = parser.parse_args()

    # Default to 'prepare' subcommand if none is provided
    if args.command is None or args.command == "prepare":
        src_dir = getattr(args, "src", Path("./use_cases"))
        dst_dir = getattr(args, "dst", Path("./data"))
        print(f"=== emlyon Dataset Preparation ===")
        print(f"Source      : {src_dir}")
        print(f"Destination : {dst_dir}")
        print()
        try:
            generated = prepare_datasets(src_dir, dst_dir)
            print()
            print(f"=== Success: {len(generated)} files generated in {dst_dir}/ ===")
            print("Next step: run 'bash script/databricks/02_upload_files.sh' or 'bash script/snowflake/02_upload_files.sh'")
        except Exception as e:
            print(f"ERROR: {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
