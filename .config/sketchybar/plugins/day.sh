#!/bin/sh

KO_DAY=$(LC_TIME=ko_KR.UTF-8 TZ=Asia/Seoul date "+%a")
IT_DAY=$(LC_TIME=it_IT.UTF-8 TZ=Asia/Seoul date "+%A")

sketchybar --set "$NAME" label="$IT_DAY($KO_DAY)"