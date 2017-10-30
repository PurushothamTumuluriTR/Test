Param(
  [string]
  [Parameter(Mandatory = $true)]
  $BuildVersion
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

Write-Host "SOFTWARE SETUP"
Write-Host "[i] Removing old infrastructure-scripts..."
Remove-Item -Force -Path infrastructure-scripts -ErrorAction Ignore -Recurse

Write-Host "[i] Grabbing infrastructure-scripts..."
git clone --depth=1 https://git.sami.int.thomsonreuters.com/production-engineering/infrastructure-scripts.git

Import-Module ".\infrastructure-scripts\private\powershell\Aws.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Logging.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Http.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\AmiBaker.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\Jenkins.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\InfrastructureConfiguration.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\ConvertPEMToPPK.psm1" -Force
Import-Module ".\infrastructure-scripts\public\powershell\ManageSshTunnel.psm1" -Force

#############################################################
#
# BEGIN CONFIGURATION
#

$region                 = Get-CI-Region
$prefix                 = Get-CI-Prefix

$infrastructureBucket   = Get-InfrastructureBucket

$bastionAddress         = Get-CIBastionAddress
$bastionTunnelSshKey    = Get-Bastion-Tunnel-SSh-Key
$bastionTunnelSshUser   = Get-Bastion-Tunnel-SSH-User

$infrabootBucket        = Get-Infra-Boot-Bucket

$serviceBakingInstanceProfile = Get-ServiceAMIIAMInstanceProfile $prefix

$buildsBuckets          = Get-ServiceBuildsBucket

$bakerServiceAddress    = Get-CIAMIBakerAddress
$bakerServicePort       = "8080"

$bakeTimeout            = ( New-Timespan -Minutes 60 )

$localBakerTunnelPort   = 9113

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

$awsAccessKey                 = Get-EnvironmentVariableOrFail "AWS_ACCESS_KEY_ID"                    " [e] FAIL: AWS_ACCESS_KEY_ID environment variable is not set."
$awsSecretAccessKey           = Get-EnvironmentVariableOrFail "AWS_SECRET_ACCESS_KEY"             " [e] FAIL: AWS_SECRET_ACCESS_KEY environment variable is not set."
$bastionTunnelSshKeyPasshrase = Get-EnvironmentVariableOrFail "BASTION_TUNNEL_SSH_KEY_PASSPHRASE" " [e] FAIL: BASTION_TUNNEL_SSH_KEY_PASSPHRASE environment variable is not set."

Write-Host "[i] Setting AWS credentials..."
Initialize-AWSDefaults -Region $region -AccessKey $awsAccessKey -SecretKey $awsSecretAccessKey
Write-Host "[i] ...set."


Try {


  Write-Host "[i] Using following AWS Access credentials..."
  Write-Host "[i] AWS_ACCESS_KEY_ID ="  $(Mask-Key  $awsAccessKey)
  Write-Host "[i] AWS_SECRET_ACCESS_KEY ="  $(Mask-Key  $awsSecretAccessKey)

  # Get latest version of linux node base ami
  $sourceAMI =  Get-AMIID -JobName     'Barossa-BakeAMI-LinuxNodeJS' `
                          -ServiceName 'linux-node-base' `
                          -Region      $region


 $extraArgs = @{
            instance_profile = $serviceBakingInstanceProfile;
            service_builds_bucket = $buildsBuckets;
      }

  Invoke-Bake -InfrabootBucket            $infrabootBucket `
              -BastionAddress             $bastionAddress `
              -BastionTunnelUsername      $bastionTunnelSshUser `
              -BastionTunnelKey           $bastionTunnelSshKey `
              -BastionTunnelKeyPassphrase $bastionTunnelSshKeyPasshrase `
              -PackerServiceAddress       $bakerServiceAddress `
              -PackerServicePort          $bakerServicePort `
              -Files                      $files `
              -SourceAMI                  $sourceAMI `
              -BakeAMIVersion             $BuildVersion `
              -Timeout                    $bakeTimeout `
              -ExtraArgs                  $extraArgs `
              -TunnelLocalPort            $localBakerTunnelPort `

} Catch {

  Write-Host "[e] FAILED: $_"

  Exit 2

}
