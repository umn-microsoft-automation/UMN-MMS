#region License
    ###
    # Copyright 2017 University of Minnesota, Office of Information Technology

    # This program is free software: you can redistribute it and/or modify
    # it under the terms of the GNU General Public License as published by
    # the Free Software Foundation, either version 3 of the License, or
    # (at your option) any later version.

    # This program is distributed in the hope that it will be useful,
    # but WITHOUT ANY WARRANTY; without even the implied warranty of
    # MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    # GNU General Public License for more details.

    # You should have received a copy of the GNU General Public License
    # along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
    ## Modules for infoblox
    # It is assumed that a Connection has already been established and the cookie is being passed to many of these functions.
    # Use 'Connect-Infoblox' to return a $cookie --
#endregion

Import-Module UMN-Google                

#region set variables
    # Dark sky provides the ApI https://darksky.net/dev/docs
    #$city = "33.9533,-84.5406"
    
    # google sheets https://github.com/umn-microsoft-automation/UMN-Google
    # this does require setting up project in google.  Follow the link above for additional info
    #region Using Google Service in automation
        $certPath = ""
        $iss = ''
        $certPswd = (Get-StoredCredential -target gCertPSWD).UserName
        $scope = "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/drive.file"
        $accessToken = Get-GOAuthTokenService -scope $scope -certPath $certPath -certPswd $certPswd -iss $iss
    #endregion
    #region Using Personal login this still requires 
        $projectID = "oit-mpt-powershell-sheets";$app_key = "203771150452-ksfb4ifju8atqutpkkfgrft61g29mlhe.apps.googleusercontent.com"
        $app_Secret = "bhO29vSPWugiRz85HiLcRLDm";$redirectURI = "https://umn.edu"
        $scope = "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/drive.file"
        $tokens = Get-GOAuthTokenUser -projectID $projectID -appKey $app_key -appSecret $app_secret -scope $scope -redirectUri $redirectURI -refreshToken $tokens.refreshToken
        $accessToken = $tokens.accesstoken
    #endregion
#endregion

#region Prep googhesheet    
    $spreadSheet = New-GSheetSpreadSheet -accessToken $accessToken -title "MMS 2018 Weather"
    $spreadSheetID  = $spreadSheet.spreadsheetId
    Set-GFilePermissions -emailAddress 'tjsobeck@umn.edu' -role writer -fileID $spreadSheetID -accessToken $accessToken -type user -sendNotificationEmail:$true
    [void]([System.Collections.ArrayList]$values = @()).Add(@("Date","High Temp","Low Temp"))
    $null = Set-GSheetData -spreadSheetID $spreadSheetID -accessToken $accessToken -sheetName 'Sheet1' -values $values -append
#endregion

#region Fetch Long/Lat
    function Get-LatLong{
        param
        (
            [parameter(Mandatory)]
            [string]$city,

            [parameter(Mandatory)]
            [ValidatePattern("^[a-z]{2}$")]
            [string]$state,

            [parameter(Mandatory)]
            [string]$geoApiKey
        )
        Begin{}
        Process
        {
            $url = "https://api.geocod.io/v1.3/geocode?q=$($city)%2c+$($state)&api_key=$geoApiKey"
            $response = Invoke-WebRequest -Uri $url
            ($response.content | ConvertFrom-Json).results
        }
        End{}
    }
#endregion
$longLat = (Get-LatLong -city "Minneapolis" -state "MN" -geoApiKey $geoApiKey)[0].location
$longLatFormatted = "$($longLat.lat),$($longLat.lng)"
foreach ($n in (-10 .. -1)){
    $url = "https://api.forecast.io/forecast/$darkSkyAPIkey/$longLatFormatted,$(([Math]::Floor((Get-Date (((Get-Date).AddDays($n)).toUniversalTime()) -UFormat +%s))))"
    $weather = Invoke-WebRequest $url | ConvertFrom-Json
    ((Get-Date).AddDays($n)).ToShortDateString()
    $weather.daily.data.temperatureHigh
    $weather.daily.data.temperatureLow
    [void]([System.Collections.ArrayList]$values = @()).Add(@(((Get-Date).AddDays($n)).ToShortDateString(),$weather.daily.data.temperatureHigh,$weather.daily.data.temperatureLow))
    $null = Set-GSheetData -spreadSheetID $spreadSheetID -accessToken $accessToken -sheetName 'Sheet1' -values $values -append
}

Remove-GSheetSpreadSheet -fileID $spreadSheetID -accessToken $accessToken