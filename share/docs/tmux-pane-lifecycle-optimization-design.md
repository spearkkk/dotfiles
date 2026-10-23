# tmux Pane Lifecycle Optimization Design

## 목적

Tilish와 pane attention 연동을 유지하면서 pane/window 전환의 공통 경로에서는 불필요한 shell 실행, 상태 재계산, client refresh가 발생하지 않게 한다. Pane 종료 시에는 실제로 변경된 window만 layout과 attention 상태를 보정하며 다른 플러그인의 hook을 보존한다.

## 확인된 문제

1. `unset_attention_state`는 option이 없어도 tmux가 성공을 반환하기 때문에 모든 acknowledge를 상태 변경으로 취급한다.
2. `after-select-pane`과 `after-resize-pane`이 attention 유무와 관계없이 helper를 실행한다.
3. `set-hook -gu after-kill-pane`은 이 설정이 소유하지 않은 hook까지 삭제한다.
4. target 없는 `select-layout`은 비활성 window pane의 자연 종료 시 활성 window를 재배치한다.
5. pane 하나가 종료되어도 `reconcile-all`이 모든 pane과 window를 다시 검사한다.
6. Tilish의 `M-Q` 종료 binding과 `after-kill-pane`이 layout을 중복 계산한다.

## 설계

### 1. Attention no-op fast path

초기 pane snapshot에 `@attention_state`를 함께 저장한다. 상태가 없는 pane에는 unset을 호출하지 않으며, 실제 변경이 있을 때만 window aggregate와 client status를 갱신한다. 선택/focus/resize hook도 현재 window에 aggregate attention 상태가 있을 때만 helper를 시작한다. `select-pane`은 zoom을 해제한 뒤 hook을 실행하므로 zoom flag로 조건화하지 않는다. `after-select-pane`은 aggregate attention 상태가 있을 때만 실행한다.

### 2. Hook 소유권과 layout target

전체 `after-kill-pane` hook을 초기화하지 않는다. 이 설정 전용 indexed hook을 사용한다. Tilish의 `pane-exited[0]`은 `#{hook_window}`를 사용하도록 교체하고, attention reconciliation도 같은 window ID를 전달한다. Tilish의 `M-Q`는 `kill-pane`만 실행하도록 덮어써서 layout 계산은 lifecycle hook 한 곳에서 담당한다.

기존 실행 중인 tmux server에 남아 있는 구버전 `after-kill-pane[0]`, `[1]`은 설정에 영구적인 전역 초기화 코드를 남기지 않고 설치 시 한 번만 제거한다.

### 3. 변경 window 중심 reconciliation

controller에 `reconcile-window <window-id>` operation을 추가한다. 이 operation은 해당 window의 pane만 title/state reconciliation하고 그 window aggregate만 동기화한다. `pane-exited`와 일반적인 interactive `kill-pane`은 이를 사용한다. Source/destination 양쪽 식별이 필요한 `pane-moved`는 안전성을 위해 기존 `reconcile-all`을 유지한다.

### 4. tmux 제약

`after-kill-pane` command hook은 명시적인 `tmux kill-pane -t <inactive-pane>`의 원래 target 정보를 제공하지 않는다. 따라서 외부에서 비활성 pane을 직접 지정하는 명령은 완전하게 target 보정할 수 없다. 일반 키 binding으로 현재 pane을 종료하는 경로와 `pane-exited` 자연 종료 경로를 지원 범위로 한다.

## 검증 기준

- attention이 없는 선택/focus hook은 controller process를 시작하지 않는다.
- attention option이 없는 pane을 acknowledge해도 option mutation, aggregate query, client refresh가 없다.
- 다른 indexed `after-kill-pane` hook이 유지된다.
- 비활성 window pane의 자연 종료는 해당 window만 layout/reconcile한다.
- Tilish `M-Q`에서 layout 계산은 한 번만 수행된다.
- pane 종료 reconciliation은 다른 window pane title을 조회하지 않는다.
- 기존 attention waiting/done 색상 및 marker 테스트가 유지된다.

## 활성 server 적용

브랜치 검증은 격리 tmux server에서 수행한다. Main 병합 후 실행 중인 server에는 구버전이 소유했던 `after-kill-pane[0]`, `[1]`만 한 번 제거하고 설정을 source한다. 저장된 설정은 전체 hook 초기화를 포함하지 않는다.
