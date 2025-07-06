#!/bin/sh

DATE=$(LC_TIME=it_IT.UTF-8 TZ=Asia/Seoul date "+%Y-%m-%d(%a)")

sketchybar --set "${NAME}" icon=" " label="$DATE"