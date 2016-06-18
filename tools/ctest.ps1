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

function Start-PackTest($packagePath, $packageName) {
    Write-Host ''
    Write-Host 'starting packing test' -ForegroundColor Magenta

    $location = Get-Location
    Set-Location $packagePath

    # run command
    $process = Start-Process -FilePath 'choco.exe' -ArgumentList 'pack' -NoNewWindow -Wait -ErrorAction Stop -PassThru
    $exitCode = $process.ExitCode

    # see if command is successful 
    if ($exitCode -eq 0) {
        Write-Host ''
        Write-Host "choco pack for package $packageName exit normally with exit code 0" -ForegroundColor Green
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Host ''
        Write-Warning "choco pack for package $packageName fail with exit code $exitCode"
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }

    Set-Location $location

}

function Start-InstallTest ($packagePath ,$packageName) {
    Write-Host ''
    Write-Host 'starting install test' -ForegroundColor Magenta

    $location = Get-Location
    Set-Location $packagePath

    # run command
    $process = Start-Process -FilePath 'choco.exe' -ArgumentList "install $packageName -fdv -s $pwd" -NoNewWindow -Wait -ErrorAction Stop -PassThru
    $exitCode = $process.ExitCode

    # see if command is successful 
    if ($exitCode -eq 0) {
        Write-Host ''
        Write-Host "choco install for package $packageName exit normally with exit code 0" -ForegroundColor Green
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Host ''
        Write-Warning "choco install for package $packageName fail with exit code $exitCode"
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }

    # go back to starting location
    Set-Location $location
}

function Start-UninstallTest ($packagePath, $packageName) {
    Write-Host ''
    Write-Host 'starting uninstall test' -ForegroundColor Magenta

    # run command
    $process = Start-Process -FilePath 'choco.exe' -ArgumentList "uninstall $packageName -debug" -NoNewWindow -Wait -ErrorAction Stop -PassThru
    $exitCode = $process.ExitCode

    # see if command is successful 
    if ($exitCode -eq 0) {
        Write-Host ''
        Write-Host "choco uninstall for package $packageName exit normally with exit code 0" -ForegroundColor Green
        $exitOption = Read-Host 'press q to quit, press Enter to continue'
        $exitOption
    }
    else {
        Write-Host ''
        Write-Warning "choco uninstall for package $packageName failed with exit code $exitCode"
        $exitOption = Read-Host 'press q to quit, press Enter to ignore the error and continue'
        $exitOption
    }

}

function Invoke-CTestCore ($infoObject) {
    foreach ($package in $infoObject.psobject.properties) {
        # get basic info
        $packagePath = [System.IO.Path]::GetDirectoryName($package.name)
        $packageName = [System.IO.Path]::GetFileNameWithoutExtension($package.name)

        Write-Host ''
        Write-Host 'starting to test package with the name' -ForegroundColor Green
        Write-Host $packageName -ForegroundColor Green

        # starts packing test
        if ($package.Value.packed) {
            Write-Host 'Package has passed the pack test'
        }
        else {
            $exitOption = Start-PackTest -packagePath $packagePath -packageName $packageName
            # handle exit option
            if ($exitOption -eq 'q') {
                # save infoDict and exit
                $infoObject | ConvertTo-Json > ./ctest_profile
                Write-Host 'info saved, you can run `ctest <path> -continue` to restore the test' -ForgroundColor Green
                return
            }
            else {
                # update infoDict
                $package.Value.packed = $true
            }
        }
        
        # start installing package
        if ($package.Value.install) {
            Write-Host 'Package has passed the install test'
        }
        else {
            $exitOption = Start-InstallTest -packagePath $packagePath -packageName $packageName
            # handle exit option
            if ($exitOption -eq 'q') {
                # save infoDict and exit
                $infoObject | ConvertTo-Json > ./ctest_profile
                Write-Host 'info saved, you can run `ctest <path> -continue` to restore the test' -ForgroundColor Green
                return
            }
            else {
                # update infoDict
                $package.Value.install = $true
            }
        }
        

        # start uninstall test
        if ($package.Value.install) {
            Write-Host 'Package has passed the uninstall test'
        }
        else {
            $exitOption = Start-UninstallTest -packageName $packageName
            # handle exit option
            if ($exitOption -eq 'q') {
                # save infoDict and exit
                $infoObject | ConvertTo-Json > ./ctest_profile
                Write-Host 'info saved, you can run `ctest <path> -continue` to restart the test' -ForgroundColor Green
                return
            }
            else {
                # update infoDict
                $package.Value.uninstall = $true
            }
        }  
    }

    Write-Host 'Test finished' -ForegroundColor Magenta
}

function Start-CTest {

    Write-Host ''
    Write-Host 'indexing the directory' -ForegroundColor Green
    Write-Host 'this can take super long time if you are running in huge dir' -ForegroundColor Magenta
    Write-Host 'so Please do not start this script in a huge dir' -ForegroundColor Magenta

    $files = Get-Files -path $PWD

    $nuspecFiles = $files| where {$_.name -match '.*\.nuspec'}

    Write-Host ''
    Write-Host 'here is all the nuspec file I have found' -ForegroundColor Green
    Write-Host $nuspecFiles -ForegroundColor Magenta
    Write-Host 'we will start testing with all these files'
    Read-Host 'Press Enter to Continue'

    Write-Host ''
    Write-Host 'initializing test' -ForegroundColor Magenta
    $default = @{'packed' = $false; 'install'= $false; 'uninstall'=$false}

    # creating info object
    $infoObject = New-Object -TypeName psobject
    foreach ($file in $nuspecFiles) {
        Add-Member -InputObject $infoObject -MemberType NoteProperty -Name $file.FullName -Value $default
    }
    Write-Host 'infoObject is initiated' -ForegroundColor Magenta

    Invoke-CTestCore $infoObject

    Write-Host 'Test finished' -ForegroundColor Magenta
}

function Resume-CTest {

    # reading the infoDict
    Write-Host 'Reading the old profile'
    $infoObject = Get-Content ./ctest_profile | ConvertFrom-Json
    
    Invoke-CTestCore -infoObject $infoObject

}

function Initialize-ResumedCTest {

    Write-Host 'Trying to find the old Profile'
    if (-Not (Test-Path ./ctest_profile)) {
        Write-Warning 'previous ctest profile not found.' 
        Write-Warning 'Starting a new test'
        Start-CTest
    }
    else {
        Write-Host 'old Profile found'
        Resume-CTest 
    }
}

function Initialize-AutoCTest{

    if(Test-Path ./ctest_profile) {
        Write-Host 'found the old test profile' -ForegroundColor Magenta
        Write-Host 'Do you want to continue the old test?' -ForegroundColor Magenta
        $option = Read-Host 'enter [Y]es for continue else we will start a new test'
        if ($option.ToLower -eq 'yes' -or $option.ToLower() -eq 'y') {
            Write-Host 'continue the old test' -ForgroundColor Magenta
            Resume-CTest
        }
        else {
            Write-Host 'removing the old test profile' -ForegroundColor Magenta
            Remove-Item ./ctest_profile
            Write-Host 'starting a new test' -ForgroundColor Magenta
            Start-CTest
        }
    }
    else {
        Write-Host 'cannot find the old test profile' -ForegroundColor Magenta
        Write-Host 'starting a new test' -ForegroundColor Magenta
        Start-CTest
    }

}

$location = Get-Location

Set-Location $path

if ($Run) {
    Start-CTest
}
elseif ($Continue) {
    Initialize-ResumedCTest
}
else {
    Initialize-AutoCTest
}

Set-Location $location


