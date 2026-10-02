# Objectifs des datasets

- Une table de faits principale découpée en 2 parties (Part 1 et Part 2) : les étudiants doivent concaténer les 2 tables (Append dans Power Query).
- Un jeu de données en étoile : 1 table de faits et 3 ou 4 tables de dimensions : les étudiants doivent construire le modèle en étoile.
- Objectif général : couvrir toute la chaîne Power BI (connexion, Power Query, modélisation, DAX, visualisation, service) avec des données proches de la réalité.

Niveaux de difficulté : **1** = débutant, **2** = intermédiaire, **3** = avancé.

# Catalogue des disqualités

Les colonnes « Table / colonne cible » sont à compléter au moment de l'injection dans les données.

## 1. Power Query : nettoyage et transformation

| Disqualité | Symptôme | Fonction Power BI visée | Niveau | Table / colonne cible |
|---|---|---|---|---|
| Lignes parasites au début (`zz_test` dans une colonne, vide dans les autres) | Les en-têtes ne sont pas sur la première ligne | Supprimer les lignes du haut, Utiliser la première ligne comme en-têtes | 1 | |
| 2 colonnes entièrement nulles | Colonnes inutiles | Supprimer des colonnes | 1 | |
| Préfixe sur toutes les valeurs d'une colonne (ex. `Sales Channel: Online`) | Valeurs polluées | Remplacer les valeurs, Extraire le texte après le délimiteur | 1 | |
| Préfixe numérique + séparateur (`1-Office Supplies`, `11-Technology`) | Code et libellé dans la même colonne | Fractionner la colonne par délimiteur | 1 | |
| Séparateurs décimaux `.` et `,` **mélangés dans la même colonne** | Types texte, erreurs de conversion | Changer le type avec paramètres régionaux (US / FR) | 2 | |
| Casse et espaces parasites (`Paris`, `paris `, `PARIS`) | Une même valeur apparaît en plusieurs libellés | Découper, Nettoyer, Mettre en majuscules chaque mot | 1 | |
| Valeurs manquantes déguisées (`N/A`, `-`, chaîne vide, `0` à la place de null) | Fausse les moyennes et les comptages | Remplacer les valeurs, Remplir vers le bas | 2 | |
| Doublons exacts et quasi-exacts | Chiffre d'affaires gonflé | Supprimer les doublons | 2 | |
| Dates en formats mixtes (`03/10/2026`, `2026-10-03`, texte) et dates impossibles | Conversion en erreur ou jour et mois inversés | Changer le type avec paramètres régionaux, gestion des erreurs | 2 | |
| Lignes de total ou sous-total, en-têtes répétés au milieu des données | Double comptage | Filtrer les lignes | 2 | |
| Mois en colonnes (Jan, Fév, Mar…) | Table large impossible à analyser par période | Dépivoter les colonnes | 2 | |
| Cellule multi-valeurs (`A;B;C`) | Une ligne regroupe plusieurs éléments | Fractionner en lignes | 3 | |
| Montants négatifs (retours), valeurs aberrantes | Indicateurs faussés | Filtres, colonnes conditionnelles | 2 | |
| Devises ou unités mixtes | Sommes incohérentes | Colonne conditionnelle, fusion avec une table de taux | 3 | |
| Encodage cassé (accents illisibles) | Caractères `Ã©` au lieu de `é` | Choix de l'encodage à l'import | 2 | |
| Colonne renommée ou ordre différent entre Part 1 et Part 2 (déjà présent dans Superstore) | Append incorrect, colonnes dupliquées | Append par nom, renommer les colonnes | 2 | |

## 2. Modélisation

| Disqualité | Symptôme | Fonction Power BI visée | Niveau | Table / colonne cible |
|---|---|---|---|---|
| Faits répartis en 2 parties | Deux tables à regrouper | Append, puis modèle en étoile | 1 | |
| Clés orphelines (faits sans correspondance dans la dimension) | Ligne `(Blank)` dans les visuels | Relations, vérification de l'intégrité | 2 | |
| Type de clé différent (`00123` en texte, `123` en entier) | Relation impossible ou vide | Changer le type, compléter avec des zéros | 2 | |
| Clé dupliquée dans une dimension | Relation plusieurs-à-plusieurs | Supprimer les doublons, cardinalité | 3 | |
| Pas de table calendrier | Time intelligence indisponible | Table de dates (`CALENDAR`), marquer comme table de dates | 2 | |
| Dimension qui évolue (client qui change de segment) | Historique incohérent | Dimension à évolution lente (SCD) | 3 | |

## 3. DAX et visualisation

| Disqualité | Symptôme | Fonction Power BI visée | Niveau | Table / colonne cible |
|---|---|---|---|---|
| Budget ou objectifs à une granularité différente (mois, région) | Écart au budget impossible à calculer directement | Mesures, relations par table commune | 3 | |
| Ratios et moyennes pondérées | Moyenne de moyennes fausse | Mesures `DIVIDE`, `SUMX` | 2 | |
| Comparaisons YTD, N-1 | Nécessitent une table calendrier propre | `TOTALYTD`, `SAMEPERIODLASTYEAR` | 3 | |

## 4. Service Power BI

| Disqualité | Symptôme | Fonction Power BI visée | Niveau | Table / colonne cible |
|---|---|---|---|---|
| Dimension Région ou Manager | Chacun ne doit voir que son périmètre | Sécurité par ligne (RLS) | 3 | |
| Volume suffisant et fichiers qui évoluent | Actualisation lente, schéma qui change | Actualisation incrémentale, passerelle | 3 | |

# Progression pédagogique

Ne pas mettre tous les défauts partout : un cas d'usage par niveau.

1. **Nettoyage simple** (niveau 1) : lignes parasites, colonnes nulles, préfixes, casse et espaces, Append Part 1 / Part 2.
2. **Qualité et modélisation** (niveau 2) : décimales mixtes, dates, doublons, null déguisés, clés orphelines, table calendrier.
3. **DAX et service** (niveau 3) : budget, YTD / N-1, SCD, many-to-many, RLS, actualisation.

# Cohérence avec le pipeline

Chaque défaut ajouté doit être injecté dans les CSV, donc dans `converter.py`, puis répercuté à l'identique sur les deux plateformes (règle 5 de `CLAUDE.md`) :

- les deux scripts `03_load_tables.sql` (tables en STRING, sans transformation ni nettoyage : règles 1 et 4) ;
- les scripts `02_upload_files.sh` si un fichier est ajouté ;
- le tableau « Pedagogical Data Traps » du README, qui sert de corrigé instructeur.
