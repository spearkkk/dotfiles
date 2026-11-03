#!/bin/bash
# No real tmux server, notifications, HOME data or Hammerspoon in this test.
set -euo pipefail
export TEST_REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
python3 - <<'PY'
import json, os, pathlib, subprocess, tempfile
root=pathlib.Path(os.environ['TEST_REPO_ROOT'])
controller=root/'home/.local/libexec/tmux-reconcile-pane-activity'
worker=root/'home/.local/libexec/tmux-notify-pane-activity'
assert worker.is_file(), 'tmux-to-Nudge worker must be implemented'
with tempfile.TemporaryDirectory(prefix='tmux-nudge-') as directory:
 d=pathlib.Path(directory);home=d/'home';bin=d/'bin'
 bin.mkdir();(home/'.local/libexec').mkdir(parents=True);(home/'.local/bin').mkdir()
 (home/'.local/libexec/tmux-notify-pane-activity').symlink_to(worker)
 tmux=bin/'tmux'
 tmux.write_text('''#!/usr/bin/env python3
import os,sys,json,pathlib
p=pathlib.Path(os.environ['FIXTURE']);s=json.loads(p.read_text());a=sys.argv[1:]
s['calls'].append(a)
def save():p.write_text(json.dumps(s))
def output(value):print(value);save();sys.exit(0)
if a[0]=='wait-for':
 s['locked']=a[1]=='-L';save();sys.exit(0)
if a[0]=='list-panes':
 if a[-1]=='#{window_id}|#{pane_id}|#{@activity}':output('@1|%2|'+s['activity'])
 output(s['activity'])
if a[0]=='list-clients':
 flags='focused,UTF-8' if s['focused'] else 'UTF-8'
 if a[-1]=='#{client_flags}|#{pane_id}':output(flags+'|%2')
 output('client|'+flags+'|@1|%2|0')
if a[0]=='show-options':
 option=a[-1]
 if option=='@activity':output(s['activity'])
 if option=='@activity_window':output(s.get('window','idle'))
 output(s['options'].get(option,''))
if a[0]=='set-option':
 if s['fail_mutation']:save();sys.exit(1)
 unset=any(x.startswith('-') and 'u' in x for x in a[1:])
 option=a[-1] if unset else a[-2]
 if option=='@activity_nudge_error' and not unset:s['diagnostic_locked']=s['locked']
 if option=='@activity':s['activity']=a[-1]
 elif option=='@activity_window':s['window']=a[-1]
 elif unset:s['options'].pop(option,None)
 else:s['options'][option]=a[-1]
 save();sys.exit(0)
if a[0]=='display-message':
 if s['missing']:save();sys.exit(1)
 fmt=a[-1]
 values={'#{pane_title}':s['title'],'#{session_name}':s['session'],'#{window_index}:#{pane_index}':'2:1'}
 if fmt in values:output(values[fmt])
if a[0]=='run-shell':s['jobs'].append(a[-1]);save();sys.exit(0)
if a[0]=='refresh-client':save();sys.exit(0)
save();sys.exit(2)
''')
 tmux.chmod(0o755)
 nudge=home/'.local/bin/nudge'
 nudge.write_text('''#!/usr/bin/env python3
import os,sys,json,pathlib
p=pathlib.Path(os.environ['FIXTURE']);s=json.loads(p.read_text())
s['notifications'].append({'args':sys.argv[1:],'locked':s['locked']})
if os.environ.get('NUDGE_ADVANCE'):s['options']['@activity_nudge_token']='newer-token'
p.write_text(json.dumps(s));sys.exit(int(os.environ.get('NUDGE_EXIT','0')))
''');nudge.chmod(0o755)
 env=dict(os.environ,HOME=str(home),PATH=str(bin)+':'+os.environ['PATH'],FIXTURE=str(d/'state.json'))
 def write(s): (d/'state.json').write_text(json.dumps(s))
 def read(): return json.loads((d/'state.json').read_text())
 def reset(**overrides):
  s=dict(activity='idle',title='Idle',focused=False,missing=False,fail_mutation=False,
    session='project-alpha',options={},calls=[],jobs=[],notifications=[],locked=False)
  s.update(overrides);write(s)
 def run(*args):subprocess.run([str(controller),*args],env=env,check=True,timeout=5)
 def deliver(state=None,token=None,**environment):
  s=read();state=state or s['activity'];token=token or s['options'].get('@activity_nudge_token','')
  subprocess.run([str(worker),'%2',state,token],env=dict(env,**environment),check=True,timeout=5)
 def args():
  a=read()['notifications'][-1]['args'];assert a[0]=='send';return dict(zip(a[1::2],a[2::2]))
 def queued():
  s=read();assert len(s['jobs'])==1
  unlock=next(i for i,a in enumerate(s['calls']) if a[:2]==['wait-for','-U'])
  dispatch=next(i for i,a in enumerate(s['calls']) if a[0]=='run-shell')
  assert unlock<dispatch and not s['locked']
 tests=0
 def passed(name):
  global tests;tests+=1;print('ok - '+name)
 reset();run('command-done','%2');queued();deliver()
 assert args()['--severity']=='info' and args()['--source']=='tmux' and args()['--event']=='completed'
 assert args()['--subtitle']=='project-alpha' and '2' in args()['--body'] and '%2' in args()['--body']
 assert args()['--ttl-seconds']=='60' and not read()['notifications'][0]['locked']
 passed('completion dispatches info asynchronously after unlocking')
 reset(activity='working',title='Action Required | private command')
 run('reconcile-title','%2');queued();token=read()['options']['@activity_nudge_token'];deliver()
 assert args()['--severity']=='warning' and 'private command' not in json.dumps(args())
 deliver('waiting',token);assert len(read()['notifications'])==1
 run('reconcile-title','%2');assert len(read()['jobs'])==1
 passed('waiting is warning; repeated transition/job never duplicates')
 old_key=args()['--key'];s=read();s['title']='⠋ Working';write(s);run('reconcile-title','%2')
 s=read();s['title']='Action Required | again';write(s);run('reconcile-title','%2');deliver()
 assert args()['--key']!=old_key and len(read()['notifications'])==2
 passed('a fresh waiting cycle gets a distinct notification key')
 for op in ['command-done','reconcile-title']:
  reset(focused=True,activity='working',title='Action Required | repo');run(op,'%2')
  assert not read()['jobs']
 passed('focused panes retain tmux state behavior without a toast')
 for op in ['reconcile-all','reconcile-window']:
  reset(activity='working',title='Idle');run(*([op,'@1'] if op=='reconcile-window' else [op]))
  assert read()['activity']=='completed' and not read()['jobs']
 passed('reload and bulk reconciliation never replay alerts')
 for change in ['focused','missing','state','token']:
  reset();run('command-done','%2');token=read()['options']['@activity_nudge_token'];s=read()
  if change in ['focused','missing']:s[change]=True
  elif change=='state':s['activity']='working'
  else:s['options']['@activity_nudge_token']='newer-token'
  write(s);deliver('completed',token);assert not read()['notifications'] and not read()['locked']
 passed('queued worker drops focused, missing, changed and stale panes')
 reset(fail_mutation=True);run('command-done','%2');assert not read()['jobs']
 passed('failed state write cannot send a toast')
 reset();run('command-done','%2');deliver(NUDGE_EXIT='3')
 assert read()['activity']=='completed' and read()['options']['@activity_nudge_error']=='delivery failed (exit 3)'
 assert read()['diagnostic_locked'], 'diagnostic check/write must serialize with newer transitions'
 assert not read()['locked'];run('acknowledge-visible')
 passed('Nudge failure is diagnostic only; tmux state and lock remain healthy')
 reset();run('command-done','%2');deliver(NUDGE_EXIT='3',NUDGE_ADVANCE='1')
 assert '@activity_nudge_error' not in read()['options'] and not read()['locked']
 passed('a delivery failure cannot annotate a newer transition')
 marker=d/'injected'
 session='quotes " $(touch '+str(marker)+')\n한글'
 reset(session=session);run('command-done','%2');deliver()
 assert args()['--subtitle']==session and not marker.exists()
 assert session not in read()['jobs'][0]
 passed('metadata is passed as data, never as shell code')
 reset();run('command-done','%2');nudge.unlink();deliver()
 assert read()['options']['@activity_nudge_error']=='delivery failed (exit 127)'
 passed('missing Nudge is nonfatal without retries or launching anything')
 print('PASS: tmux-nudge ('+str(tests)+' groups)')
PY
