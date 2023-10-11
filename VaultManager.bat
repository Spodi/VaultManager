::[Bat To Exe Converter]
::
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivcOC1VIcBXL
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivcFDxRWMBuoYW8=
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivc6DQ5Uaj+qYA4zrHwMtXfl
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivc6DQ5Uaj+qYA4zrHwMpnfUVw==
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivc6DQ5Uaj+qYA4zrHwMpneIZqc=
::fBE1pAF6MU+EWHreyHcjLQlHcDeSM2+zOoYf+uHr+/m7gVQfUfByVIrc07uAHNYS/0nwWJcj131fivc6DQ5Uaj+qYA4zrHwMrmmJVw==
::YAwzoRdxOk+EWAjk
::fBw5plQjdCyDJGyX8VAjFChEQwCLAFi5FLwM/PvHzPOFp19QeOc4cYDV5oKPNewHx0TqdJEoxEZTm8QCQhJbcXI=
::YAwzuBVtJxjWCl3EqQJgSA==
::ZR4luwNxJguZRRnk
::Yhs/ulQjdF+5
::cxAkpRVqdFKZSDk=
::cBs/ulQjdF65
::ZR41oxFsdFKZSDk=
::eBoioBt6dFKZSDk=
::cRo6pxp7LAbNWATEpSI=
::egkzugNsPRvcWATEpCI=
::dAsiuh18IRvcCxnZtBJQ
::cRYluBh/LU+EWAnk
::YxY4rhs+aU+JeA==
::cxY6rQJ7JhzQF1fEqQJQ
::ZQ05rAF9IBncCkqN+0xwdVs0
::ZQ05rAF9IAHYFVzEqQJQ
::eg0/rx1wNQPfEVWB+kM9LVsJDGQ=
::fBEirQZwNQPfEVWB+kM9LVsJDGQ=
::cRolqwZ3JBvQF1fEqQJQ
::dhA7uBVwLU+EWDk=
::YQ03rBFzNR3SWATElA==
::dhAmsQZ3MwfNWATElA==
::ZQ0/vhVqMQ3MEVWAtB9wSA==
::Zg8zqx1/OA3MEVWAtB9wSA==
::dhA7pRFwIByZRRnk
::Zh4grVQjdCyDJGyX8VAjFChEQwCLAFi5FLwM/PvHzPOFp19QeOc4cYDV5oKPNewHx0TqdJEoxEZZl8YcBRddei6dbxo4vUNDuGWCMtXSthfkKg==
::YB416Ek+ZG8=
::
::
::978f952a14a936cc963da21a135fa983
@echo off
set _NoGUI=0
if /I "%~1" == "-NoGUI" set _NoGUI=1
if /I "%~2" == "-NoGUI" set _NoGUI=1
if /I "%~3" == "-NoGUI" set _NoGUI=1
if /I "%~4" == "-NoGUI" set _NoGUI=1
if /I "%~5" == "-NoGUI" set _NoGUI=1
if /I "%~6" == "-NoGUI" set _NoGUI=1
if /I "%~7" == "-NoGUI" set _NoGUI=1
if /I "%~8" == "-NoGUI" set _NoGUI=1
if /I "%~9" == "-NoGUI" set _NoGUI=1
::echo %~0
::set _remove=%~0
set _arg=%*
::call set arg=%%_arg:"%_remove%"=%%
::call set arg=%%_arg:%_remove%=%%
::echo "%b2eincfilepath%\VaultManager.ps1" %arg%


if %_NoGUI%==1 (
		call %systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoExit -File ".\VaultManager.ps1" %arg%
	) else (
		call %systemroot%\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoLogo -File ".\VaultManager.ps1" %arg%
	)
EXIT /b