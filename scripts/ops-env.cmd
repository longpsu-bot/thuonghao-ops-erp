@echo off
set "PATH=C:\Program Files\nodejs;C:\Users\hp\AppData\Roaming\npm;%LOCALAPPDATA%\pnpm;%PATH%"
echo OPS Windows toolchain PATH bootstrap
where node
where pnpm
node -v
pnpm -v
