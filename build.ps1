Param(
  [string]
  [Parameter(Mandatory = $true)]
  $BuildVersion
)


#
# Get endpoints-collation-service from SAMI-git.
#
function ZipFolder($sourcefolder, $zipfile) {
	
	# Check that the source folder exists.
	If (!(Test-Path $sourcefolder)) {
		Write-Host "[E] The output folder '$sourcefolder' was not found."
		Exit 1
	}
	Write-Host "[i] zipping file '$sourcefolder' to '$zipfile'..."
	[System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
	[System.IO.Compression.ZipFile]::CreateFromDirectory($sourcefolder, $zipFile)
}
Try {
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host ""
Write-Host "==> GRAB endpoints-collation-service"
Write-Host ("=" * 80)
Write-Host ""

if (Test-Path '.\endpoints-collation-service') {
	Write-Host "==> Updating existing endpoints-collation-service..."
	Push-Location '.\endpoints-collation-service'
	& git pull
	Pop-Location
} else {
	Write-Host "==> Getting new endpoints-collation-service..."
	& git clone https://git.sami.int.thomsonreuters.com/production-engineering/endpoints-collation-service
}

$buildDirectory = $PSScriptRoot +"/Build"
$zipDirectory = $PSScriptRoot +"/ZipFiles"

if (Test-Path $buildDirectory) {
	Remove-Item -Path $buildDirectory -Force -Recurse
}
if (Test-Path $zipDirectory) {
	Remove-Item -Path $zipDirectory -Force -Recurse
}
	New-Item -ItemType directory -Path $buildDirectory
	New-Item -ItemType directory -Path $zipDirectory

$sourcefolder = $PSScriptRoot    + '\endpoints-collation-service'
$deploymentYamlpath = $PSScriptRoot    + '\deployment.yaml'


$ExcludeExtentions = ".git", ".gitignore" 
Get-ChildItem $sourcefolder -Recurse -Exclude $ExcludeExtentions | Copy-Item -Destination $buildDirectory 
Copy-Item  $deploymentYamlpath $buildDirectory -Force

$filename = 'Barossa-EndpointsCollationService.1.0.'+ $BuildVersion +'.0.zip'
$zipfilepath= $zipDirectory + "\" + $filename;

ZipFolder $buildDirectory  $zipfilepath
} Catch {
 Write-Host "[e] FAILED: $_"
 $exitCode = 1

}
