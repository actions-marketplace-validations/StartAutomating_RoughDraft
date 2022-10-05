
Extension/YouTubeDL.RoughDraft.Extension.ps1
--------------------------------------------
### Synopsis
Youtube Downloader

---
### Description

Extends Get-Media to enable the downloading of videos from YouTube and other sources, using YouTubeDL

---
### Related Links
* [http://ytdl-org.github.io/youtube-dl/](http://ytdl-org.github.io/youtube-dl/)



---
### Parameters
#### **YouTubeURL**

> **Type**: ```[Uri]```

> **Required**: true

> **Position**: 1

> **PipelineInput**:false



---
#### **YouTubeOutputFile**

The YouTubeDL Output File.  See [documentation](https://github.com/ytdl-org/youtube-dl/blob/master/README.md#output-template)



> **Type**: ```[String]```

> **Required**: false

> **Position**: 2

> **PipelineInput**:false



---
#### **DownloadLatestYouTubeDL**

If set, will force a download of the latest YouTubeDL (even if one is already found).  It will be placed in $home/.RoughDraft/.



> **Type**: ```[Switch]```

> **Required**: false

> **Position**: named

> **PipelineInput**:false



---
#### **AutoGeneratedSubtitle**

If set, will download auto-generated subtitles.



> **Type**: ```[Switch]```

> **Required**: false

> **Position**: named

> **PipelineInput**:false



---
#### **AllSubtitle**

If set, will download all subtitles.



> **Type**: ```[Switch]```

> **Required**: false

> **Position**: named

> **PipelineInput**:false



---
#### **YouTubeDownloadArgumentList**

> **Type**: ```[String[]]```

> **Required**: false

> **Position**: 3

> **PipelineInput**:false



---
#### **YouTubeDownloadInformation**

If set, will return the information about the download, instead of downloading.



> **Type**: ```[Switch]```

> **Required**: false

> **Position**: named

> **PipelineInput**:false



---
### Syntax
```PowerShell
Extension/YouTubeDL.RoughDraft.Extension.ps1 [-YouTubeURL] <Uri> [[-YouTubeOutputFile] <String>] [-DownloadLatestYouTubeDL] [-AutoGeneratedSubtitle] [-AllSubtitle] [[-YouTubeDownloadArgumentList] <String[]>] [-YouTubeDownloadInformation] [<CommonParameters>]
```
---



