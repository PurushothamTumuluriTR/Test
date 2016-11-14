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
  Remove-Item $buildDirectory -recurse
}
if (Test-Path $zipDirectory) {
  Remove-Item $zipDirectory -recurse
}


New-Item -ItemType directory -Path $buildDirectory
New-Item -ItemType directory -Path $zipDirectory

$packageJsonPath    = $PSScriptRoot    + '\endpoints-collation-service\package.json'
$serverJs           = $PSScriptRoot    + '\endpoints-collation-service\server.js'
$startServerScriptPath   = $PSScriptRoot    + '\endpoints-collation-service\startServer.sh'
$deploymentYamlpath = $PSScriptRoot    + '\deployment.yaml'

Copy-Item $packageJsonPath    $buildDirectory
Copy-Item $serverJs           $buildDirectory
Copy-Item $startServerScriptPath           $buildDirectory
Copy-Item $deploymentYamlpath $buildDirectory

$filename = 'Barossa-EndpointsCollationService.1.0.'+ $BuildVersion +'.0.zip'
$zipfilepath= $zipDirectory + "\" + $filename;

ZipFolder $buildDirectory  $zipfilepath

} Catch {

 Write-Host "[e] FAILED: $_"
 $exitCode = 1

}
