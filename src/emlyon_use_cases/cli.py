import argparse
from pathlib import Path
import sys
from emlyon_use_cases.converter import prepare_datasets


def main() -> None:
    parser = argparse.ArgumentParser(
        prog="emlyon-use-cases",
        description="CLI d'automatisation et de préparation des jeux de données emlyon (BI & DataViz)",
    )
    subparsers = parser.add_subparsers(dest="command", help="Sous-commandes disponibles")

    # Command: prepare
    prepare_parser = subparsers.add_parser(
        "prepare",
        help="Convertit les fichiers Excel (.xlsx) et prépare le dossier ./data pour l'upload Databricks",
    )
    prepare_parser.add_argument(
        "--src",
        type=Path,
        default=Path("./use_cases"),
        help="Dossier source des use_cases (défaut: ./use_cases)",
    )
    prepare_parser.add_argument(
        "--dst",
        type=Path,
        default=Path("./data"),
        help="Dossier destination généré (défaut: ./data)",
    )

    args = parser.parse_args()

    # Par défaut si aucune sous-commande n'est fournie, exécuter 'prepare'
    if args.command is None or args.command == "prepare":
        src_dir = getattr(args, "src", Path("./use_cases"))
        dst_dir = getattr(args, "dst", Path("./data"))
        print(f"=== Préparation des jeux de données emlyon ===")
        print(f"Source      : {src_dir}")
        print(f"Destination : {dst_dir}")
        print()
        try:
            generated = prepare_datasets(src_dir, dst_dir)
            print()
            print(f"=== Succès : {len(generated)} fichiers générés dans {dst_dir}/ ===")
            print("Vous pouvez maintenant exécuter : bash script/databricks/02_upload_files.sh")
        except Exception as e:
            print(f"ERREUR : {e}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    main()
