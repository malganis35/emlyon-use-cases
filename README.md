# Setup Databricks Free Edition — cours BI & DataViz

Deux use cases, cinq fichiers, deux schémas. Compter **20 minutes** au premier passage, **5 minutes** ensuite.

## Ordre d'exécution

| # | Fichier | Où | Durée |
|---|---------|-----|-------|
| 1 | `01_setup_unity_catalog.sql` | SQL Editor Databricks | 30 s |
| 2 | `02_upload_files.sh` | terminal local (CLI authentifiée) | 1 min |
| 3 | `03_load_tables.sql` | SQL Editor Databricks | 2 min |
| 4 | `04_grants_bi.sql` | SQL Editor Databricks | 15 s |
| 5 | UI : warehouse `CAN USE` + service principal | interface | 5 min |

Le dossier source attendu par l'étape 2 contient :

```
data/
├── life-expectancy-vs-gdp-per-capita_-_cleaned.csv
├── continent_mapping.csv                              # converti depuis Mapping_Table.xlsx
├── Sample_-_EU_Superstore_Migrated_Data_-_Part_1.csv
├── Sample_-_EU_Superstore_Migrated_Data_-_Part_2.csv
└── nomenclature.csv                                   # converti depuis Nomenclature.xlsx
```

Lancer avec `bash 02_upload_files.sh ./data`.

## Modèle produit

```
emlyon_use_cases
├── gdp
│   ├── raw_files/                    (volume : 2 CSV)
│   ├── raw_life_expectancy           12 744 lignes, tout en STRING
│   ├── raw_continent_mapping              3 lignes
│   ├── fact_life_expectancy          typée
│   └── dim_continent                 typée, PK sur continent
└── superstore
    ├── raw_files/                    (volume : 3 CSV)
    ├── raw_orders                    10 000 lignes (union part1 + part2)
    ├── raw_nomenclature                  17 lignes
    ├── fact_orders                   typée, dates converties
    └── dim_category                  typée, PK sur sub_category
```

Les couches `raw_*` conservent les noms de colonnes d'origine (`Country/Region`, `Remove Inc ?`)
grâce à `delta.columnMapping.mode = 'name'`. Les couches typées **ne nettoient aucune valeur** :
préfixes `1-`, `10-`, `100-` et continent `Mars` sont conservés, c'est le travail des étudiants.

## Pièges pédagogiques intégrés

| Use case | Piège | Exercice visé |
|----------|-------|---------------|
| GDP | référentiel continent limité à Europe / Asia / Mars | jointure externe, valeurs orphelines |
| GDP | décimales à virgule sur `Life exp` | typage à l'import |
| Superstore | Part 1 et Part 2 n'ont pas le même ordre de colonnes | union par nom, pas par position |
| Superstore | `Remove Inc ?` et `Remove Inc 2?` remplies de `?` | suppression de colonnes parasites |
| Superstore | `Category` préfixée `1-` / `10-` / `100-` | split de colonne, tri personnalisé |

## Fiche de connexion à donner aux étudiants

```
Server hostname : <workspace>.cloud.databricks.com
HTTP path       : /sql/1.0/warehouses/<id>
Catalogue       : emlyon_use_cases
Schéma          : gdp   ou   superstore
Authentification: Power BI -> "Databricks Client Credentials" (client ID + secret)
                  Tableau  -> methode "Service Principal" (meme client ID + secret)
Mode conseillé  : Import (Power BI) / Extract (Tableau)
```

**Ne pas utiliser DirectQuery ni Live Connection.** La Free Edition n'autorise qu'un seul
SQL warehouse en 2X-Small : trente étudiants en requêtage simultané le saturent. En Import /
Extract, chacun ne sollicite le warehouse qu'une fois.

## Limites Free Edition à connaître

1. Un seul workspace, un seul metastore, un seul SQL warehouse (2X-Small).
2. Un utilisateur ajouté au workspace **ne peut plus être supprimé** — d'où le choix d'un service principal plutôt qu'un compte `db_invite`.
3. Pas de mot de passe : authentification par OTP e-mail, Google ou Microsoft uniquement.
4. Dépassement de quota = compute coupé jusqu'au lendemain. À tester la veille du cours, pas le matin même.
5. Usage non commercial. À valider côté emlyon avant de bâtir un cours dessus.
