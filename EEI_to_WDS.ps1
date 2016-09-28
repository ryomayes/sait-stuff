#A script to migrate new EEI images to WDS.

Write-Host 'This script requires 7-Zip to be installed in C:\Program Files and version 8.1 of Windows Deployment Kit
to be installed in C:\Program Files (x86)\Windows Kits\. Press any key to continue.' -ForegroundColor Yellow
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')


$Image_File = Read-Host "Please enter the path to the image file you would like to extract."
$Desktop_Path = "C:\Extracted_EEI"
$MountDir = "C:\MountDir"
$7zip_x64 = "C:\Program Files\7-Zip\7z.exe"
$7zip_x86 = "C:\Program Files (x86)\7-Zip\7z.exe"
do
{
	$version = Read-Host "Please enter the number (7, 8, or 10) of the image operating system."
}
until (($version -eq "7") -or ($version -eq "8") -or ($version -eq "10"))

#if ($version -eq "7")
#{
#	$version = ""
#}
$currDeploy = "Deploy" + $version
$prevDeploy = $currDeploy + "_prev"


#Step 1: Extracting the image to desktop
if (Test-Path $Desktop_Path)
{
	Write-Host "Deleting previous image extraction..." -ForegroundColor Yellow
	Remove-Item $Desktop_Path -Force -Recurse
}

New-Item -ItemType directory -Path $Desktop_Path

if (Test-Path $MountDir)
{
	Write-Host "Deleting previous mount directory..." -ForegroundColor Yellow
	Remove-Item $MountDir -Force -Recurse
}
New-Item -ItemType directory -Path $MountDir

if (-not ((Test-Path $7zip_x64) -or (Test-Path $7zip_x86)))
{
	throw "Error - You appear to not have 7-Zip installed. If 7-Zip is installed,`
	ensure that it is installed to a folder called '7-Zip' in a Program Files`
	directory and is entitled '7z.exe'."
}
	
if (Test-Path $7zip_x64)
{
	Set-Alias sz $7zip_x64
}
else
{
	Set-Alias sz $7zip_x86
}
##Mount WDS with credentials
if (Test-Path P:)
{
	Remove-PSDrive P
}
$username = Read-Host "Please enter your deploy account username."
Write-Host "Mounting WDS with deploy credentials to P drive..." -ForegroundColor Yellow
New-PSDrive -Name P -PSProvider FileSystem -Root \\wds.housing.berkeley.edu\REMINST\MDT -Credential deploy\$username -Persist

##Extracting to desktop path. "x" is 7zip extract and "-o" is the output dir.
Write-Host "Extracting to $Desktop_path. This will take about two hours..." -ForegroundColor Yellow
sz x -y "-o$Desktop_Path" $Image_File

#Step 2: Mounting the image (Room for improvement - assert that this path exists)

Write-Host "Mounting image..." -ForegroundColor Yellow
if (-not (Test-Path "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"))
{
	throw "Error - DISM isn't installed on your computer in file location 'C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\DISM'"
}
Import-Module "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"
$env:Path = "C:\Program Files (x86)\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\DISM"
dism /Mount-Wim /WimFile:"$Desktop_Path\Deploy\Boot\LiteTouchPE_x64.wim" /index:1 /MountDir:$MountDir

#Step 3: Editing bootstrap.ini

Write-Host "Editing bootstrap.ini..." -ForegroundColor Yellow
$file = "$MountDir\Deploy\Scripts\bootstrap.ini"

(Get-Content ($file)) |
	ForEach-Object {
		$_
		if ($_ -eq "`[Default]")
		{
			"DeployRoot=\\wds.housing.berkeley.edu\REMINST\MDT\$currDeploy"
		}
	} | Set-Content $file

#Step 4: Unmounting the image - Is it possible to close applications
# that have the mounted wim open via powershell?

#Write-Host 'Please close all applications (Windows Explorer, Notepad, etc.) that have
#the mounted .wim open and press any key to continue.' -ForegroundColor Yellow
#$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

#Closing all explorer windows and then unmounting the image:

(New-Object -comObject Shell.Application).Windows() | foreach-object {$_.quit()}

Write-Host "Unmounting image..." -ForegroundColor Yellow
dism /unmount-wim /Mountdir:$MountDir /commit

#Step 5: Moving Deploy folder to WDS
#Write-Host 'WARNING -- THIS HAS NOT BEEN FULLY TESTED AND USES REAL FOLDER NAMES. PRESS ANY KEY TO CONTINUE. ' -ForegroundColor Yellow
#$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

#Navigate into WDS
Write-Host "Navigating to WDS..." -ForegroundColor Yellow
P:

##Delete old prev
if (Test-Path $prevDeploy)
{
	Write-Host "Deleting the old backup deploy folder..." -ForegroundColor Yellow
	Remove-Item $prevDeploy -Force -Recurse
}
Write-Host "Marking deploy folder as previous..." -ForegroundColor Yellow
Rename-Item -Path $currDeploy -NewName $prevDeploy

Write-Host "Renaming the new deploy folder..." -ForegroundColor Yellow
$Desktop_Path2 = $Desktop_Path + "\" + "Deploy"
$Desktop_Path3 = $Desktop_Path2 + $version
Rename-Item -Path $Desktop_Path2 -NewName $currDeploy
##Copy new one here.
Write-Host "Copying folder. This will take 50-70 mins..." -ForegroundColor Yellow
Copy-Item $Desktop_Path3 $currDeploy -Recurse
Write-Host "All done!" -ForegroundColor Yellow














