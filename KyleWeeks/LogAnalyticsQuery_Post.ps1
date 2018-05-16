# Get the UMN Azure Module
Install-Module UMN-Azure
Import-Module UMN-Azure

# Azure registered Application info
$tenantID = 'Azure AD Tenant ID'

#Inform the shell to use TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#region Log Analytics
### Log Analytic workspace info, azure ad app info, and resource to be asked for with oAuth tokens.
$workspaceID = 'Log Analytics Workspace ID'
$primaryKey = 'Log Analytics Primary Preshared Key'

$resourceLog = 'https://api.loganalytics.io/'

$accessKeyLog = 'Azure AD Registered APP Key'
$clientIDLog = 'Azure AD Registered APP ID'


# Get an OAuth 2.0 Token from your Azure AD registered App
# Function is from the UMN-Azure module.
$accessToken = Get-AzureOAuthTokenService -tenantID $tenantID -clientid $clientIDLog -accessKey $accessKeyLog -resource $resourceLog

# Query Log Analytics -- 'Get-AzureLogAnalytics' is from the UMN Azure Module
$query = 'Update'
$response = Get-AzureLogAnalytics -workspaceID $workspaceID -accessToken $accessToken -query $query

#Responses
$response.tables.rows

# Column Headers
$response.tables.columns

# Count how many responses
$response.tables.rows.count



#posting to data collector API -- some kind of JSON Data
$Inputs = @{"School"="University of MN";"MMS"="2018";"Location"="Bloomington MN"}

$body = $Inputs |ConvertTo-Json -Depth 10

### Log type is the source custom log type in Log Analytics. _CL will be appeneded by Microsoft
$logType = 'The name you want for you index aka the log name'

## The following is from the Microsoft Doc page - and is broken out of a function.
$method = "POST"
$contentType = "application/json"
$api = "/api/logs"
$date = [DateTime]::UtcNow.ToString("r")
$contentLength = $body.Length
$xMSDate = "x-ms-date:" + $date
$stringToSign = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xMSDate + "`n" + $api
$stringBytes = [Text.Encoding]::UTF8.GetBytes($stringToSign)
$primaryKeyBytes = [Convert]::FromBase64String($primaryKey)


$hmac256 = New-Object System.Security.Cryptography.HMACSHA256
$hmac256.Key = $primaryKeyBytes
$hash = $hmac256.ComputeHash($stringBytes)
$hashBase64 = [Convert]::ToBase64String($hash)
$authorization = 'SharedKey {0}:{1}' -f $workspaceID,$hashBase64
$signature = $authorization
$uri = "https://" + $workspaceID + ".ods.opinsights.azure.com" + $api + "?api-version=2016-04-01"
$headers = @{"Authorization" = $signature;"Log-Type" = $logType;"x-ms-date" = $date;"time-generated-field" = $date}
$response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
$response
$response.StatusCode

## Status Code 200 = The world is all ok, and your data posted.
#endregion



