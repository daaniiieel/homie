#!/bin/bash
exec &>> capture-log.txt
echo "Running cron-job foo at $(date)"
./homie.exe
