param (
    [string] $Path = './',
    [switch] $Run,
    [Switch] $Continue
)

function Get-Files($path = $pwd) 
{ 
    foreach ($item in Get-ChildItem $path)
    {

        if (Test-Path $item.FullName -PathType Container) 
        {
            $item
            Get-Files -path $item.FullName
        } 
        else 
        { 
            $item
        }
    } 
}

function Resolve-ExitCode ($infoDict, $exitCode) {

}

function Start-PackTest ($packagePath) {
    Write-Host ''
    Write-Host 'starting packing test' -ForegroundColor Magenta

    # get current location
    $location = Get-Location

    # go to package dir
    Set-Location $packagePath

    # run command
    Start-Process -FilePath 'choco.exe' -ArgumentList 'pack' -NoNewWindow -Wait -ErrorAction Stop -PassThru

    # see if command is successful 
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'choco pack exit normally with exit code 0' -ForegroundColor Magenta
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Warning "choco pack fail with exit code $LASTEXITCODE"
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }

    # go back to starting location
    Set-Location $location
}

function Start-InstallTest ($packagePath, $packageName) {
    Write-Host ''
    Write-Host 'starting install test' -ForegroundColor Magenta

    # get current location
    $location = Get-Location

    # go to package dir
    Set-Location $packagePath

    # run command
    Start-Process -FilePath 'choco.exe' -ArgumentList "install $packageName -fdv -s $pwd" -NoNewWindow -Wait -ErrorAction Stop -PassThru

    # see if command is successful 
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'choco pack exit normally with exit code 0' -ForegroundColor Magenta
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Warning "choco pack fail with exit code $LASTEXITCODE"
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }

    # go back to starting location
    Set-Location $location
}

function Start-UninstallTest ($packagePath, $packageName) {
    Write-Host ''
    Write-Host 'starting uninstall test' -ForegroundColor Magenta

    # go to package dir
    Set-Location $packagePath

    # run command
    Start-Process -FilePath 'choco.exe' -ArgumentList "uninstall $packageName -debug" -NoNewWindow -Wait -ErrorAction Stop -PassThru

    # see if command is successful 
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'choco pack exit normally with exit code 0' -ForegroundColor Magenta
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Warning "choco pack fail with exit code $LASTEXITCODE"
        $exitOption = Read-Host 'press q to quit, press Enter to ignore the error and continue'
        $exitOption
    }

}

function Start-Test ($path) {

    Write-Host ''
    Write-Host 'indexing the directory' -ForegroundColor Green
    Write-Host 'this can take super long time if you are running in huge dir' -ForegroundColor Magenta
    Write-Host 'so Please do not start this script in a huge dir' -ForegroundColor Magenta

    $files = Get-Files -path $PWD

    $nuspecFiles = $files| where {$_.name -match '.*\.nuspec'}

    Write-Host ''
    Write-Host 'here is all the nuspec file I have found' -ForegroundColor Magenta
    Write-Host $nuspecFiles -ForegroundColor Magenta
    Write-Host 'we will start testing with all these files'
    Read-Host 'Press Enter to Continue'

    Write-Host ''
    Write-Host 'initializing test' -ForegroundColor Magenta
    $default = @{'packed' = $false; 'install'= $false; 'uninstall'=$false}
    $infoDict = @{}
    foreach ($file in $nuspecFiles) {
        $infoDict.Add($file.FullName, $default)
    }
    Write-Host 'infoDict is initiated' -ForegroundColor Magenta

    foreach ($package in $infoDict.GetEnumerator()) {
        # get basic info
        $packagePath = [System.IO.Path]::GetDirectoryName($package.name)
        $packageName = [System.IO.Path]::GetFileNameWithoutExtension($package.name)

        Write-Host ''
        Write-Host 'starting to test package with the path' -ForegroundColor Magenta
        Write-Host $packageName -ForegroundColor Magenta

        # starts packing test
        $exitOption = Start-PackTest -packagePath $packagePath
        # handle exit option
        if ($exitOption -eq 'q') {
            # save infoDict and exit
            $infoDict | ConvertTo-Json > ./ctest_profile
            Write-Host 'info saved, you can run `ctest -command continue` to restart the test' -ForgroundColor Green
            exit
        }
        else {
            # update infoDict
            $package.Value.packed = $true
            $infoDict.Set_Item($package.Name, $package.Value)
        }

        # start installing package
        $exitOption = Start-InstallTest -packagePath $packagePath -packageName $packageName
        # handle exit option
        if ($exitOption -eq 'q') {
            # save infoDict and exit
            $infoDict | ConvertTo-Json > ./ctest_profile
            Write-Host 'info saved, you can run `ctest -command continue` to restart the test' -ForgroundColor Green
            exit
        }
        else {
            # update infoDict
            $package.Value.install = $true
            $infoDict.Set_Item($package.Name, $package.Value)
        }

        # start uninstall test
        $exitOption = Start-UninstallTest -packageName $packageName
        # handle exit option
        if ($exitOption -eq 'q') {
            # save infoDict and exit
            $infoDict | ConvertTo-Json > ./ctest_profile
            Write-Host 'info saved, you can run `ctest -command continue` to restart the test' -ForgroundColor Green
            exit
        }
        else {
            # update infoDict
            $package.Value.uninstall = $true
            $infoDict.Set_Item($package.Name, $package.Value)
        }
    }

    Write-Host 'Test finished' -ForegroundColor Magenta
}

function Resume-Test ($path) {
    

}

function Initialize-CTest ($Path) {

    Set-Location $Path

    if(Test-Path ./ctest_profile) {
        Write-Host 'found the old test profile' -ForegroundColor Magenta
        Write-Host 'Do you want to continue the old test?' -ForegroundColor Magenta
        $option = Read-Host 'enter [Y]es for continue else we will start a new test'
        if ($option.ToLower -match 'y.*') {
            Write-Host 'continue the old test' -ForgroundColor Magenta
            Resume-Test -path $path
        }
        else {
            Write-Host 'removing the old test profile' -ForegroundColor Magenta
            Remove-Item ./ctest_profile
            Write-Host 'starting a new test' -ForgroundColor Magenta
            Start-Test -path $path
        }
    }
    else {
        Write-Host 'cannot find the old test profile' -ForegroundColor Magenta
        Write-Host 'starting a new test' -ForegroundColor Magenta
        Start-Test -path $path
    }

}


if ($Run) {
    Start-Test -path $Path
}
elseif ($Continue) {
    Resume-Test -path $Path
}
else {
    Initialize-CTest -Path $Path
}


