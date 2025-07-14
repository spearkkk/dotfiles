function git
    set -l repo_required "status" "log" "lg" "diff" "branch" "remote" "checkout"
    set -l subcommand ""
    set -l raw_mode 0

    if test (count $argv) -gt 0
        set subcommand $argv[1]

        # --raw 옵션이 포함되면 후킹 로직 생략
        for arg in $argv
            if test $arg = "--raw"
                set raw_mode 1
                break
            end
        end
    end

    # --raw 플래그 우회 처리
    if test $raw_mode -eq 1
        set -l cleaned_args
        for arg in $argv
            if test $arg != "--raw"
                set cleaned_args $cleaned_args $arg
            end
        end
        command git $cleaned_args
        return
    end

    # 저장소 필요한 명령어 체크
    if contains $subcommand $repo_required
        if not command git rev-parse --is-inside-work-tree >/dev/null 2>&1
            echo -e "\033[31m❌  이 디렉토리는 Git 저장소가 아닙니다.\033[0m"
            return 1
        end
    end

    # 깔끔한 로그 출력
    if test $subcommand = "log"
        command git log --graph \
            --pretty=format:'%C(auto)%h%Creset %<(50,trunc)%s %C(blue)%<(12,trunc)%ad%Creset %C(magenta)%<(12,trunc)%an%Creset %C(yellow)%d%Creset' \
            --date=short \
            --abbrev-commit \
            --decorate \
            --all
        return 0
    end

    # 그 외는 기본 git 실행
    command git $argv
end