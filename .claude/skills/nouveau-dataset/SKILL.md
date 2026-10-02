---
name: nouveau-dataset
description: Ajoute un nouveau jeu de données (use case) au pipeline. Propose des disqualités pédagogiques issues d'un fichier de référence de docs/, génère le manifeste, les CSV dégradés et les scripts Snowflake et Databricks. À utiliser quand un professeur fournit un dataset à déployer pour ses étudiants.
---

# Nouveau dataset avec disqualités

Tu transformes un dataset fourni par un professeur en un use case complet : CSV dégradés + scripts `01_`, `02_`, `03_`, `04_` pour Snowflake et Databricks. Tu n'écris jamais de code de transformation toi-même : tout passe par le manifeste YAML et la CLI `uv run emlyon-use-cases`.

## Règles

- Ne modifie jamais les use cases existants (`gdp`, `superstore`, `allsales`) ni les scripts `script/*/0x_*` écrits à la main. Le nouveau use case a son propre schéma et ses scripts sont générés dans `script/<plateforme>/generated/<use_case>/`.
- Ne nettoie jamais les anomalies : les disqualités sont des exercices pour les étudiants. Pas de cast, d'union, de renommage ni de contrainte dans le SQL (tout reste STRING).
- Ne donne jamais de droits d'écriture aux comptes étudiants (`db-invite-bi`, `BI_STUDENT_ROLE`, `STUDENT_BI_USER`). Les scripts `04_` générés sont en lecture seule : ne les modifie pas.
- N'applique que les 5 types de disqualités supportés (voir ci-dessous). Si le fichier de référence en demande une autre, dis-le au professeur au lieu d'improviser.
- Pose les questions avec `AskUserQuestion` (4 questions maximum, 2 à 4 options chacune). Ne demande que ce que le dataset et le fichier de référence ne disent pas déjà.
- Ne lance jamais un `02_upload_files.sh`, `snowsql` ou `databricks` sans confirmation explicite du professeur : l'upload est une action sortante.

## Disqualités supportées

| type | effet | paramètres |
|---|---|---|
| `junk_rows` | lignes parasites après l'en-tête (une colonne = marqueur, le reste vide) | `column`, `count` (3), `marker` (`zz_test`) |
| `null_columns` | colonnes vides, nommées explicitement | `names` (liste), `position` (`end` ou `start`) |
| `value_prefix` | préfixe constant sur toutes les valeurs d'une colonne | `column`, `prefix` |
| `code_prefix` | préfixe `1-`, `2-`, `11-` à séparer ensuite | `column`, `start` (1), `separator` (`-`) |
| `mixed_decimal` | séparateurs décimaux `.` et `,` mélangés | `column`, `ratio` (0.5) |

Contraintes vérifiées par la CLI : `value_prefix` et `code_prefix` doivent précéder `junk_rows` s'ils visent la même colonne ; `code_prefix` calcule ses codes sur la source complète, donc une même valeur reçoit le même code dans Part 1 et Part 2 ; `null_columns.names` est une liste de noms uniques ; `mixed_decimal.ratio` est dans ]0, 1]. Les noms de use case `gdp`, `superstore`, `allsales` et les mots réservés Snowflake sont refusés.

## Étapes

1. **Recueillir le dataset** : chemin du fichier (`.csv` ou `.xlsx`, avec la feuille si besoin) et nom du use case (minuscules, chiffres et `_`, ex. `retail`). Si le dataset n'est pas dans le dépôt, copie-le dans `use_cases/<nom>/`.
2. **Profiler** : `uv run emlyon-use-cases profile --src <fichier> [--sheet "<feuille>"]`. Le JSON donne, par colonne, le type (`numeric` ou `text`), la présence de décimales, le nombre de valeurs distinctes et des exemples.
3. **Choisir le fichier de référence** : liste `docs/*.md`. S'il y en a plusieurs, demande lequel utiliser avec `AskUserQuestion` (une option par fichier). Lis-le et dresse la liste des disqualités demandées, en les rattachant aux types supportés.
4. **Choisir les disqualités** : `AskUserQuestion` en multiSelect avec les disqualités trouvées (2 questions si plus de 4). Pour chacune retenue, demande la colonne cible en proposant 2 à 4 colonnes cohérentes avec le profil :
   - `value_prefix` / `code_prefix` : colonnes texte avec peu de valeurs distinctes ;
   - `mixed_decimal` : colonnes numériques avec décimales (`has_decimals`) ;
   - `junk_rows` : une colonne identifiant ou texte ;
   - `null_columns` : propose des noms (ex. `Empty 1`, `Empty 2`) ; ils doivent être explicites.
5. **Choisir la structure** : table unique, ou fait coupé en Part 1 / Part 2 (une table par plage `rows: [début, fin]`, que les étudiants devront concaténer), ou schéma en étoile. Pour l'étoile, la CLI ne sait pas extraire les dimensions : le professeur fournit un fichier (ou une feuille) par dimension, chacun devient une table du manifeste.
6. **Écrire `use_cases/<nom>/manifest.yaml`** (les chemins `source` sont relatifs au dossier du manifeste) :
   ```yaml
   use_case: retail
   seed: 1
   tables:
     - name: sales_part1
       source: sales.csv
       rows: [0, 5000]
       disqualities:
         - {type: junk_rows, column: Order ID, count: 3}
         - {type: null_columns, names: [Empty 1, Empty 2]}
         - {type: value_prefix, column: Channel, prefix: "Sales Channel: "}
         - {type: code_prefix, column: Product}
         - {type: mixed_decimal, column: Price}
     - name: sales_part2
       source: sales.csv
       rows: [5000, 10000]
   ```
   Applique les disqualités sur chaque partie voulue. Elles sont idempotentes et reproductibles (même `seed`, même résultat).
7. **Générer** :
   ```
   uv run emlyon-use-cases degrade --manifest use_cases/<nom>/manifest.yaml --dst ./data
   uv run emlyon-use-cases generate-sql --manifest use_cases/<nom>/manifest.yaml --data ./data --dst ./script
   ```
   Une erreur de colonne inconnue ou de paramètre manquant s'affiche clairement : corrige le manifeste et relance.
8. **Vérifier** avant de conclure : lis les premières lignes de chaque CSV de `./data/<nom>_*.csv` (en-tête, `zz_test`, préfixes, virgules décimales), contrôle que le nombre de lignes de chaque `03_load_tables.sql` généré correspond aux CSV, et que les deux plateformes ont les mêmes tables et colonnes (Snowflake : noms en majuscules snake_case, chargement par position).
9. **Résumer** au professeur : fichiers générés, lignes et colonnes ajoutées, disqualités appliquées par table. Puis propose l'ordre de déploiement et attends sa confirmation avant d'exécuter quoi que ce soit :
   1. `01_` (Databricks SQL Editor / Snowsight) ;
   2. `bash script/<plateforme>/generated/<nom>/02_upload_files.sh ./data` ;
   3. `03_` puis vérifier que `row_count = expected` pour chaque table ;
   4. `04_` en remplaçant `<<CLIENT_ID>>` (Databricks) : droits en lecture seule.
