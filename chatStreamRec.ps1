# Chaturbate Stream Recorder


#Definition der Variablen
$pages = @{};
$pages.Add("chaturbate.com", @{"matchString"="https://edge.+.m3u8"; "offlineStrings"=@("room_status: `"offline`"", "Hidden Cam", "room_status: `"private`"")})
$pages.Add("cam4.com", @{"matchString"="https://com4-.+.m3u8"; "offlineStrings"=@("room_status: `"offline`"", "Hidden Cam", "room_status: `"private`"")})
$baseUrl = "https://chaturbate.com/";
#http://odir.org/to/primechats.com
#omagadomagad

#maxRec definiert die Maximal gleichzeitig laufenden Aufnahmen
$maxRec = 3;

#currentRec ist der Zähler für die aktuell laufenden Aufnahmen
$currentRec = 0;

#Enthällt Key Value Pairs von allen gerade laufenden Aufnahmen
$Processes =@{}

#Läd alle abzufragenden Streams
$csvData = Import-Csv -Path .\Streams.csv -Delimiter ";"


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$processPath = "./Processes.json"

#Auslesen der Gestarteten und laufenden Processe

$runningProcesses = Get-Process -Name ffmpeg -ErrorAction SilentlyContinue
$startedProcesses = Get-Content -Path $processPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-JSON
Remove-Item $processPath -ErrorAction SilentlyContinue
$currentRec = $runningProcesses.Count

foreach($entry in $csvData)
{
    $isOnline = $true;
    $streamer = $entry.Name;
    $currentUri = $baseUrl + $entry.Name + "/";
    $currentUri
    $result = Invoke-RestMethod -Uri $currentUri -Method Get
    $offlineStrings = @("room_status: `"offline`"", "Hidden Cam", "room_status: `"private`"")

    foreach ($check in $offlineStrings)
    {
        if($result.Contains("$check"))
        {
            $isOnline = $false;
            Write-Host "$streamer $check"
            break;
        }
    }
    
    if ($isOnline)
    {
        $currentDate = Get-Date -UFormat "%Y-%m-%d-%H-%M"
        $filename = "$currentDate-$($entry.name).mkv"

        $playlistUrl = $result -split "'" -match "https://edge.+.m3u8"
        $streamer
        $playlistUrl.Get(0)
        $playlist = Invoke-RestMethod -Method Get -Uri $playlistUrl.Get(0)
        $playlist = Invoke-RestMethod -Method Get -Uri $playlistUrl.Get(1)
        $splitPlaylist = ($playlist -split "\n")
        $highResPlaylist =$splitPlaylist[$splitPlaylist.Count - 2]
        $newPlaylist = $playlistUrl.Get(1).Substring(0, $playlistUrl.Get(0).Length -13) + $highResPlaylist
        if($startedProcesses.$streamer -eq $null -and $currentRec -le $maxRec)
        {
            Write-Host "Start Rec1"

            $returnCode = Start-Process -FilePath ".\ffmpeg.exe" -ArgumentList  '-i', $newPlaylist,'-codec copy', $filename -passthru
            $Processes.Add($streamer, @{"Id"=$($returnCode.id); "Uri"=$newPlaylist})
            
            $currentRec += 1;
        }
        elseif ($startedProcesses.$streamer -ne $null -and $currentRec -le $maxRec)
        {
            $checkPro = Get-Process -Id $startedProcesses.$streamer.Id -ErrorAction SilentlyContinue
            if($checkPro -eq $null)
            {
                Write-Host "Start Rec2"
                $returnCode = Start-Process -FilePath ".\ffmpeg.exe" -ArgumentList  '-i', $newPlaylist,'-codec copy', $filename -passthru
                $Processes.Add($streamer, @{"Id"=$($returnCode.id); "Uri"=$newPlaylist})
            
                # Starte Aufnahme und Schreib in Liste
                $currentRec += 1;
            }
            else {
                $Processes.Add($streamer, @{"Id"=$checkPro.Id; "Uri"=$startedProcesses.$streamer.Uri})
            }
            
        }
    }

    
}
$Processes | ConvertTo-JSON | Set-Content -Path "./Processes.json"