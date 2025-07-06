#!/bin/sh

DATE=$(TZ=Asia/Seoul date "+%Y-%m-%d")

sketchybar --set "${NAME}" icon=" " label="$DATE"