Param(
  [string]
  [Parameter(Mandatory = $true)]
  $BuildVersion
)

$exitCode = 0

Try {
  $ErrorActionPreference = "Stop"

  if (Test-Path '.\endpoints-collation-service') {
    Write-Host "[i] Updating existing endpoints-collation-service..."
    Push-Location '.\endpoints-collation-service'
    & git pull
    Pop-Location
  } else {
    Write-Host "[i] Getting new endpoints-collation-service..."
    & git clone https://git.sami.int.thomsonreuters.com/production-engineering/endpoints-collation-service
  }

  # node_modules contains very long paths which PowerShell cannot delete.
  # We'll use rimraf to wipe them out.
  Write-Host "[i] Installing rimraf..."
  npm install rimraf -global

  If( $LASTEXITCODE -ne 0 ) {
    throw 'Failed to install rimraf.'
  }

  if (Test-Path '.\endpoints-collation-service\node_modules') {
    Write-Host "[i] Deleting existing node_modules directory..."
  	rimraf '.\endpoints-collation-service\node_modules'

    If( $LASTEXITCODE -ne 0 ) {
      throw 'Failed to delete existing node_modules directory.'
    }
  }

  if (Test-Path '.\endpoints-collation-service\dist') {
    Write-Host '[i] Deleting existing distribution directory...'
    rimraf '.\endpoints-collation-service\dist'

    If( $LASTEXITCODE -ne 0 ) {
      throw 'Failed to delete existing distribution directory.'
    }
  }

  Write-Host "[i] Installing gulp locally..."
  npm install gulp

  If( $LASTEXITCODE -ne 0 ) {
    throw 'Failed to install gulp locally.'
  }

  Write-Host "[i] Installing Endpoints Collation Service Node.JS modules..."
  cd .\endpoints-collation-service
  npm install

  If( $LASTEXITCODE -ne 0 ) {
    throw 'Failed to install Endpoints Collation Service Node.JS modules.'
  }

  Write-Host "[i] Building Endpoints Collation Service..."
  gulp dist
  cd ..

  If( $LASTEXITCODE -ne 0 ) {
    throw 'Failed to build Endpoints Collation Service.'
  }

  Write-Host '[i] Copying deployment.yaml to distribution...'
  Copy-Item  '.\deployment.yaml' '.\endpoints-collation-service\dist'

  $zip = ".\Barossa-EndpointsCollationService.1.0.$BuildVersion.0.zip"

  if (Test-Path $zip) {
    Write-Host "[i] Deleting existing ZIP..."
  	rimraf $zip

    If( $LASTEXITCODE -ne 0 ) {
      throw 'Failed to delete existing ZIP.'
    }
  }

  Write-Host '[i] Creating ZIP...'
  [System.Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
	[System.IO.Compression.ZipFile]::CreateFromDirectory('.\endpoints-collation-service\dist', $zip)

  Write-Host '[i] Endpoints Collation Service built successfully.'

} Catch {

  Write-Host "[e] FAILED: $_"
  $exitCode = 1

} Finally {

  cd ..
  Exit $exitCode

}
