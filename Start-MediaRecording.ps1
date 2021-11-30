function Start-MediaRecording
{
    <#
    .Synopsis
        Starts a media recording
    .Description
        Starts capturing input from a capture device.

        This can be used to capture any DirectShow input for a given PC, like an attached webcam or microphone.

        If no parameters other than an output file are passed, the media recording will attempt to capture the screen using the Screen Desktop Recorder.  If this is not installed, the capture will not succeed.

        You can also install video filters that allow you to capture the desktop or microphone.  For more information, see the notes.
    .Example
        Start-MediaRecording -OutputPath c:\screencap.avi |
            Stop-MediaRecording -After 10
    .Notes
        To capture the screen, you'll need install the open source project ScreenCapturer.

        You can get it on [SourceForge](http://sourceforge.net/projects/screencapturer/) or [GitHub](https://github.com/rdp/screen-capture-recorder-to-video-windows-free)
    .Link
        Stop-MediaRecording
    #>
    [OutputType([Diagnostics.Process])]
    param(
    # The output path
    [Parameter(Mandatory=$true,ValueFromPipelineByPropertyName=$true)]
    [string]
    $OutputPath,

    # The name of the video device.  If not specified, the screen will be captured.
    #|Options Get-MediaCaptureDevice |? { $_.IsVideoDevice } | Select-Object -ExpandProperty FriendlyName
    [string]
    $VideoDevice,

    # The name of the audio device.  If not specified, the currently playing audio will be captured
    #|Options Get-MediaCaptureDevice |? { -not $_.IsVideoDevice } | Select-Object -ExpandProperty FriendlyName
    [string]
    $AudioDevice,

    # If set, will only capture video
    [Switch]
    $NoAudio,

    # If set, will only capture audio
    [Switch]
    $NoVideo,

    # The audio gain, either in decibals (i.e. 12db) or as a ratio (i.e. 1.5)
    [string]
    $AudioGain,

    # The size of the real time buffer.  The larger the buffer, the more memory used, but the less likely the capture is to lag.
    [long]
    $RealTimeBufferSize = 700000kb,

    # The capture frame rate (by default, 30)
    [uint32]
    $FrameRate = 30,

    # The path to FFMpeg.exe.  By default, checks in Program Files\FFMpeg\. Download FFMpeg from http://ffmpeg.org/.
    [Parameter(ValueFromPipelineByPropertyName=$true)]
    [string]
    $FFMpegPath = "$env:ProgramFiles\FFMpeg\bin\FFMpeg.exe"
    )



    process {

        $inputSrcParts = @()
        if ($AudioDevice) {
            $inputSrcParts += "audio=`"$AudioDevice`""
        } elseif (-not $NoAudio) {
            $inputSrcParts += "audio=`"virtual-audio-capturer`""
        }

        if ($VideoDevice) {
            $inputSrcParts += "video=`"$VideoDevice`""
        } elseif (-not $NoVideo) {
            $inputSrcParts += "video=`"screen-capture-recorder`""
        }

        $uro = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)

        $aList  = '-rtbufsize', "$([Math]::Floor($RealTimeBufferSize / 1kb))k",
            '-framerate', "$FrameRate",
            '-f', 'dshow','-i',"$($inputSrcParts -join ':')"


        if ($AudioGain) {
            $aList += '-af'
            $aList+= "`"volume=$($audioGain -ireplace 'db', 'dB')`""
        }
        $aList +=
            '-tune', 'zerolatency',
            "$uro",'-y'



        if ($DebugPreference -eq 'inquire') {
            #region Find FFMpeg
            if ($PSBoundParameters.FfmpegPath) {
                $script:ffmpeg = $null
            }
            if (-not $script:ffmpeg) {
                if (Test-Path $FFMpegPath) {
                    $script:ffmpeg = Get-Command $FFMpegPath
                }
            }
            if (-not $script:ffmpeg) {
                Write-Error "FFMpeg not found.  Must provide -FFMpegPath at least once"
                return
            }
            #endregion Find FFMpeg

            & $script:ffmpeg @aList 2>&1


        } else {
            $ffMpegProc = Start-Process -FilePath $FFMpegPath -ArgumentList $aList -PassThru -WindowStyle Minimized

            $ffMpegProc
        }


    }


