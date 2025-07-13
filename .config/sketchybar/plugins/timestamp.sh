#!/bin/bash

TIMESTAMP=$(LC_TIME=it_IT.UTF-8 TZ=Asia/Seoul date "+%Y-%m-%d(%a)  %H:%M:%S")

sketchybar --set "${NAME}" label="$TIMESTAMP"