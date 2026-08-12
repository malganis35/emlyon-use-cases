import csv
from pathlib import Path
import openpyxl


def convert_xlsx_to_csv(xlsx_path: Path, csv_path: Path, delimiter: str = ";") -> None:
    """Converts the active sheet of an .xlsx workbook to a CSV file."""
    wb = openpyxl.load_workbook(xlsx_path, data_only=True)
    sheet = wb.active
    if sheet is None:
        raise ValueError(f"Aucune feuille active trouvée dans {xlsx_path}")

    csv_path.parent.mkdir(parents=True, exist_ok=True)
    with open(csv_path, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f, delimiter=delimiter)
        for row in sheet.iter_rows(values_only=True):
            # Ignorer les lignes totalement vides
            if not any(cell is not None for cell in row):
                continue
            writer.writerow([cell if cell is not None else "" for cell in row])


def normalize_and_copy_csv(src_csv: Path, dst_csv: Path) -> None:
    """Copie un fichier CSV en garantissant l'encodage UTF-8 sans BOM et des fins de ligne LF."""
    dst_csv.parent.mkdir(parents=True, exist_ok=True)
    content = src_csv.read_bytes()
    # Retirer le BOM UTF-8 si présent
    if content.startswith(b"\xef\xbb\xbf"):
        content = content[3:]
    # Remplacer CRLF par LF
    text = content.decode("utf-8", errors="replace").replace("\r\n", "\n").replace("\r", "\n")
    dst_csv.write_text(text, encoding="utf-8")


def prepare_datasets(src_dir: Path, dst_dir: Path) -> list[Path]:
    """
    Parcourt le dossier des cas d'usage (src_dir) et prépare les 5 fichiers cibles
    dans le dossier de destination (dst_dir).
    """
    src_dir = Path(src_dir).resolve()
    dst_dir = Path(dst_dir).resolve()
    dst_dir.mkdir(parents=True, exist_ok=True)

    mappings = [
        # Use Case GDP
        (
            src_dir / "gdp" / "Mapping Table.xlsx",
            dst_dir / "continent_mapping.csv",
            "xlsx",
        ),
        (
            src_dir / "gdp" / "life-expectancy-vs-gdp-per-capita - cleaned.csv",
            dst_dir / "life-expectancy-vs-gdp-per-capita_-_cleaned.csv",
            "csv",
        ),
        # Use Case Superstore
        (
            src_dir / "superstore" / "Nomenclature.xlsx",
            dst_dir / "nomenclature.csv",
            "xlsx",
        ),
        (
            src_dir / "superstore" / "Sample - EU Superstore_Migrated Data - Part 1.csv",
            dst_dir / "Sample_-_EU_Superstore_Migrated_Data_-_Part_1.csv",
            "csv",
        ),
        (
            src_dir / "superstore" / "Sample - EU Superstore_Migrated Data - Part 2.csv",
            dst_dir / "Sample_-_EU_Superstore_Migrated_Data_-_Part_2.csv",
            "csv",
        ),
    ]

    generated_files: list[Path] = []
    for src_path, dst_path, file_type in mappings:
        if not src_path.exists():
            raise FileNotFoundError(f"Fichier source introuvable : {src_path}")

        if file_type == "xlsx":
            print(f"-> Conversion XLSX -> CSV : {src_path.name} => {dst_path.name}")
            convert_xlsx_to_csv(src_path, dst_path, delimiter=";")
        elif file_type == "csv":
            print(f"-> Normalisation CSV     : {src_path.name} => {dst_path.name}")
            normalize_and_copy_csv(src_path, dst_path)

        generated_files.append(dst_path)

    return generated_files
