# Libexec helper relocation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking. This document authorizes no implementation, installation, commit, or service reload by itself.

**Goal:** tmux 상태바 렌더러와 SketchyBar 데몬 2개를 `scope-action-target` 이름의 내부 실행 진입점으로 이동한다.

**Architecture:** 실행 파일 본문은 그대로 유지하고 위치·이름·호출 경로만 바꾼다. tmux와 launchd는 `~/.local/libexec/`의 명시적 경로로 실행한다. 확장자가 없어져도 검사에서 누락되지 않도록 전용 회귀 테스트를 `setup/check.fish`에 연결한다.

**Tech Stack:** macOS, POSIX sh, Bash 3.2, fish, tmux, launchd/plist, GNU Stow, Python 3 표준 라이브러리. 새 의존성 없음.

**Spec:** 아래 「확정 범위와 불변 조건」이 이 작은 변경의 자족적인 설계다. 별도 설계서·티켓에 의존하지 않는다. 사용자가 계획 작성, 구현 진행, 이후 커밋·통합·실환경 적용을 순서대로 승인했다. 최종 반영 결과는 문서 마지막에 기록한다.

## Global Constraints

- 설치될 파일은 `home/`, 설치/검증 코드는 `setup/`, 문서는 `share/`에 둔다.
- 이름은 `scope-action-target`; 세 파일은 shebang과 실행 권한을 유지하고 확장자는 제거한다.
- 현재 macOS 도구와 fish를 사용한다. 런타임이 없으면 `mise`를 먼저 확인한다.
- `profiles/work/`는 local-only다. 새 워크트리에 복사하거나 추적 파일로 승격하지 않는다.
- 실제 `~/`의 링크, tmux 서버, LaunchAgent를 계획 작성·자동 테스트 과정에서 변경하지 않는다.
- 커밋 전 변경 파일의 비밀값을 검사한다. 커밋/통합/실환경 적용은 사용자 요청 후 수행한다.

## 작업 공간 및 기준 상태

- 원본: `/Users/al02494219/.dotfiles` (`main`, clean).
- 기준 커밋: `71a057e`.
- managed worktree: `/Users/al02494219/.codex/worktrees/6401/.dotfiles`.
- 생성 당시 detached HEAD였으며 구현 브랜치 `refactor/libexec-helper-relocation`을 연결했다. 새 워크트리를 중복 생성하지 않았다.
- 관련 기준 검증: `tmux-reconcile-pane-activity.test.sh`, `cw-multi-context.test.sh`, plist validation, 이동 대상 3개의 shell syntax 검사 통과.
- 전체 `fish setup/check.fish`: 기존 SSH 테스트 1건 실패. `setup/tests/ssh-config.test.sh`가 Git에서 제외된 `profiles/work/home/.ssh/config.d/0200-work.conf`를 직접 참조하지만 새 워크트리에는 해당 파일이 없다. 이 실패는 이번 변경 이전부터 존재한다. 이를 숨기거나 테스트를 무조건 skip하지 않는다.
- 권한 승인 후 전체 검사를 재실행했다. mise 캐시 경고 없이 동일한 SSH 테스트 1건만 실패(exit 1)했고 나머지 검사·Stow simulation·비밀값 검사는 통과했다. SSH fixture 부재는 샌드박스 문제와 별개다.

## 확정 범위와 불변 조건

| 이전 경로 | 새 경로 |
|---|---|
| `home/.tmux/scripts/status-box.sh` | `home/.local/libexec/tmux-render-status-box` |
| `home/.config/sketchybar/daemons/calendar.sh` | `home/.local/libexec/sketchybar-run-calendar-daemon` |
| `home/.config/sketchybar/daemons/media.sh` | `home/.local/libexec/sketchybar-run-media-daemon` |

1. 세 실행 파일 본문은 바이트 단위로 유지한다. Git 모드는 `100755`를 유지한다.
2. tmux renderer의 인자, 출력, quoting, 실행 횟수는 유지한다.
3. 데몬의 cache/PID/refresh 경로, polling 간격, 이벤트 이름, 단일 인스턴스 로직은 유지한다.
4. LaunchAgent의 Label, `/bin/bash -lc`, PATH, KeepAlive, RunAtLoad, 로그 경로는 유지한다. ProgramArguments의 실행 대상 문자열만 바꾼다.
5. 옛 경로에 compatibility wrapper나 symlink를 추가하지 않는다. 활성 설정 전환은 명시적인 배포 절차로 다룬다.
6. libexec를 PATH에 추가하지 않는다. 설정·Lua 모듈·fish 함수는 이동하지 않는다.
7. `ai-review`, `weather.lua`, `mediactl`, `todays-daemon`, work 프로필은 범위 밖이다. 발견된 기존 문제도 섞어서 수정하지 않는다.

## 변경 파일 지도

- 위 표의 파일 3개: rename only.
- `home/.tmux.conf`: status-format[2] 안의 renderer 경로 1곳.
- `setup/tests/tmux-reconcile-pane-activity.test.sh`: renderer 변수와 이름 출현 횟수 assertion.
- `setup/tests/cw-multi-context.test.sh`: renderer 변수.
- `setup/launchagents/plists/dev.spearkkk.sketchybar.calendar-daemon.plist`: 실행 경로.
- `setup/launchagents/plists/dev.spearkkk.sketchybar.media-daemon.plist`: 실행 경로.
- `setup/tests/libexec-layout.test.sh`: 새 위치·권한·문법·plist 계약을 검증하는 신규 테스트.
- `setup/check.fish`: 신규 테스트 등록. 전체 파일 탐색기를 일반화하는 리팩터링은 하지 않는다.
- `README.md`: 공통 libexec 규칙과 적용 시 주의사항.

## Task 1: tmux renderer 이동

**Interfaces:** 소비자는 `.tmux.conf`와 기존 테스트 2개다. 생산 인터페이스는 `tmux-render-status-box BG FG BORDER [PREFIXED_CONTEXTS]`이며, 기존 `x` 접두사 처리와 stdout 출력 그대로다.

- [x] **1. 기존 테스트를 새 계약으로 먼저 수정한다.** 두 테스트의 `renderer`를 `$repo_root/home/.local/libexec/tmux-render-status-box`로 바꾸고, reconcile 테스트의 횟수 assertion을 아래처럼 바꾼다. 같은 테스트에 권한·옛 파일 부재·문법 검사를 추가한다.

```bash
[[ $(grep -o 'tmux-render-status-box' "$tmux_config" | wc -l | tr -d ' ') == 1 ]]
[[ -x "$renderer" ]]
[[ ! -e "$repo_root/home/.tmux/scripts/status-box.sh" ]]
[[ ! -L "$repo_root/home/.tmux/scripts/status-box.sh" ]]
/bin/sh -n "$renderer"
```

- [x] **2. RED를 확인한다.** 각각 실행해 새 경로 부재 또는 설정 assertion 때문에 실패하는지 확인한다. 의존 도구 오류를 의도한 실패로 취급하지 않는다.

```fish
bash setup/tests/tmux-reconcile-pane-activity.test.sh
bash setup/tests/cw-multi-context.test.sh
```

- [x] **3. 파일을 이동하고 설정을 최소 변경한다.** `.tmux.conf`에서는 `~/.tmux/scripts/status-box.sh`만 `~/.local/libexec/tmux-render-status-box`로 치환한다. 나머지 tmux format과 escaping은 유지한다.

```fish
git mv home/.tmux/scripts/status-box.sh home/.local/libexec/tmux-render-status-box
```

- [x] **4. GREEN을 확인한다.** 위 테스트 2개를 다시 실행한다. 출력/컨텍스트 렌더링의 기존 assertion도 모두 통과해야 한다.
- [x] **5. 변경을 리뷰한다.** `git diff HEAD -- home/.tmux.conf setup/tests` 및 `git diff HEAD --summary`로 변경 범위를 확인한다. 커밋을 요청받은 경우에만 비밀값 검사 후 `Move tmux status renderer to libexec`로 커밋한다.

## Task 2: SketchyBar 데몬 이동 및 확장자 없는 파일 검사

**Interfaces:** launchd는 `/bin/bash -lc 'exec ~/.local/libexec/sketchybar-run-…-daemon'`으로 실행한다. 새 테스트는 실제 데몬을 기동하지 않고 파일·plist·shell syntax만 검사하며 exit 0/1로 결과를 반환한다.

- [x] **1. `setup/tests/libexec-layout.test.sh`를 아래 내용으로 작성한다.** 이전 경로가 문자열로 등장하는 이 테스트 자체는 정상이다. 저장소 전체에서 옛 경로 문자열이 0개인지 검사해서는 안 된다.

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
python3 - "$repo_root" <<'PY'
import os
import plistlib
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
cases = [
    ('home/.tmux/scripts/status-box.sh', 'tmux-render-status-box', '/bin/sh'),
    ('home/.config/sketchybar/daemons/calendar.sh',
     'sketchybar-run-calendar-daemon', '/bin/bash'),
    ('home/.config/sketchybar/daemons/media.sh',
     'sketchybar-run-media-daemon', '/bin/bash'),
]
for old, name, shell in cases:
    path = root / 'home/.local/libexec' / name
    assert path.is_file(), f'missing helper: {name}'
    assert os.access(path, os.X_OK), f'not executable: {name}'
    assert not os.path.lexists(root / old), f'legacy entry remains: {old}'
    subprocess.run([shell, '-n', str(path)], check=True)

for kind in ('calendar', 'media'):
    label = f'dev.spearkkk.sketchybar.{kind}-daemon'
    path = root / 'setup/launchagents/plists' / f'{label}.plist'
    with path.open('rb') as stream:
        plist = plistlib.load(stream)
    assert plist['Label'] == label
    assert plist['ProgramArguments'] == [
        '/bin/bash', '-lc',
        f'exec ~/.local/libexec/sketchybar-run-{kind}-daemon',
    ]
    assert plist['KeepAlive'] is True
    assert plist['RunAtLoad'] is True
    assert plist['EnvironmentVariables']['PATH'] == (
        '/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin'
    )
    assert plist['StandardOutPath'] == f'/tmp/{label}.log'
    assert plist['StandardErrorPath'] == f'/tmp/{label}.err.log'
print('PASS: libexec-layout')
PY
```

- [x] **2. RED를 확인한다.** `bash setup/tests/libexec-layout.test.sh`를 실행한다. Task 1 완료 상태에서는 첫 SketchyBar 데몬의 새 경로 부재로 실패해야 한다.
- [x] **3. 파일과 plist 경로만 바꾼다.** 아래 rename 후, 두 plist의 실행 문자열을 각각 `exec ~/.local/libexec/sketchybar-run-calendar-daemon`, `exec ~/.local/libexec/sketchybar-run-media-daemon`으로 변경한다.

```fish
git mv home/.config/sketchybar/daemons/calendar.sh home/.local/libexec/sketchybar-run-calendar-daemon
git mv home/.config/sketchybar/daemons/media.sh home/.local/libexec/sketchybar-run-media-daemon
```

- [x] **4. 전용 검사를 등록한다.** `setup/check.fish`의 Shell syntax 블록 다음, SSH config 블록 전에 아래를 추가한다. 기존 `.sh` 검색은 유지한다. 이 등록으로 새 helper 3개는 확장자 유무와 무관하게 항상 검사된다.

```fish
log_step "Internal executable layout"
if not bash "$repo_root/setup/tests/libexec-layout.test.sh"
    mark_fail "Internal executable layout checks failed."
end
```

- [x] **5. GREEN 및 통합을 확인한다.**

```fish
bash setup/tests/libexec-layout.test.sh
fish -n setup/check.fish
make -C setup/launchagents validate
fish setup/check.fish
```

새 layout 테스트와 plist validation은 통과해야 한다. 전체 검사는 기준 상태의 SSH fixture 실패를 별도 보고하고, 추가 실패가 없어야 한다. 실제 데몬 실행으로 calendar/media 데이터를 읽거나 cache를 쓰지 않는다.

- [x] **6. 리뷰한다.** `git diff HEAD -- setup/launchagents setup/check.fish setup/tests/libexec-layout.test.sh`를 확인한다. 커밋 요청이 있는 경우에만 비밀값 검사 후 `Move SketchyBar daemons to libexec`로 커밋한다.

## Task 3: 문서·최종 검증·배포 준비

**Interfaces:** README는 사용자 명령과 내부 진입점의 차이 및 적용 경계를 설명한다. 적용 대상은 일시적인 워크트리가 아닌 원본 active dotfiles 저장소다.

- [x] **1. README의 Structure 설명을 보완한다.** 기존 프로필 전용 libexec 설명을 아래로 교체한다.

```text
User-facing commands belong under home/.local/bin/. Internal executable entry
points belong under home/.local/libexec/ and use scope-action-target names.
Profile-owned helpers follow the same rule inside that profile's home/.
Loaded shell functions and application modules remain in their native paths.
The tmux status renderer and SketchyBar calendar/media daemons are internal
entry points; their callers use explicit ~/.local/libexec/ paths.
```

아래 적용 절차에서 「워크트리를 실제 홈에 Stow하지 않기」「Stow와 plist 재설치 및 서비스 재시작이 모두 필요함」을 짧게 README에도 기록한다.

- [x] **2. 본문 불변을 확인한다.** 아래를 워크트리에서 실행한다. 세 파일 모두 기준 커밋의 원본과 일치해야 한다.

```sh
python3 - <<'PY'
import subprocess
from pathlib import Path
for old, new in [
    ('home/.tmux/scripts/status-box.sh', 'tmux-render-status-box'),
    ('home/.config/sketchybar/daemons/calendar.sh', 'sketchybar-run-calendar-daemon'),
    ('home/.config/sketchybar/daemons/media.sh', 'sketchybar-run-media-daemon'),
]:
    before = subprocess.check_output(['git', 'show', f'71a057e:{old}'])
    assert (Path('home/.local/libexec') / new).read_bytes() == before, new
print('PASS: helper bodies unchanged')
PY
```

- [x] **3. 대상 검증을 최종 실행한다.**

```fish
bash setup/tests/libexec-layout.test.sh
bash setup/tests/tmux-reconcile-pane-activity.test.sh
bash setup/tests/cw-multi-context.test.sh
make -C setup/launchagents validate
fish setup/check.fish
git diff HEAD --check
git diff HEAD --summary
git status --short
```

실행 결과를 실제 exit code와 함께 기록한다. SSH fixture의 기존 실패를 전체 검증 성공으로 표현하지 않는다. 신규 layout 테스트가 `setup/check.fish` 출력에 나타나는지 확인한다.

- [x] **4. 사용자에게 구현 결과와 별도 적용 승인을 요청한다.** 이 단계에서는 commit/merge, 실제 Stow, tmux reload, launchctl을 실행하지 않는다. 사용자가 커밋을 요청한 경우에만 검토된 변경 파일을 명시적으로 stage하고 imperative 메시지로 커밋한다.

## 실제 적용 절차 — 별도 승인 후에만 실행

1. 원본 active 저장소의 현재 브랜치·변경 사항과 실제 링크를 확인한다. 워크트리에서 `--target=$HOME`으로 Stow하지 않는다.
2. 원본에 변경을 통합하기 직전에 기존 두 LaunchAgent를 `launchctl bootout gui/(id -u)/<label>`로 중지하고 종료를 확인한다. `setup/launchagents/teardown.fish`는 disable까지 수행하므로 이번 경로 전환에는 사용하지 않는다. 프로세스 종료 전에 살아 있는 PID 파일을 지우지 않는다.
3. 승인된 방식으로 원본 저장소에 변경을 통합한다. 강제 reset/push로 적용하지 않는다.
4. 원본에서 `stow --simulate --verbose --restow --no-folding --dir=home --target=$HOME .`를 실행한다. 이전 위치의 dangling symlink가 남으면 원본이 관리하던 세 링크인지 대상까지 확인하여 승인 후 그 링크만 제거한다. 실제 사용자 파일이나 디렉터리를 일괄 삭제하지 않는다.
5. dry-run이 안전하면 원본에서 Stow를 적용한다. 새 세 경로의 실행 가능 여부와 링크 목적지가 원본 active 저장소인지 확인한다.
6. 원본에서 `make -C setup/launchagents bootstrap`을 실행한다. plist는 복사 설치되므로 Stow만으로는 실행 경로가 갱신되지 않는다. Label은 바꾸지 않는다.
7. `tmux source-file ~/.tmux.conf`를 실행해 기존 세션의 옛 renderer 경로를 갱신한다.
8. `make -C setup/launchagents status`, 실제 상태바, 두 데몬의 상태·캐시 갱신을 확인한다. 실패 시 원인을 보고하고 승인 없이 추가 수정을 하지 않는다. 로그나 calendar/media 내용을 공개 문서에 복사하지 않는다.

## 되돌리기

실환경 적용 실패 시 먼저 두 LaunchAgent를 중지한다. 승인된 revert 또는 이전 파일 복원으로 실행 파일과 호출 경로를 한 세트로 되돌린 다음 원본에서 Stow, plist 재설치/재시작, tmux reload를 수행한다. 단순히 파일 이름만 되돌리거나 강제 Git reset을 사용하지 않는다. 기존 cache 및 사용자 데이터는 삭제하지 않는다.

## 계획 검토 체크리스트

- [x] 3개 이동과 호출부·테스트·문서 외의 기능 변경은 제외했다.
- [x] 테스트 RED/GREEN 단계, 기대 실패와 성공 조건을 명시했다.
- [x] 확장자 없는 파일의 문법 검사 누락을 전용 테스트로 막았다.
- [x] 실행 파일 본문 및 plist 비경로 설정의 불변 검증을 포함했다.
- [x] 기준 상태의 SSH 테스트 실패와 로컬 전용 프로필 경계를 기록했다.
- [x] 임시 워크트리와 active 설치 원본을 구분하고 적용·되돌리기를 별도 승인으로 남겼다.


## 구현 및 검증 결과 — 2026-11-04, 실환경 적용 전

- Task 1–3의 구현·문서·검증을 완료했다. 조건부 커밋 단계는 사용자 요청이 없어 실행하지 않았다. 변경 사항은 워크트리에 보존되어 있다.
- tmux 회귀 테스트 2개: 새 경로 부재로 RED(exit 127)를 확인하고 이동 후 GREEN(exit 0)을 확인했다.
- 신규 layout 테스트: calendar helper 부재로 RED(exit 1)를 확인한 뒤 3개 파일 이동·plist 변경 후 GREEN(exit 0)을 확인했다.
- 세 실행 파일은 기준 커밋 `71a057e`의 원본과 바이트 단위로 같고 모드 `755`를 유지한다. 두 plist는 실행 경로 외의 파싱 결과가 동일하다.
- 임시 복사본에서 파일 누락, 실행 권한 제거, shell 문법 오류, 옛 plist 경로, dangling legacy symlink를 각각 주입했다. 정상본은 exit 0, 다섯 변이본은 모두 exit 1로 검출되었다. 실제 데몬은 실행하지 않았다.
- `fish -n setup/check.fish`, plist validation, `git diff HEAD --check` 통과. 활성 설정 및 LaunchAgent 소스에 옛 경로 참조가 없음을 확인했다.
- 전체 `fish setup/check.fish`: 신규 layout 검사 포함 나머지 검사는 통과했고, 기준 상태와 동일한 SSH fixture 부재 1건만 실패(exit 1)했다. 기존 실패를 숨기거나 work 프로필을 복사하지 않았다. Stow simulation과 비밀값 검사도 통과했다.
- 독립 코드 리뷰: Critical/Important 지적 없음. 실제 migration과 서비스 재시작은 검증하지 않은 제한 사항으로 남겼다.
- 원본 active 저장소는 변경하지 않았다. 커밋·통합·실제 Stow·사용자 tmux reload·LaunchAgent 재시작을 실행하지 않았다.
- 위 실제 적용 절차와 되돌리기는 여전히 별도 승인이 필요하다. 전체 검사에는 기존 실패가 남아 있으므로 전체 테스트 성공으로 보고하지 않는다.

## 최종 반영 결과 — 2026-11-04

- 사용자 승인 후 `3afcf75` (`Move internal helpers to libexec`)를 커밋하고 원본 `main`에 fast-forward로 반영했다. 원격 push는 하지 않았다.
- 기존 두 LaunchAgent와 해당 프로세스가 종료된 것을 확인한 뒤 경로를 전환했다. 원본을 가리키던 옛 symlink 3개만 확인 후 제거하고, Stow dry-run 및 실제 restow로 새 링크를 설치했다. 임시 워크트리는 설치 원본으로 사용하지 않았다.
- LaunchAgent plist 재설치·재시작과 tmux 설정 reload를 완료했다. 두 데몬이 새 libexec 경로로 실행되고, PID 파일과 실행 PID가 일치하며, 두 캐시가 재시작 이후 계속 갱신됨을 확인했다. 캐시 내용은 기록하지 않았다.
- 실제 tmux 설정이 새 렌더러를 참조하고 설치된 렌더러가 실행됨을 확인했다. SketchyBar의 `todays`, `media_label` 상태 조회도 성공했다. 화면의 시각적 배치는 별도로 캡처하지 않았다.
- 원본에서 `fish setup/check.fish` 전체 통과(exit 0). SSH 검사도 로컬 work 프로필이 있는 원본에서는 통과했으며, 프로필 파일이나 관련 비밀값을 추적 경로로 옮기지 않았다.
- 앱 관리 워크트리와 구현 브랜치는 보존했다. 호스트가 관리하는 워크트리를 수동 삭제하지 않았다.
