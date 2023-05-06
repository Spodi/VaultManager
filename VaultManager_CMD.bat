:: This is a wrapper to start the PowerShell script in the
:: same directory with the same name automatically.
:: PowerShell is a bit paranoid about starting scripts otherwise.
:: This also takes care of things if called from a 32-bit app.
@echo off
call VaultManager.bat -NoGUI
)
EXIT /b