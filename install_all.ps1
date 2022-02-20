cd installs
Get-ChildItem -Filter *.exe | ForEach {
echo Installing $_.FullName
Start-Process $_.Fullname /quiet -Wait
}
pause
