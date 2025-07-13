#!/usr/bin/env fish

function _change_osx_setting
    # 빠른 창 애니메이션
    defaults write -g NSWindowResizeTime -float 0.001
    # 앱 실행 애니메이션 비활성화
    defaults write com.apple.dock launchanim -bool false
    # 창 최소화/최대화 애니메이션 끄기
    defaults write -g NSAutomaticWindowAnimationsEnabled -bool false
    # Finder 창 애니메이션 끄기
    defaults write com.apple.finder DisableAllAnimations -bool true
    # 툴팁 딜레이 제거
    defaults write -g NSInitialToolTipDelay -integer 0

    # 확장자 항상 보기
    defaults write NSGlobalDomain AppleShowAllExtensions -bool true
    # Finder: 경로 막대 보기
    defaults write com.apple.finder ShowPathbar -bool true
    # Finder: 상태 막대 보기
    defaults write com.apple.finder ShowStatusBar -bool true
    # 기본 보기 모드: 리스트
    defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
    # 숨김 파일 보기
    defaults write com.apple.finder AppleShowAllFiles -bool true

    # 자동 숨김 시 딜레이 제거
    defaults write com.apple.dock autohide-delay -float 0
    defaults write com.apple.dock autohide-time-modifier -float 0.2
    # Dock 자동 숨김 켜기
    defaults write com.apple.dock autohide -bool true
    # 최근 사용한 앱 안 보이게
    defaults write com.apple.dock show-recents -bool false

    # 키 반복 최대화
    defaults write -g KeyRepeat -int 1
    defaults write -g InitialKeyRepeat -int 15

    # 자동 맞춤법 끄기
    defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false
    # 자동 대문자 끄기
    defaults write -g NSAutomaticCapitalizationEnabled -bool false
    # 스마트 따옴표 끄기
    defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

    # 크래시 리포트 비활성화
    defaults write com.apple.CrashReporter DialogType none
end