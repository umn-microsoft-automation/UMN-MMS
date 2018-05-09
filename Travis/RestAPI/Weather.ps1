#region set variables
    # Dark sky provides the ApI https://darksky.net/dev/docs
    $city = "33.9533,-84.5406"
    $darkSkyAPIkey = "ebff2e526a587e28ca90245f97f779ac"
    # google sheets https://github.com/umn-microsoft-automation/UMN-Google
    $certPath = ""
    $iss = ''
    $certPswd = (Get-StoredCredential -target gCertPSWD).UserName
    $scope = "https://www.googleapis.com/auth/spreadsheets https://www.googleapis.com/auth/drive https://www.googleapis.com/auth/drive.file"
    $accessToken = Get-GOAuthTokenService -scope $scope -certPath $certPath -certPswd $certPswd -iss $iss
#endregion

#region Prep googhesheet
    $spreadSheet = New-GSheetSpreadSheet -accessToken $accessToken -title "MMS 2018 Weather"
    $spreadSheetID  = $spreadSheet.spreadsheetId
    Set-GFilePermissions -emailAddress 'tjsobeck@umn.edu' -role writer -fileID $spreadSheetID -accessToken $accessToken -type user -sendNotificationEmail:$true
    [void]([System.Collections.ArrayList]$values = @()).Add(@("Date","High Temp","Low Temp"))
    $null = Set-GSheetData -spreadSheetID $spreadSheetID -accessToken $accessToken -sheetName 'Sheet1' -values $values -append
#endregion
foreach ($n in (-10 .. -1)){
    $url = "https://api.forecast.io/forecast/$darkSkyAPIkey/$city,$(([Math]::Floor((Get-Date (((Get-Date).AddDays($n)).toUniversalTime()) -UFormat +%s))))"
    $weather = Invoke-WebRequest $url | ConvertFrom-Json
    ((Get-Date).AddDays($n)).ToShortDateString()
    $weather.daily.data.temperatureHigh
    $weather.daily.data.temperatureLow
    [void]([System.Collections.ArrayList]$values = @()).Add(@(((Get-Date).AddDays($n)).ToShortDateString(),$weather.daily.data.temperatureHigh,$weather.daily.data.temperatureLow))
    $null = Set-GSheetData -spreadSheetID $spreadSheetID -accessToken $accessToken -sheetName 'Sheet1' -values $values -append
}

Remove-GSheetSpreadSheet -fileID $spreadSheetID -accessToken $accessToken