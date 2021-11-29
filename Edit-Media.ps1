﻿function Edit-Media
{
    <#
    .Synopsis
        Edits media files
    .Description
        Modifies media files to apply advanced filters
    .Notes
        Edit-Media will return the output file, which can in turn be piped into the next Edit-Media.  
        Each parameter set of Edit-Media will perform one and only one action.
        Using Edit-Media in a fluent pipeline will allow you to easily control the order in which actions are applied.
    .Example
        Get-Item a.mp4 | 
            Edit-Media -FadeIn |
            Edit-Media -Rotate 90
    .Link
        Convert-Media
    .Link
        Get-Media
    .Link
        Get-RoughDraftExtension
    .Link
        Use-RoughDraftExtension
    #> 
    [CmdletBinding(DefaultParameterSetName='None',SupportsShouldProcess)]
    [OutputType([IO.FileInfo])]   
    param(
    # The input path
    [Parameter(Mandatory,Position=0,ValueFromPipelineByPropertyName)]
    [Alias('Fullname')]
    [string[]]
    $InputPath,
        
    # The output path.  If not provided, the output path will be named for the current edit action, i.e. 1_FadeIn.mp4
    [Parameter(Position=1,ValueFromPipelineByPropertyName)]    
    [string]
    $OutputPath,

    # The output map.  This can be provided to map multiple outputs from a single input.
    [Collections.IDictionary]
    $OutputMap,

    # The coded used for the conversion
    [Parameter(Position=2,ValueFromPipelineByPropertyName)]    
    [string]
    $Codec,

    # The path to FFMpeg.exe.  By default, checks in Program Files\FFMpeg\. Download FFMpeg from http://ffmpeg.org/.  
    [Parameter(ValueFromPipelineByPropertyName)]
    [string]
    $FFMpegPath,

    # The metadata to put in the converted file
    [Collections.IDictionary]
    $MetaData,

    # The timespan to start 
    [Parameter(ValueFromPipelineByPropertyName)]
    [Timespan]
    $Start,
    
    # The time span to end 
    [Parameter(ValueFromPipelineByPropertyName)]
    [Timespan]
    $End,
    
    # A series of video filters.  The key is the name of the filter, and the value can either be the direct string value of the filter, or a hashtable containing the filter components.
    [Parameter(Mandatory=$true,ParameterSetName='CustomVideoFilter', ValueFromPipelineByPropertyName)]
    [Collections.IDictionary]
    $VideoFilter,

    # A series of audio filters.  The key is the name of the filter, and the value can either be the direct string value of the filter, or a hashtable containing the filter components.
    [Parameter(Mandatory=$true,ParameterSetName='CustomAudioFilter', ValueFromPipelineByPropertyName)]
    [Parameter(ParameterSetName='CustomVideoFilter', ValueFromPipelineByPropertyName)]
    [Collections.IDictionary]
    $AudioFilter,

    # A series of complex filters.  The key is the name of the filter, and the value can either be the direct string value of the filter, or a hashtable containing the filter components.
    [Collections.IDictionary[]]
    $ComplexFilter
    )

    dynamicParam {
        $myCmd = $MyInvocation.MyCommand
        Use-RoughDraftExtension -CommandName $myCmd -DynamicParameter
    }

    begin {
        $ErrorList = @()
        $progId = Get-Random
        $processFFMpegOutput = 
            {                
                if ($_ -like "*time=*" -and $_ -like "*bitrate=*" -and $mediaInfo.Duration) {
                    $lineChunks = $_.Tostring() -split "[ =]" -ne '' | Where-Object { $_.Trim() } 
                    $lineData = New-Object PSObject 
                    for ($i =0; $i -lt $lineChunks.Count; $i+=2) {                
                        $lineData |Add-Member NoteProperty $lineChunks[$i].TrimEnd("=") $lineChunks[$i + 1] -Force
                    }
            

                    $time = $lineData.Time -as [Timespan]
                    $perc = $time.TotalMilliseconds * 100 / $mediaInfo.Duration.TotalMilliseconds
                    if ($perc -ge 100) { $perc = 100 }
                    Write-Progress "Encoding $ri" "$lineData".TrimStart("@{").TrimEnd("}") -PercentComplete $perc -id $progId
                } else {
                    if ($_ -like "*error*" -or $_ -like "*unable*" -or $inErrorState) {
                        $inErrorState = $true
                        $ErrorList += "$_".Trim()                           
                        Write-Verbose "$_"
                    } else {
                        Write-Verbose "$_"
                    }
                }        
            }    

        $endFFMpegOutput = {
            if ($ErrorList.Count) {
                Write-Error "$($ErrorList -join ([Environment]::NewLine))"
            }
        }
    }

    process {
        #region Find FFMpeg
        $ffmpeg = & $findFFMpeg -FFMpegPath $ffMpegPath
        if (-not $ffmpeg) { return }
        #endregion Find FFMpeg
        $myParams = [Ordered]@{} + $PSBoundParameters
        $ri = 
            if ([IO.File]::Exists($InputPath[0])) {
                $InputPath[0]
            } else {
                $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($InputPath[0])
            }                    

        if (-not $OutputPath -and -not $OutputMap.Count) {
            $inputItem = Get-Item -LiteralPath $ri
            $paramSetShortName = 
                ($PSCmdlet.ParameterSetName -split "\$([IO.Path]::DirectorySeparatorChar)")[-1] -replace 
                '\.RoughDraft\.(ext|extension)\.ps1$'
            $OutputPath = $inputItem.Fullname.Substring(0, $inputItem.FullName.Length - $inputItem.Extension.Length) + "_$paramSetShortName" + $inputItem.Extension
        }
        $uro = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

                
        $mediaInfo = Get-Media -InputPath $ri 
        if (-not $start) { $start = [Timespan]::FromMilliseconds(0) }
        if (-not $end -and $mediaInfo.Duration)   { $end = $MediaInfo.Duration }
        $ffmpegParams = @()

        if ($Codec) {
        
            $foundSeparator = $false
            $codecList = & $ffmpeg -codecs 2>&1 | 
                Where-Object {
                    $foundSeparator
                    if ($_ -like "*------*") {
                        $foundSeparator = $true
                    }
                } |
                ForEach-Object {
                    $parts = $_ -split " {1,}" -ne ''
                    $fields = $parts[0]
                    $shortName = $parts[1]
                    $fullname = $parts[2..($parts.Count - 1)] -join ' ' 
                    New-Object PSObject |
                        Add-Member NoteProperty ShortName $shortName -Force -PassThru | 
                        Add-Member NoteProperty FullName $fullname -Force -PassThru | 
                        Add-Member NoteProperty CanDecode ($fields -like "*D*") -Force -PassThru |
                        Add-Member NoteProperty CanEncode ($fields -like "*E*") -Force -PassThru |
                        Add-Member NoteProperty IsVideoCodec ($fields -like "*V*") -Force -PassThru |
                        Add-Member NoteProperty IsAudioCodec ($fields -like "*A*") -Force -PassThru |
                        Add-Member NoteProperty IsSubtitleCodec ($fields -like "*S*") -Force -PassThru |
                        Add-Member NoteProperty IsIntraFrameOnlyCodec ($fields -like "*I*") -Force -PassThru |
                        Add-Member NoteProperty IsLossyCompression ($fields -like "*L*") -Force -PassThru |
                        Add-Member NoteProperty IsLosslessCompression ($fields -like "*S*") -Force -PassThru 
        
                }   
                
            $matchingCodec = $codecList | Where-Object {$_.ShortName -like $codec -or $_.FullName -like $codec } | Select-Object -First 1 

            if (-not $matchingCodec) {
                Write-Error "Codec not found.  Try one of the following items $($codecList | Where-Object {$_.CanEncode } | Select ShortName, Fullname)"
                return
            }

            $ffmpegParams += "-c" 
            $ffmpegParams += "$($matchingCodec.ShortName)"
        }


        $filterParams = @()
        
        if ($MetaData) {
            foreach ($kv in $metaData.GetEnumerator()) {
                $filterParams += "-metadata"        
                $filterParams+= "`"$($kv.Key)`"=`"$($kv.Value)`""        
            }
        }

        if ($VideoFilter) {            
            foreach ($kv in $VideoFilter.GetEnumerator()) {
                $filterParams += "-vf"
                $filterString = "$($kv.Key)=".ToLower()
                if ($kv.Value -is [Collections.IDictionary]) {
                    $filterString += '"'
                    $filterString += @(foreach ($ikv in $kv.Value.GetEnumerator()) {
                        "$($ikv.Key)=$($ikv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                    }) -join ':'
                    $filterString += '"'
                } elseif ($kv.Value.ToString().Trim()) {
                    $filterString += "$($kv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                }
                $filterParams += $filterString
            }
        }

        if ($AudioFilter) {            
            foreach ($kv in $AudioFilter.GetEnumerator()) {
                $filterParams += "-af"
                $filterString = "$($kv.Key)=".ToLower()
                if ($kv.Value -is [Collections.IDictionary]) {
                    $filterString += '"'
                    $filterString += @(foreach ($ikv in $kv.Value.GetEnumerator()) {
                        "$($ikv.Key)=$($ikv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                    }) -join ':'
                    $filterString += '"'
                } elseif ($kv.Value.ToString().Trim()) {
                    $filterString += "$($kv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                }
                $filterParams += $filterString
            }
        }


        if ($ComplexFilter) {
            foreach ($cf in $ComplexFilter) {
                $filterParams += "-filter_complex"
                $filterParams += 
                @(foreach ($kv in $cf.GetEnumerator()) {
                    "$($kv.Key)=".ToLower() +
                    $(if ($kv.Value -is [Collections.IDictionary]) {
                        @(foreach ($ikv in $kv.Value.GetEnumerator()) {
                            "$($ikv.Key)=$($ikv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                        }) -join ':'
                    } elseif ($kv.Value.ToString().Trim()) {
                        "$($kv.Value.ToString().Replace(',','\,').Replace(':','\:'))"
                    })
                
                }) -join ','
            }
        }

        $ffInFiles = @(
            foreach ($in in $InputPath) {
                if ([IO.File]::Exists($In)) {
                    '-i'
                    ([IO.FileInfo]$in).FullName
                } else {
                    '-i'
                    "$($ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($in) | Get-Item |Select-Object -ExpandProperty Fullname)"
                }
            }
        )

        $outParams = @(
            if ($OutputPath -and $uro) {
                $uro
                '-y'
            } elseif ($OutputMap.Count) {
                foreach ($kv in $OutputMap.GetEnumerator()) {
                    '-map'
                    if ($kv.Key -match '\[\w+\]') {
                        $kv.Key
                    } else {
                        "[$($kv.Key)]"
                    }
                    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($kv.Value).ToString()
                }
                '-y'
            }
        )

        #region Handle Extensions
        Use-RoughDraftExtension -CommandName $myCmd -CanRun -ExtensionParameter $myParams |
            . Use-RoughDraftExtension -Run | 
            . { process { 
                $inObj = $_
                if ($inObj.ExtensionOutput) {
                    Write-Verbose "Adding Filter Parameters from Extension '$extensionCommand'"
                    Write-Verbose "$extensionOutput"
                    $FilterParams += $extensionOutput
                }
                if ($inObj.Done) {
                    continue nextFile
                }
            } }
        #endregion Handle Extensions


        # Write the arguments out to verbose
        Write-Verbose "FFMpeg Arguments -i $ri -ss `"$start`" -to `"$end`" $($filterParams -join ' ') $uro -y $($ffmpegParams -join ' ')"
        $ffMpegFullArgs = @(
            $ffInFiles
            '-ss'
            "$start"
            if ("$end") {
                '-to'
                "$end"
            }
            $filterParams
            $OutParams
            $ffmpegParams
        )

        $timeArgs  =  @(
            '-ss'
            "$start"
            if ("$end") {
                '-to'
                "$end"
            }
        )
        
        if ($WhatIfPreference) { return $ffMpegFullArgs } # If -WhatIf was passed, return the FFMpeg Arguments
        
        if (-not $PSCmdlet.ShouldProcess("$($ffMpegFullArgs -join ' ')")) { return } # Otherwise, check ShouldProcess
        & $ffmpeg @ffInFiles @timeArgs @filterParams @outParams @ffmpegParams 2>&1 | 
            ForEach-Object -Process $processFFMpegOutput -End $endFFMpegOutput

        if ($uro) { # If we had a single output
            Get-Item -ErrorAction SilentlyContinue -LiteralPath $uro # get it.
        } elseif ($OutputMap.Count) { # If we had an output map
            foreach ($kv in $OutputMap.GetEnumerator()) {
                $rp = # Find each file in the map
                    try { 
                        $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($kv.Value)
                    } catch {
                        $null
                    }

                if ($rp) { Get-Item -LiteralPath $rp } # and output it.
            }
        }
    }
}
