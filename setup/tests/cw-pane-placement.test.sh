#!/bin/bash
# Real tmux/fish, isolated HOME/server and synthetic providers only.
set -euo pipefail
export TEST_REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - <<'PY'
import json, os, pathlib, shutil, subprocess, tempfile, time

root = pathlib.Path(os.environ['TEST_REPO_ROOT'])
fish = shutil.which('fish')
with tempfile.TemporaryDirectory(prefix='cw-placement-', dir='/tmp') as directory:
    home = pathlib.Path(directory)
    socket = str(home / 'socket')
    config = home / '.config/fish'
    (config / 'functions').mkdir(parents=True)
    (config / 'functions/cw.fish').symlink_to(root / 'home/.config/fish/functions/cw.fish')
    (config / 'config.fish').write_text('''
function __cw_context --argument-names name
    printf '%s\\n' name=demo requested=$name type=demo env=dev cwd=$HOME session=unused-default inject=demo_inject restore=demo_inject eject=demo_eject
end
function demo_inject --argument-names pane instance
    tmux set-option -p -t "$pane" @demo_injected 1
    tmux set-option -p -t "$pane" @demo_argument (__cw_get requested $argv[3..-1])
end
function demo_eject
end
''')
    env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'),
               CW_CONTEXT_HELPER=str(root / 'home/.local/libexec/tmux-manage-pane-context'))
    env.pop('TMUX', None)
    env.pop('TMUX_PANE', None)
    client = None

    def tmux(*args):
        return subprocess.check_output(['tmux', '-S', socket, *args], env=env, text=True, timeout=5).strip()

    def rows():
        data = tmux('list-panes', '-a', '-F', '#{pane_id}|#{session_name}|#{window_id}|#{pane_left}|#{pane_top}')
        return {r[0]: r[1:] for r in (line.split('|') for line in data.splitlines())}

    def applied(pane, name):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            raw = tmux('show-options', '-pqv', '-t', pane, '@contexts')
            if raw:
                contexts = json.loads(raw)['contexts']
                if len(contexts) == 1 and contexts[0]['id'] == 'demo' and contexts[0]['state'] == 'active':
                    assert tmux('show-options', '-pqv', '-t', pane, '@demo_injected') == '1'
                    assert tmux('show-options', '-pqv', '-t', pane, '@demo_argument') == name
                    return
            time.sleep(.05)
        raise AssertionError('context did not activate in ' + pane + ': ' +
                             tmux('capture-pane', '-p', '-t', pane))

    try:
        original = tmux('-f', '/dev/null', 'new-session', '-d', '-x', '180', '-y', '80',
                        '-P', '-F', '#{pane_id}', '-s', 'main', fish)
        tmux('set-option', '-g', 'default-shell', fish)
        other = tmux('new-session', '-d', '-P', '-F', '#{pane_id}', '-s', 'other', fish)
        client = subprocess.Popen(['tmux', '-S', socket, '-C', 'attach-session', '-t', 'main'],
                                  env=env, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL)
        deadline = time.monotonic() + 5
        while not tmux('list-clients'):
            assert time.monotonic() < deadline, 'control client failed to attach'
            time.sleep(.05)

        def cw(name, *flags, outside=False):
            caller_env = dict(env, TMUX=socket+',0,0', TMUX_PANE=original)
            if outside:
                caller_env.pop('TMUX_PANE')
                caller_env.pop('TMUX')
                # tmux socket selection for an outside caller without touching the default server.
                wrapper = home / 'bin'
                wrapper.mkdir(exist_ok=True)
                executable = wrapper / 'tmux'
                executable.write_text('#!/bin/sh\nexec "'+shutil.which('tmux')+'" -S "'+socket+'" "$@"\n')
                executable.chmod(0o755)
                caller_env['PATH'] = str(wrapper) + ':' + env['PATH']
            subprocess.run([fish, '-c', 'cw $argv', '--', name, *flags], env=caller_env, check=True, timeout=10)

        before = rows()
        cw('demo')
        assert rows() == before
        applied(original, 'demo')
        print('ok - default applies in the current pane without creating a window or pane')

        for flags, anchor, bottom, outside in [
            (['--pane'], original, False, False),
            (['--pane', '--bottom'], original, True, False),
            (['--session', 'other'], other, False, False),
            (['--session', 'other', '--bottom'], None, True, True),
        ]:
            if anchor is None:
                anchor = tmux('display-message', '-p', '-t', '=other:', '#{pane_id}')
            before = rows()
            name = "quote' 한글; touch " + str(home / 'injected')
            cw(name, *flags, outside=outside)
            after = rows()
            added = set(after) - set(before)
            assert len(added) == 1, (flags, added)
            pane = added.pop()
            assert after[pane][:2] == before[anchor][:2], 'wrong session/window'
            x, y = map(int, after[pane][2:])
            ax, ay = map(int, after[anchor][2:])
            assert (x == ax and y > ay) if bottom else (x > ax and y == ay), (flags, after)
            applied(pane, name)
            assert not (home / 'injected').exists(), 'context became shell code'
            print('ok -', ' '.join(flags), 'creates one correctly placed pane and activates context')
        print('PASS: cw pane placement and fresh fish autoload')
    finally:
        if pathlib.Path(socket).exists():
            subprocess.run(['tmux', '-S', socket, 'kill-server'], env=env,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        if client:
            client.wait(timeout=5)
            client.stdin.close()
PY
