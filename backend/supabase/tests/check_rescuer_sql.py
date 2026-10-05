"""Offline PostgreSQL syntax review; NOT a DB, RLS or concurrency test.

Requires pglast. Optional --parser-path points at an isolated installation.
No database connection, subprocess or network access is performed.
"""
import argparse
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--parser-path', type=Path)
parser.add_argument('--migration', type=Path, help='Migration to parse; defaults to the foundation.')
parser.add_argument('--regression', type=Path, help='SQL regression to parse; defaults to the foundation regression.')
args = parser.parse_args()
if args.parser_path:
    sys.path.insert(0, str(args.parser_path))

from pglast import ast, parse_sql
from pglast.parser import parse_plpgsql_json
from pglast.stream import RawStream

path = args.migration or (Path(__file__).resolve().parents[1] / 'migrations' / '202610020001_rescuer_backend_foundation.sql')
source = path.read_text(encoding='utf-8')
statements = parse_sql(source)
functions = []
procedural = 0
sql_bodies = 0
for raw in statements:
    node = raw.stmt
    if isinstance(node, ast.CreateFunctionStmt):
        name = '.'.join(part.sval for part in node.funcname)
        options = {option.defname: option.arg for option in node.options}
        functions.append(name)
        language = options['language'].sval
        if language == 'plpgsql':
            # The wrapper's JSON decoder has issues with trigger return types;
            # libpg_query still validates the function and returns raw tokens.
            parse_plpgsql_json(RawStream()(node))
            procedural += 1
        elif language == 'sql':
            parse_sql(options['as'][0].sval)
            sql_bodies += 1
        assert "SET search_path TO ''" in RawStream()(node), name
    elif isinstance(node, ast.DoStmt):
        body = next(o.arg.sval for o in node.args if o.defname == 'as')
        parse_plpgsql_json('CREATE FUNCTION offline_do() RETURNS void LANGUAGE plpgsql AS $offline$'
                           + body + '$offline$')

expected = {
    'register_profile', 'update_profile', 'submit_profile', 'reserve_document', 'complete_document',
    'register_vehicle', 'update_vehicle', 'set_capability', 'set_online', 'update_location',
    'list_available_requests', 'get_available_request', 'claim_request', 'get_active_job',
    'update_job_status', 'create_quote', 'list_job_history', 'get_job_history',
}
public = {name.removeprefix('public.rescuer_') for name in functions if name.startswith('public.rescuer_')}
if path.name == '202610020001_rescuer_backend_foundation.sql':
    assert public == expected, (public - expected, expected - public)
assert len(functions) == len(set(functions)), 'RPC overloading requires review'
assert source.rstrip().endswith('commit;'), 'Incomplete migration transaction'
regression = args.regression or (Path(__file__).resolve().parent / 'rescuer_local_regression.sql')
regression_source = '\n'.join(line for line in regression.read_text(encoding='utf-8').splitlines()
                              if not line.startswith('\\'))
regression_statements = parse_sql(regression_source)
for raw in regression_statements:
    if isinstance(raw.stmt, ast.DoStmt):
        body = next(o.arg.sval for o in raw.stmt.args if o.defname == 'as')
        parse_plpgsql_json('CREATE FUNCTION offline_test() RETURNS void LANGUAGE plpgsql AS $offline$'
                           + body + '$offline$')
print(f'PASS: {len(statements)} SQL statements, {procedural} PL/pgSQL functions, '
      f'{sql_bodies} SQL bodies, {len(public)} public RPCs; empty search_path on every function.')
print(f'PASS: {len(regression_statements)} regression SQL statements (psql directives excluded).')
print('NOT TESTED: live schema resolution, RLS/grants enforcement, Storage API, locks/concurrency.')
