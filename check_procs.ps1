Get-CimInstance Win32_Process -Filter "name LIKE 'language_server%'" | Select-Object ProcessId, CreationDate, CommandLine | Format-List
