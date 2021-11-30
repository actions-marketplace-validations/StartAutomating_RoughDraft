﻿function Invoke-FFPlay
{
    <#
    .Synopsis
        Invokes FFPlay.
    .Description
        Runs FFPlay
    .Example
        Invoke-FFPlay -FFPlayArgument "$home\Music\ASong.mp3"
    .Link
        Invoke-FFProbe
    .Link
        Invoke-FFPlay
    #>
    [CmdletBinding(PositionalBinding=$false)]
    [OutputType([string])]
    param(
    # Arguments to FFPlay.
    [Parameter(ValueFromPipelineByPropertyName,ValueFromRemainingArguments)]
    [string[]]
    $FFPlayArgument,

    # The path to FFPlay.
    [string]
    $FFPlayPath,

    # If set, will run as a background job.
    [switch]
    $AsJob
    )

    process {
        #region Find FFPlay
        $FFPlay = & $findFFPlay -FFPlayPath $FFPlayPath
        if (-not $FFPlay) {return}
        #endregion Find FFPlay
        #region Handle -AsJob
        if ($AsJob) {
            return & $startRoughDraftJob
        }
        #endregion Handle -AsJob
        #region Run FFPlay
        Write-Verbose "Invoke FFPlay with $($FFPlayArgument -join ' ')"
        & $FFPlay @FFPlayArgument *>&1 |
            . {
                process {
                    $line = $_
                    "$line"
                }
            }
        #endregion Run FFPlay
    }
}
