Param(
  [string]
  [Parameter(Mandatory = $true)]
  $BuildVersion
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Import-Module ".\infrastructure-scripts\private\powershell\Aws.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Logging.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Http.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\AmiBaker.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Jenkins.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\InfrastructureConfiguration.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\ConvertPEMToPPK.psm1" -Force
Import-Module ".\infrastructure-scripts\public\powershell\ManageSshTunnel.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\CommitTagging.psm1" -Force

Setup-CommitTaggingTool

Initialize-ManifestFromFile -Filename ".\statutory-reporting\manifest.json"

#############################################################
#
# BEGIN CONFIGURATION
#
$infraEnvironmentId     = Get-CI-InfraStructureEnvironmentId
$region                 = Get-CI-Region
$prefix                 = Get-CI-Prefix
$kmsKeyId = Get-EC2EncrytionKeyId -InfrastructureEnvironmentId $infraEnvironmentId -RegionId $region

$serviceBakingInstanceProfile = Get-ServiceAMIIAMInstanceProfile $prefix

$buildsBuckets          = Get-ServiceBuildsBucket

$bakerServiceAddress    = Get-CIAMIBakerAddress
$bakerServicePort       = "8080"

$bakeTimeout            = ( New-Timespan -Minutes 60 )

$files = @{
  "packer.json"         = "packer.json";
}

#
# END CONFIGURATION
#
#############################################################

#############################################################
#
# BEGIN FUNCTIONS
#

Function Get-EnvironmentVariableOrFail (
  [string]
  [Parameter(Mandatory = $true)]
  $Var,

  [string]
  [Parameter(Mandatory = $true)]
  $Message
)
{
  Push-Location env:
  $tempVar = Get-ChildItem $Var -ErrorAction SilentlyContinue
  Pop-Location

  If( -Not( $tempVar ) -Or -Not( $tempVar.Value ) ) {
    Write-Host $Message
    Exit 1
  }

  $tempVar.Value
}

#
# END FUNCTIONS
#
#############################################################

Write-Host "[i] Starting pre-flight checks..."

$awsAccessKey       = Get-EnvironmentVariableOrFail "AWS_ACCESS_KEY_ID"     " [e] FAIL: AWS_ACCESS_KEY_ID environment variable is not set."
$awsSecretAccessKey = Get-EnvironmentVariableOrFail "AWS_SECRET_ACCESS_KEY" " [e] FAIL: AWS_SECRET_ACCESS_KEY environment variable is not set."

Write-Host "[i] Setting AWS credentials..."
Initialize-AWSDefaults -Region $region -AccessKey $awsAccessKey -SecretKey $awsSecretAccessKey
Write-Host "[i] ...set."

Try {

  Write-Host "[i] Using following AWS Access credentials..."
  Write-Host "[i] AWS_ACCESS_KEY_ID =" $(Mask-Key $awsAccessKey)
  Write-Host "[i] AWS_SECRET_ACCESS_KEY =" $(Mask-Key $awsSecretAccessKey)

  # Get latest version of linux node base ami

  $commit = Get-Commit -service 'linux-node-base'  `
                       -tags 'built=true;class=service'

  $sourceAMI = Get-AMIID -JobName     'Barossa-BakeAMI-LinuxNodeJS' `
                         -ServiceName 'linux-node-base' `
                         -Region      $region `
                         -Commit      $commit

  $extraArgs = @{
    instance_profile = $serviceBakingInstanceProfile;
    service_builds_bucket = $buildsBuckets;
    kms_key_id = $kmsKeyId;
  }

  Invoke-Bake -PackerServiceAddress       $bakerServiceAddress `
              -PackerServicePort          $bakerServicePort `
              -Files                      $files `
              -SourceAMI                  $sourceAMI `
              -BakeAMIVersion             $BuildVersion `
              -Timeout                    $bakeTimeout `
              -ExtraArgs                  $extraArgs

} Catch {

  Write-Host "[e] FAILED: $_"

  Exit 2

}
