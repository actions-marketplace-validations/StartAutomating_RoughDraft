function Stop-MediaRecording
{
    <#
    .Synopsis
        Stops a started media recording
    .Description
        Stops the capture of an existing media recording
    .Link
        Start-MediaRecording
    .Example
        Get-Process ffmpeg | Stop-MediaRecording
    #>
    [OutputType([Nullable])]
    param(
    # The process ID of the media recording
    [ValidateScript({
    $procInfo = [diagnostics.process]::GetProcessById($_)
    if ($procInfo.Name -notlike 'ffmpeg*') {
        throw "$_ is not a ffmpeg process ID"
    }
    return $true
    })]
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [Uint32]
    $Id,

    # An optional timeframe.  If provided, then the process will wait that long to stop the process
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [TimeSpan]
    $After
    )

    process {
        #region Wait if Needed
        if ($After) {
            $then = [DateTime]::Now + $After
        }

        do {
            [Threading.Thread]::Sleep(15)
        } while ($then -ge [Datetime]::Now)
        #endregion Wait if Needed

        $procInfo = [diagnostics.process]::GetProcessById($id)

        if ($procInfo) {
            if ($PSVersionTable.Platform -eq 'Unix') {
                $procInfo | Stop-Process
            } else {
                $null = $procInfo.CloseMainWindow()
            }
        }
    }
}