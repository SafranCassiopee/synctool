@echo off
echo Compiling syncTool

SET AUTOIT_PATH="C:\Program Files (x86)\AutoIt3\aut2exe\aut2exe.exe"
%AUTOIT_PATH% /in .\syncTool.au3 /console /icon ./sync.ico
echo End of compilation