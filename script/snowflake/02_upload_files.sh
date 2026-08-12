#!/usr/bin/env bash
# =============================================================================
# 02_upload_files.sh (Snowflake)
# Object : Uploads the 9 source files into Snowflake internal stages
# Prerequisites : SnowSQL (snowsql CLI) installed and configured
# Duration : ~5 seconds
# =============================================================================
set -euo pipefail

# --- Verify SnowSQL availability ----------------------------------------------
command -v snowsql >/dev/null 2>&1 || {
  echo "ERROR: Snowflake CLI 'snowsql' is not installed or not available in PATH."
  echo "Please install it: https://docs.snowflake.com/en/user-guide/snowsql-install-config"
  exit 1
}

# --- Parameters ---------------------------------------------------------------
SRC_DIR="${1:-./data}"
CONNECTION="${SNOWSQL_CONN:-emlyon}"

python3 -c "
import os, sys, subprocess, tomllib

src_dir = os.path.abspath('$SRC_DIR')
conn = '$CONNECTION'
p = os.path.expanduser('~/.snowflake/connections.toml')

cfg = {}
if os.path.exists(p):
    try:
        data = tomllib.load(open(p, 'rb'))
        if conn in data:
            cfg = data[conn]
    except Exception:
        pass

env = os.environ.copy()
if cfg.get('password'):
    env['SNOWSQL_PWD'] = cfg['password']

uploads = [
    ('life_expectancy.csv', 'GDP'),
    ('continent_mapping.csv', 'GDP'),
    ('superstore_part1.csv', 'SUPERSTORE'),
    ('superstore_part2.csv', 'SUPERSTORE'),
    ('nomenclature.csv', 'SUPERSTORE'),
    ('allsales_part1.csv', 'ALLSALES'),
    ('allsales_part2.csv', 'ALLSALES'),
    ('allsales_team.csv', 'ALLSALES'),
    ('allsales_store.csv', 'ALLSALES'),
]

print('=== Snowflake File Upload Process ===')
print(f'Source directory : {src_dir}')
print(f'Connection       : {conn}')
print(f'Database         : EMLYON_USE_CASES')
print()

lines = ['USE DATABASE EMLYON_USE_CASES;']
for filename, schema in uploads:
    filepath = os.path.join(src_dir, filename)
    if not os.path.exists(filepath):
        print(f'ERROR: Missing file {filepath}', file=sys.stderr)
        sys.exit(1)
    lines.append(f'USE SCHEMA {schema};')
    lines.append(f'PUT file://{filepath} @RAW_STAGE OVERWRITE=TRUE AUTO_COMPRESS=FALSE;')

batch_sql = os.path.join(src_dir, '_upload_batch.sql')
with open(batch_sql, 'w') as f:
    f.write('\n'.join(lines) + '\n')

cmd = ['snowsql']
if cfg.get('account') and cfg.get('user'):
    cmd.extend(['-a', cfg['account'], '-u', cfg['user']])
    if cfg.get('warehouse'):
        cmd.extend(['-w', cfg['warehouse']])
    if cfg.get('role'):
        cmd.extend(['-r', cfg['role']])
else:
    cmd.extend(['-c', conn])

cmd.extend(['-f', batch_sql, '-o', 'exit_on_error=true', '-o', 'quiet=true'])

res = subprocess.run(cmd, env=env, capture_output=True, text=True)

if os.path.exists(batch_sql):
    os.remove(batch_sql)

if res.returncode != 0:
    print(f'ERROR: {res.stderr.strip() or res.stdout.strip()}', file=sys.stderr)
    sys.exit(res.returncode)

print('=== Success: 9 files transferred to Snowflake internal stages ===')
print('NEXT STEP: Run 03_load_tables.sql')
"
