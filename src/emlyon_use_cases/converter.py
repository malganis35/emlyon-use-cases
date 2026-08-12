import csv
from pathlib import Path
import openpyxl


def convert_xlsx_to_csv(xlsx_path: Path, csv_path: Path, delimiter: str = ";") -> None:
    """Converts the active sheet of an .xlsx workbook to a CSV file."""
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    sheet = wb.active
    if sheet is None:
        raise ValueError(f"No active worksheet found in {xlsx_path}")

    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=delimiter)
        for row in sheet.iter_rows(values_only=True):
            # Skip completely empty rows
            if not any(cell is not None for cell in row):
                continue
            writer.writerow([cell if cell is not None else "" for cell in row])


def normalize_and_copy_csv(src_csv: Path, dst_csv: Path) -> None:
    """Copies a CSV file while ensuring UTF-8 encoding without BOM and LF line endings."""
    dst_csv.parent.mkdir(parents=True, exist_ok=True)
    content = src_csv.read_bytes()
    # Remove UTF-8 BOM if present
    if content.startswith(b"\xef\xbb\xbf"):
        content = content[3:]
    # Convert CRLF to LF
    text = content.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    dst_csv.write_text(text, encoding="utf-8")


def prepare_datasets(src_dir: Path, dst_dir: Path) -> list[Path]:
    """
    Scans the use cases source directory (src_dir) and prepares the 5 target files
    in the destination directory (dst_dir).
    """
    src_dir = Path(src_dir).resolve()
    dst_dir = Path(dst_dir).resolve()
    dst_dir.mkdir(parents=True, exist_ok=True)

    mappings = [
        # GDP Use Case
        (
            src_dir / "gdp" / "Mapping Table.xlsx",
            dst_dir / "continent_mapping.csv",
            "xlsx",
        ),
        (
            src_dir / "gdp" / "life-expectancy-vs-gdp-per-capita - cleaned.csv",
            dst_dir / "life_expectancy.csv",
            "csv",
        ),
        # Superstore Use Case
        (
            src_dir / "superstore" / "Nomenclature.xlsx",
            dst_dir / "nomenclature.csv",
            "xlsx",
        ),
        (
            src_dir / "superstore" / "Sample - EU Superstore_Migrated Data - Part 1.csv",
            dst_dir / "superstore_part1.csv",
            "csv",
        ),
        (
            src_dir / "superstore" / "Sample - EU Superstore_Migrated Data - Part 2.csv",
            dst_dir / "superstore_part2.csv",
            "csv",
        ),
    ]

    generated_files: list[Path] = []
    for src_path, dst_path, file_type in mappings:
        if not src_path.exists():
            raise FileNotFoundError(f"Source file not found: {src_path}")

        if file_type == "xlsx":
            print(f"-> Converting XLSX to CSV: {src_path.name} => {dst_path.name}")
            convert_xlsx_to_csv(src_path, dst_path, delimiter=";")
        elif file_type == "csv":
            print(f"-> Normalizing CSV       : {src_path.name} => {dst_path.name}")
            normalize_and_copy_csv(src_path, dst_path)

        generated_files.append(dst_path)

    return generated_files
