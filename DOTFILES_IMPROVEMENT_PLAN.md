# Dotfiles Improvement Plan

이 문서는 현재 dotfiles를 새 macOS 환경에서도 재현 가능하고 안전하게
유지하기 위한 정리 계획이다. 각 단계는 앞 단계가 완료된 뒤 진행한다.

## 원칙

- 비밀값은 저장소에 넣지 않는다.
- `install.sh`는 시스템 준비와 심볼릭 링크만 담당한다.
- `bootstrap.fish`는 패키지 설치와 선택 프로필만 담당한다.
- 설치 실패는 성공으로 표시하지 않는다.
- 새 머신에서 문서만 보고 설치와 검증을 끝낼 수 있어야 한다.

## 1. Open-Meteo 전환 및 WeatherAPI 키 폐기

우선순위: Critical

대상:

- `.config/sketchybar/items/weather.lua`

작업:

1. WeatherAPI에서 현재 API 키를 폐기한다.
2. `weather.lua`의 하드코딩된 키와 WeatherAPI 요청을 제거한다.
3. API 키가 필요 없는 Open-Meteo의 현재 날씨 API로 교체한다.
4. IP 기반 위치 조회 결과를 위도와 경도로 검증한 뒤 HTTPS 요청에 사용한다.
5. Open-Meteo WMO 날씨 코드를 기존 SF Symbol 아이콘으로 매핑한다.
6. 기존 커밋에 노출된 키는 이미 유출된 것으로 간주한다. 공개 원격 저장소라면 키 폐기가 필수다.

완료 기준:

- `git grep`으로 WeatherAPI 키가 검색되지 않는다.
- 별도 환경 변수나 비밀 설정 파일 없이 날씨 위젯이 정상 갱신된다.
- 위치 조회에 실패하면 날씨 위젯은 오류 없이 비활성 상태로 표시된다.

## 2. 설치 경로와 책임 정리

우선순위: High

상태: 완료 (2026-07-11)

대상:

- `install.sh`
- `README.md`

작업:

1. `install.sh`가 `$HOME/.dotfiles`를 가정하지 않고, 스크립트 자체 위치에서 저장소 루트를 계산하도록 바꾼다.
2. Homebrew, Fish, GNU Stow 설치와 Stow 링크 생성까지만 `install.sh`에 남긴다.
3. iTerm2 설치 및 iTerm2 preferences 설정 블록을 제거한다. 현재 표준 터미널은 Ghostty다.
4. Dock, 창 제스처, 디스플레이 Space 설정은 별도 opt-in 스크립트로 분리한다.
5. `~/.zprofile`에 Homebrew PATH를 중복 추가하지 않도록 처리한다.
6. README를 실제 설치 흐름에 맞춰 다시 작성한다.

완료 기준:

- 임의의 clone 경로에서 `./install.sh`가 저장소를 올바르게 Stow한다.
- 기본 설치가 사용자의 Dock, 기본 셸, 시스템 설정을 예고 없이 바꾸지 않는다.
- README 명령을 처음부터 순서대로 실행할 수 있다.

## 3. Bootstrap 실패 처리 강화

우선순위: High

상태: 완료 (2026-07-11)

대상:

- `bootstrap.fish`
- `.config/fish/functions/_install_fisher_if_missing.fish`
- `.config/fish/functions/_install_mas_if_missing.fish`

작업:

1. 활성 설치 helper가 실패 시 반드시 non-zero를 반환하도록 만든다.
2. `bootstrap.fish`가 실패한 패키지를 수집해 마지막에 요약한다.
3. 하나의 패키지 실패가 나머지 독립 패키지 설치를 막을지, 끝까지 진행 후 실패 코드로 종료할지 정한다.
   권장 방식은 끝까지 진행하고 최종적으로 non-zero로 종료하는 것이다.
4. Homebrew tap 및 패키지 선언은 Brewfile로 단일화한다.
5. 설치 완료 메시지는 실패 목록이 없을 때만 출력한다.

완료 기준:

- 존재하지 않는 Homebrew formula를 임시로 넣었을 때 bootstrap은 non-zero로 끝난다.
- 실패한 패키지 이름이 최종 요약에 표시된다.
- 성공/실패 상태가 CI와 수동 실행에서 일치한다.

## 4. Alfred 추적 방식 재설계

우선순위: High

상태: export 구조 완료, workflow 선택 대기

대상:

- `.gitignore`
- `.config/alfred/`
- `assets/alfred/` 또는 `alfred/` (신규)

작업:

1. 현재 무시되는 로컬 workflow 디렉터리를 그대로 추적하지 않는다.
2. 필요한 워크플로우를 Alfred에서 `.alfredworkflow` 파일로 export한다.
3. export 파일을 새 전용 디렉터리에 추적한다.
4. 개인 토큰, 로컬 경로, 캐시가 포함된 워크플로우는 export 전 제거하거나 문서화한다.
5. README에 Alfred 가져오기 절차를 추가한다.

완료 기준:

- 새 머신에서 Alfred preferences와 필요한 workflow를 복원할 수 있다.
- workflow 캐시와 대용량 이미지 리소스가 작업 트리를 오염시키지 않는다.
- 저장소에는 비밀값이 포함되지 않는다.

## 5. SketchyBar와 launchd 정리

우선순위: Medium

상태: 완료 (2026-07-11)

대상:

- `launchagents/bootstrap.fish`
- `launchagents/teardown.fish`
- `launchagents/status.fish`
- `README.md`
- `.config/sketchybar/items/weather.lua`

작업:

1. README에 `fish launchagents/bootstrap.fish` 실행 시점을 명시한다.
2. 또는 bootstrap에 `--launchagents` 옵션을 추가해 명시적으로 등록하게 한다.
3. `launchagents/teardown.fish` 사용법과 로그 위치를 문서화한다.
4. launchd 등록 여부를 확인하는 검증 명령을 추가한다.
5. `/tmp` 파일을 사용하는 데몬의 상태, 로그, 재시작 방법을 한 곳에 정리한다.

완료 기준:

- 새 머신에서 media/calendar 데몬이 의도한 방식으로 등록된다.
- `launchctl list`와 각 로그로 상태를 확인할 수 있다.
- 해제 절차가 문서화되어 있다.

## 6. 죽은 경로와 오래된 설정 제거

우선순위: Medium

상태: 완료 (2026-07-11)

대상:

- `README.md`
- `.config/fish/functions/_pomodoro_toggle.fish`
- `.config/fish/functions/pomo.fish`
- `.aerospace.toml`
- `.config/nvim/lua/config/core/options.lua`

작업:

1. 존재하지 않는 `~/.config/sketchybar/plugins/*` 안내를 README에서 제거한다.
2. 존재하지 않는 `plugins/pomodoro.sh`를 호출하는 Fish 함수를 제거하거나, 현재 Lua Pomodoro 구현에 맞는 제어 경로로 다시 만든다.
3. iTerm2를 제거한다면 Aerospace의 iTerm2 규칙도 제거 또는 Ghostty 규칙으로 교체한다.
4. Neovim 옵션 주석의 iTerm2 언급을 Ghostty 기준으로 정리한다.
5. 사용하지 않는 설치 항목과 문서 명령을 삭제한다.

완료 기준:

- README의 모든 경로와 명령이 존재한다.
- `pomo`는 정상 동작하거나 더 이상 제공되지 않는다.
- 표준 터미널이 Ghostty로 일관되게 표현된다.

## 7. 패키지 선언 단일화

우선순위: Medium

상태: 완료 (2026-07-11)

대상:

- `bootstrap.fish`
- `Brewfile` (신규)
- `Brewfile.work` 또는 profile 구조 (선택)

작업:

1. 공통 Homebrew formula/cask/tap을 `Brewfile`로 옮긴다.
2. 업무용 도구는 별도 Brewfile 또는 `brew bundle --file` 선택 프로필로 분리한다.
3. Fish bootstrap은 Fisher, MAS, mise 등 Brewfile 밖의 설치만 담당하거나, 각 도구의 실행 순서만 조정한다.
4. Homebrew 설치 목록을 한 곳에서만 관리한다.

완료 기준:

- Formula, cask, tap 선언이 중복되지 않는다.
- 공통 설치는 `brew bundle` 한 번으로 재현된다.
- 업무용 도구는 명시적인 옵션을 통해서만 설치된다.

## 8. 자동 검증 추가

우선순위: Medium

상태: 완료 (2026-07-11)

대상:

- `tests/`
- `.github/workflows/validate.yml` (선택)

작업:

1. 모든 Fish 파일에 `fish --no-execute`를 실행한다.
2. Bash 파일에 `bash -n`을 실행한다.
3. LaunchAgent plist에 `plutil -lint`를 실행한다.
4. 임시 HOME에서 `stow --simulate`를 실행한다.
5. 격리 상태 경로로 headless Neovim을 시작하고 `NvimTreeToggle`을 검증한다.
6. API 키와 토큰 패턴을 검사하는 secret scan을 추가한다.

완료 기준:

- 현재 `tests/`가 비어 있는 상태를 해소한다.
- pull request 또는 커밋 전에 구성 오류를 자동으로 잡는다.
- Neovim 설정 변경이 nvim-tree 시작 오류를 재발시키지 않는다.

## 권장 진행 순서

1. 1단계: Open-Meteo 전환과 WeatherAPI 키 폐기
2. 2단계: 설치 스크립트 경로 및 시스템 변경 분리
3. 3단계: bootstrap 실패 상태 처리
4. 5단계: launchd 등록 흐름 문서화
5. 6단계: iTerm2, SketchyBar plugin, Pomodoro 잔재 정리
6. 4단계: Alfred workflow export 방식 도입
7. 7단계: Brewfile 기반 패키지 선언 단일화
8. 8단계: 검증 자동화와 CI 추가

## 현재 검증 상태

- Fish 문법 검사 통과
- Bash 문법 검사 통과
- LaunchAgent plist 검사 통과
- 격리된 Neovim 상태에서 `NvimTreeToggle` 실행 통과
- 자동화 테스트 파일은 아직 없음
