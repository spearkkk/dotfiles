# Dotfiles

macOS용 개인 환경 설정이다. 기본 설치는 Homebrew, Fish, GNU Stow 설치와
설정 파일 링크만 수행한다. 기본 셸과 macOS 기본값은 명시적으로 요청할 때만
변경한다.

## 설치

원하는 경로에 저장소를 clone한 뒤 설치 스크립트를 실행한다. 저장소 위치는
`~/.dotfiles`일 필요가 없다.

```shell
bash /path/to/dotfiles/install.sh
```

설치 스크립트는 다음만 수행한다.

- Homebrew 설치 및 셸 환경 등록
- Fish, GNU Stow 설치
- 저장소 설정을 `$HOME`에 심볼릭 링크로 연결

## 공통 도구 설치

링크 생성 후 공통 Homebrew, Fisher, MAS 도구를 설치한다.

```shell
fish /path/to/dotfiles/bootstrap.fish
```

Homebrew formula, cask, tap 선언은 [Brewfile](Brewfile)에만 둔다. Homebrew 패키지만
직접 적용하거나 확인하려면 다음을 사용한다.

```shell
brew bundle install --file /path/to/dotfiles/Brewfile
brew bundle check --file /path/to/dotfiles/Brewfile
```

업무용 도구도 설치하려면 다음을 사용한다.

```shell
fish /path/to/dotfiles/bootstrap.fish --work
```

업무용 Homebrew 패키지는 [Brewfile.work](Brewfile.work)에 별도로 선언한다.

## SketchyBar LaunchAgents

media와 calendar 위젯의 백그라운드 데몬은 명시적으로 등록한다. 공통 도구 설치와
함께 등록하려면 다음을 실행한다.

```shell
fish /path/to/dotfiles/bootstrap.fish --launchagents
```

이미 공통 도구를 설치했다면 LaunchAgent만 별도로 등록할 수 있다.

```shell
fish /path/to/dotfiles/launchagents/bootstrap.fish
```

상태와 로그 위치는 다음 명령으로 확인한다.

```shell
fish /path/to/dotfiles/launchagents/status.fish
```

데몬을 다시 등록하려면 bootstrap 명령을 다시 실행한다. 등록을 해제하려면 다음을
사용한다.

```shell
fish /path/to/dotfiles/launchagents/teardown.fish
```

로그는 `/tmp/dev.spearkkk.sketchybar.media-daemon.log` 및
`/tmp/dev.spearkkk.sketchybar.calendar-daemon.log`에 기록된다. 오류 로그는 같은
파일명에 `.err.log` 접미사가 붙는다.

Pomodoro 타이머는 다음 명령으로 제어한다.

```shell
pomo start
pomo break
pomo stop
```

## 선택 작업

Fish를 로그인 셸로 사용하려면 직접 변경한다.

```shell
chsh -s "$(command -v fish)"
```

창 드래그와 Dock 자동 숨김 설정을 적용하려면 다음을 실행한다.

```shell
bash /path/to/dotfiles/macos-defaults.sh
```

이 스크립트는 AeroSpace의 다중 모니터 안정성을 위해 **Displays have separate
Spaces**를 끈다. 모든 디스플레이가 하나의 macOS Space를 공유하게 되며, 설정을
적용한 뒤에는 반드시 로그아웃 후 다시 로그인해야 한다. 이는 여러 모니터에서
다른 창이 잘못 포커스되는 [AeroSpace #101](https://github.com/nikitabobko/AeroSpace/issues/101)의
우회책이다.

SketchyBar 설정을 다시 읽으려면 다음을 실행한다.

```shell
sketchybar --reload
```

## Alfred Workflows

Alfred workflow 원본 디렉터리는 캐시와 로컬 상태를 포함하므로 Git에서 무시한다.
복원할 workflow만 검토한 뒤 `alfred/workflows/`에 `.alfredworkflow` export 파일로
추적한다. export 및 가져오기 절차는 [alfred/workflows/README.md](alfred/workflows/README.md)를
따른다.
