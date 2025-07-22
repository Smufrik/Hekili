@echo off
for %%f in (*.lua) do (
    echo Checking %%f
    "c:\Program Files (x86)\Lua\5.1\luac.exe" -p "%%f"
)
pause
