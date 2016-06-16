$path = Join-Path $(Split-Path -parent $MyInvocation.MyCommand.Definition) 'ctest.ps1'

Install-ChocolateyPowershellCommand -PackageName 'apt-cyg' -PSFileFullPath $path