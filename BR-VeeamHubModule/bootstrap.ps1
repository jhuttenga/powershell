﻿$baseurl = "https://raw.githubusercontent.com/tdewin/powershell"
$versionurl = "http://dewin.me/veeamhubmodule/version.json"

$installversion = $null
$installmode = $null


$veeamhubmodulename = "VeeamHubModule"

clear-host
write-host "Welcome to the VeeamHub Module Bootstrap Installer"
write-host "##################################################"

$allowfire = $false
write-host @"
Copyright (c) 2018 VeeamHub

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
"@
write-host ""
write-host "Before we continue, please take notice that this module is released under MIT License"
write-host "Basically, this module is released in an opensource module, but we do not take any responsibility in any case"
write-host "Do you agree to this before installing?"
$acceptcheck = read-host "Write yes to confirm "
if ($acceptcheck.ToLower().Trim() -eq "yes") {
    $allowfire = $true
} else {
    write-error "You didn't agree, refusing to continue"
}


function Install-VeeamHubWebFile {
    param($url,$dest)
    
    if ($url -ne $null -and $dest -ne $null) {
        $fdest = (Join-Path $dest -ChildPath (Split-Path $url -Leaf))
        write-host "Downloading $fdest"
        Invoke-WebRequest -Uri $url -OutFile $fdest
    }
}

if ($allowfire) {
    write-host "Fetching version"
    $r = Invoke-WebRequest $versionurl
    if ($r.StatusCode -eq 200) {
        $versions = $r.Content | ConvertFrom-Json
        if ($versions -ne $null -and $versions.Stable -ne $null) {
            
            #Ask for version
            while($installversion -eq $null) {
                $answerversion = (read-host "Which version do you want to install - stable (default), latest, <version>, list").ToLower().trim()
                if ($answerversion -eq "") {
                    $installversion = $versions.stable
                } elseif ($answerversion -eq "stable") {
                    $installversion = $versions.stable
                } elseif ($answerversion -eq "latest") {
                    $installversion = $versions.latest
                } elseif ($answerversion -match "^([0-9]+\.?)+$") {
                    $installversion = $versions.all | ? { $_.version -eq $answerversion }
                } elseif ($answerversion -eq "list") {
                    $versions.all | % { write-host ("{0:6} - {1}" -f $_.version,$_.description )}
                }
            }
            write-host ("Installing {0:6} - {1}" -f $installversion.version,$installversion.description )

            while($installmode -eq $null) {
                $answermode = (read-host "Do you want to install for this user, or for all users - user (default), all (need to be admin)").ToLower().Trim()
                if ($answermode -in "user","all") {
                    $installmode = $answermode
                } elseif($answermode -eq "") {
                    $installmode = "user"
                }
            }
            write-host ("Installing for {0}" -f $installmode)

            $pspaths = $env:PSModulePath -split ";" 
            $installbase = $null
            

            if ($installmode -eq "all") {
                $installbase = $pspaths | ? { $_ -match  $env:SystemRoot.Replace("\","\\") }
            } elseif ($installmode -eq "user") {
                $installbase = $pspaths | ? { $_ -match  $env:USERPROFILE.Replace("\","\\") }
            }

            if ($installbase -ne $null -and $installbase.Trim() -ne "") {
                $installbase = (join-path $installbase -ChildPath $veeamhubmodulename)

                if( -not (Test-Path $installbase)) {
                    New-Item -Path $installbase -ItemType  Directory -ErrorAction SilentlyContinue | out-null
                }

                if( Test-Path $installbase ) {
                    write-host "Installing in $installbase"
                    $alreadyinstalled = @(Get-childItem $installbase).count
                    $canoverwrite = $false
                    if ($alreadyinstalled -gt 0) {
                        $answeroverwrite = (read-host "Seems there is already a version installed, do you want to overwrite? - yes/no").ToLower().Trim()
                        if ($answeroverwrite -eq "yes") {
                            $canoverwrite = $true
                        } else {
                            write-error "You answered negative to overwriting the current module, stopping"
                        }
                    } else {
                        $canoverwrite = $true
                    }
                    if($canoverwrite) {
                        Install-VeeamHubWebFile -url ($installversion.psd -replace "baseurl:/","$baseurl") -dest $installbase
                        Install-VeeamHubWebFile -url ($installversion.psm -replace "baseurl:/","$baseurl") -dest $installbase

                        Import-Module "$veeamhubmodulename" -ErrorAction SilentlyContinue
                        if ((Get-Module "$veeamhubmodulename") -ne $null) {
                            try { 
                                $vhv = Invoke-Expression "Get-VeeamHubVersion"
                                write-host "Installed and loaded $vhv"
                                write-host "Next time, please use 'import-module $veeamhubmodulename' to load the module"
                            } catch { 
                                write-error "Could not run Get-VeeamHubVersion"
                            }
                        } else {
                            Write-Error "Something must have gone wrong because I was not able to load the module, please validate $installbase"
                        } 

                    }
                } else {
                    write-error "$installbase could not be created, make sure you have access"
                }

            } else {
                write-error "Could not find path"
            }

        } else {
            Write-Error "Found json version file but it seems corrupted"
        }
    } else {
        Write-Error "Could not find module version page"
    }
}