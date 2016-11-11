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
if (Test-Path $buildDirectory) {
  Remove-Item $buildDirectory -recurse
}
New-Item -ItemType directory -Path $buildDirectory

$filename = 'Barossa-EndpointsCollationService.1.0.'+ $BuildVersion +'.0.zip'
$zipfilepath= $buildDirectory + "\" + $filename;
$sourcefolder = $PSScriptRoot+'\endpoints-collation-service'
ZipFolder $sourcefolder  $zipfilepath


