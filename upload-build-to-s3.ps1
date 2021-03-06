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

Write-Host "Preparing to upload the build to S3..."
Write-Host " * Setting AWS credentials..."
$awsAccessKey                 = Get-EnvironmentVariableOrFail "AWS_ACCESS_KEY_ID"                    " [e] FAIL: AWS_ACCESS_KEY_ID environment variable is not set."
$awsSecretAccessKey           = Get-EnvironmentVariableOrFail "AWS_SECRET_ACCESS_KEY"             " [e] FAIL: AWS_SECRET_ACCESS_KEY environment variable is not set."
Initialize-AWSDefaults -AccessKey $awsAccessKey -SecretKey $awsSecretAccessKey
Write-Host "[i] ...set."

Import-Module ".\infrastructure-scripts\private\powershell\Aws.psm1" -Force
Import-Module ".\infrastructure-scripts\private\powershell\InfrastructureConfiguration.psm1" -Force

Write-Host "[i] Using follwing AWS credentials..."
Write-Host "[i] AWS_ACCESS_KEY_ID ="  $(Mask-Key  $awsAccessKey)
Write-Host "[i] AWS_SECRET_ACCESS_KEY ="  $(Mask-Key  $awsSecretAccessKey)


$service_bucket = Get-ServiceBuildsBucket

Write-Host " * Uploading..."
Write-S3Object -BucketName $service_bucket -SearchPattern Barossa-EndpointsCollationService.*.zip -KeyPrefix endpoints-collation-service -Folder .
Write-S3Object -BucketName $service_bucket -SearchPattern endpoints-collation-service.*.zip -KeyPrefix endpoints-collation-service -Folder .
Write-Host "Done."