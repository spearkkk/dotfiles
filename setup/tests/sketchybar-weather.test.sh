#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
lua_bin=${LUA_BIN:-lua}
python3 - "$repo_root" "$lua_bin" <<'PY'
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
lua = sys.argv[2]
helper = root / 'home/.local/libexec/sketchybar-fetch-weather'
assert helper.is_file(), 'missing sketchybar-fetch-weather helper'
assert os.access(helper, os.X_OK), 'weather helper must be executable'
subprocess.run(['/bin/bash', '-n', str(helper)], check=True)

with tempfile.TemporaryDirectory(prefix='sketchybar-weather-') as tmp:
    base = Path(tmp)
    home = base / "home with ' spaces"
    bin_dir = base / 'bin'
    bin_dir.mkdir()
    installed = home / '.local/libexec/sketchybar-fetch-weather'
    installed.parent.mkdir(parents=True)
    installed.symlink_to(helper)
    location = base / 'location.txt'
    weather = base / 'weather.json'
    calls = base / 'calls.log'
    arguments = base / 'arguments.log'
    curl = bin_dir / 'curl'
    curl.write_text('''#!/bin/bash
set -eu
url=${!#}
printf '%s\\n' "$url" >> "$CALL_LOG"
printf '%s\\n' "$@" >> "$ARGUMENT_LOG"
case "$url" in
  ipinfo.io/loc)
    /bin/cat "$LOCATION_FILE"
    exit "${LOCATION_EXIT:-0}"
    ;;
  https://api.open-meteo.com/v1/forecast[?]*)
    /bin/cat "$WEATHER_FILE"
    exit "${WEATHER_EXIT:-0}"
    ;;
  *) echo 'unexpected curl URL' >&2; exit 99 ;;
esac
''')
    curl.chmod(0o755)
    env = dict(os.environ, HOME=str(home), PATH=f'{bin_dir}:{os.environ["PATH"]}',
               LOCATION_FILE=str(location), WEATHER_FILE=str(weather), CALL_LOG=str(calls),
               ARGUMENT_LOG=str(arguments),
               LOCATION_EXIT='0', WEATHER_EXIT='0')
    good = '{"current":{"weather_code":3,"temperature_2m":18.4,"is_day":1}}'

    def check(name, loc='37.5,127.0\n', body=good, expected=None, status=0,
              loc_exit='0', weather_exit='0', requests=2):
        location.write_text(loc)
        weather.write_text(body)
        calls.write_text('')
        arguments.write_text('')
        result = subprocess.run([str(installed)], cwd='/',
                                env=dict(env, LOCATION_EXIT=loc_exit, WEATHER_EXIT=weather_exit),
                                text=True, capture_output=True, timeout=5)
        assert (result.returncode == 0) == (status == 0), (name, result.returncode, result.stderr)
        if status == 0:
            assert result.stdout == expected, (name, result.stdout)
            assert not result.stderr, (name, result.stderr)
        else:
            assert result.stdout == '', (name, 'failure leaked stdout', result.stdout)
            assert result.stderr.strip(), (name, 'missing error diagnostic')
        urls = calls.read_text().splitlines()
        assert len(urls) == requests, (name, urls)
        return urls

    urls = check('valid day', expected='3\t18.4\t1\n')
    assert urls == ['ipinfo.io/loc',
                    'https://api.open-meteo.com/v1/forecast?latitude=37.5&longitude=127.0&current=temperature_2m,weather_code,is_day']
    check('negative temperature', body='{"current":{"weather_code":71,"temperature_2m":-3.6,"is_day":0}}',
          expected='71\t-3.6\t0\n')
    check('zero values', body='{"current":{"weather_code":0,"temperature_2m":0,"is_day":0}}',
          expected='0\t0\t0\n')
    urls = check('coordinate whitespace', loc='  -0.5 , -120.25  \n', expected='3\t18.4\t1\n')
    assert 'latitude=-0.5&longitude=-120.25&' in urls[1]
    check('location transport error', status=1, loc_exit='22', requests=1)
    check('weather transport error with partial response', status=1, weather_exit='22')
    check('location timeout', status=1, loc_exit='28', requests=1)
    check('weather timeout with partial response', status=1, weather_exit='28')
    for loc in ('', 'not coordinates', '37.5', '37.5,127.0&extra=1', '37.5,127.0\n1,2'):
        check('invalid coordinates', loc=loc, status=1, requests=1)
    for body in ('', 'not json', 'null', '{}', '{"current":null}', '[]', good + '\n' + good):
        check('invalid response', body=body, status=1)
    for field, values in (
        ('weather_code', [None, '3', -1, 1.5, True]),
        ('temperature_2m', [None, '18.4', [], True]),
        ('is_day', [None, '1', 2, True]),
    ):
        for value in values:
            data = json.loads(good)
            data['current'][field] = value
            check(f'invalid {field}', body=json.dumps(data), status=1)
        data = json.loads(good)
        del data['current'][field]
        check(f'missing {field}', body=json.dumps(data), status=1)
    check('non-finite temperature', body='{"current":{"weather_code":3,"temperature_2m":1e999,"is_day":1}}', status=1)
    print('PASS: weather helper data, validation, failures, quoted HOME and arbitrary cwd', flush=True)

    urls = check('bounded network requests', expected='3\t18.4\t1\n')
    request_args = arguments.read_text().splitlines()
    start = 0
    for index, value in enumerate(request_args):
        if value in ('ipinfo.io/loc', urls[1]):
            options = request_args[start:index]
            assert '--connect-timeout' in options, 'each HTTP request needs a connection timeout'
            assert '--max-time' in options, 'each HTTP request needs an overall timeout'
            assert 0 < float(options[options.index('--connect-timeout') + 1]) <= 3
            assert 0 < float(options[options.index('--max-time') + 1]) <= 8
            assert options[0] in ('-q', '--disable'), 'ignore curlrc that can override bounded requests'
            start = index + 1
    assert start == len(request_args), 'all HTTP request arguments must be checked'
    print('PASS: both HTTP requests use bounded timeouts and ignore user curlrc', flush=True)

    location.write_text('37.5,127.0\n')
    weather.write_text(good)
    result = subprocess.run([lua, str(root / 'setup/tests/sketchybar-weather.test.lua'), str(root)],
                            cwd='/', env=env, text=True, capture_output=True, timeout=15)
    assert result.returncode == 0, result.stderr
    print(result.stdout, end='')
PY
