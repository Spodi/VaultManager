

<#
.NOTES
CueSheet classes and functions v24.04.16
    
    MIT License

    Copyright (C) 2024 Spodi

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
class Time : IComparable {

    [ValidateRange(0, 7843003432699639)] #uint64 for TotalBytes
    [Int64]$TotalFrames = 0

    Time() {
    }
    Time([SByte]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([int16]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([int32]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([int64]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([Byte]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([uint16]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([uint32]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([uint64]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([double]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([float]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    Time([TimeSpan]$Time) {
        [UInt32]$Modulo = 0
        $frames = [System.Numerics.BigInteger]::DivRem($Time.Ticks * 75, 10000000, [ref]$Modulo)
        if ($Modulo) {
            Write-Warning 'Lost precission. Converting from [TimeSpan] will only be accurate in increments of 80ms!'
        }
        $this.TotalFrames = $frames
    }
    Time([string]$timeString) {
        #if ($timeString -match '^\d+:0*[1-5]?[1-9]]:0*([0-9]|[1-][0-9]|7[1-4])$') {
        if ($timeString -match '^\d+:\d+:\d+$') {    
            [Double[]]$splitTimes = $timeString -split ':'
            #if ($splitTimes[0] -gt 1742889651711 -or $splitTimes[0] -lt 0) { throw 'Invalid Range for "Minutes". Valid range: 0 to 1742889651711.' }
            if ($splitTimes[1] -gt 59 -or $splitTimes[1] -lt 0) { throw 'Invalid Range for "Seconds". Valid range: 0 to 59.' }
            if ($splitTimes[2] -gt 74 -or $splitTimes[2] -lt 0) { throw 'Invalid Range for "Frames". Valid range: 0 to 74.' }
            $frames = [int64]($splitTimes[0] * 60 * 75 + $splitTimes[1] * 75 + $splitTimes[2])
            if ($frames -gt 7843003432699639) { throw 'Time too long. Maximum time is 1742889651711:01:64.' }
            $this.TotalFrames = $frames
        
        }
        else { throw 'Invalid Format. Must be "<Minutes>:<Seconds>:<CueFrames>".' }
    }

    [int]CompareTo($other) {
        return $this.TotalFrames.CompareTo($other.TotalFrames)
    }
    [string]ToString() {
        return ('{0:d2}' -f $this.Minutes), ('{0:d2}' -f $this.Seconds), ('{0:d2}' -f $this.Frames) -join ':'
    }
    [TimeSpan]ToTimeSpan() {
        return [int64]($this.TotalFrames * 10000000 / 75)
    }
    static [Time]op_Addition([Time]$a, [Time]$b) {
        return $a.TotalFrames + $b.TotalFrames
    }
    static [Time]op_Subtraction([Time]$a, [Time]$b) {
        return $a.TotalFrames - $b.TotalFrames
    }
    static [Time]op_Division([Time]$a, [double]$b) {
        return $a.TotalFrames / $b
    }
    static [Time]op_Multiply([Time]$a, [double]$b) {
        return $a.TotalFrames * $b
    }
    [bool]Equals([object]$other) {
        return $this.TotalFrames -eq $other.TotalFrames
    }
    static [Time]FromBytes([uint64]$Bytes) {
        [UInt16]$Modulo = 0
        [UInt64]$sectors = [System.Numerics.BigInteger]::DivRem($bytes, 2352, [ref]$Modulo)
        if ($Modulo) {
            #[ValidateRange(0,18446744073709550928)]$Bytes = $bytes
            if ($Bytes -gt 18446744073709550928) {
                throw "A value of $Bytes Bytes is out of range. Must be less or equal to 18446744073709550928 Bytes."
            }
            Write-Warning 'No exact multiplicative from a sector size of 2352 bytes. Will round up to the next full sector (cue frame) size.'
            $sectors += 1
        }
        return ([uint64]$sectors)
    }
}
Update-TypeData -TypeName 'Time' -MemberType ScriptProperty -MemberName 'Minutes' -Value {
    [int64]([Math]::floor($this.TotalFrames / 4500))
} -Force
Update-TypeData -TypeName 'Time' -MemberType ScriptProperty -MemberName 'Seconds' -Value {
    [Byte]([Math]::floor(($this.TotalFrames % 4500) / 75))
} -Force
Update-TypeData -TypeName 'Time' -MemberType ScriptProperty -MemberName 'Frames' -Value {
    [Byte]([Math]::floor($this.TotalFrames % 75))
} -Force
Update-TypeData -TypeName 'Time' -MemberType ScriptProperty -MemberName 'TotalBytes' -Value {
    [uint64]([uint64]$this.TotalFrames * 2352)
} -Force

class Index {

    [Byte]$Number
    [Time]$Offset

    [string]ToString() {
        return -join ('{0:d2}' -f $this.Number), $this.Offset
    } 
}
class Track {
    [Byte]$Number
    [ValidateSet('AUDIO', 'CDG', 'MODE1/2048', 'MODE1/2352', 'MODE2/2048', 'MODE2/2324', 'MODE2/2336', 'MODE2/2352', 'CDI/2336', 'CDI/2352')][String]$DataType
    [ValidateSet('DCP', '4CH', 'PRE', 'SCMS', 'DATA')][String[]]$Flags
    [ValidatePattern('^[a-zA-Z0-9]{5}\d{7}$|^$')][String]$ISRC
    [ValidateLength(0, 80)][string]$Performer
    [ValidateLength(0, 80)][string]$Title
    [ValidateLength(0, 80)][string]$Songwriter
    [Time]$PreGap
    [Index[]]$Indexes
    [Time]$PostGap

    [string]ToString() {
        return -join ('{0:d2}' -f $this.Number), $this.DataType
    }  
}

class File {

    [String]$FileName
    [ValidateSet('BINARY', 'MOTOROLA', 'AIFF', 'WAVE', 'MP3')][String]$FileType
    [Track[]]$Tracks

    [string]ToString() {

        return '"', $this.FileName, '" ', $this.FileType -join ''
    }
}

class Sheet {
    [ValidatePattern('^\d{13}$|^$')][String]$Catalog
    [String]$CDTextFile
    [ValidateLength(0, 80)][string]$Performer
    [ValidateLength(0, 80)][string]$Title
    [ValidateLength(0, 80)][string]$Songwriter
    [File[]]$Files
    hidden [bool]$IsDreamcast
}

function ConvertFrom-Cue {
    <#
    .SYNOPSIS
    Converts a Cue sheet formatted string to a collection of Cue.File objects.
    .LINK
    ConvertTo-Cue
    .EXAMPLE
    Get-Content "Twisted Metal 4 (USA).cue" -raw | ConvertFrom-Cue
    Output:
    FileName                             FileType Tracks
    --------                             -------- ------
    Twisted Metal 4 (USA) (Track 01).bin BINARY   {1 MODE2/2352}
    Twisted Metal 4 (USA) (Track 02).bin BINARY   {2 AUDIO}
    Twisted Metal 4 (USA) (Track 03).bin BINARY   {3 AUDIO}
    Twisted Metal 4 (USA) (Track 04).bin BINARY   {4 AUDIO}
    Twisted Metal 4 (USA) (Track 05).bin BINARY   {5 AUDIO}
    Twisted Metal 4 (USA) (Track 06).bin BINARY   {6 AUDIO}
    Twisted Metal 4 (USA) (Track 07).bin BINARY   {7 AUDIO}
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]   [string] $InputObject 
    )
    Process {
        $cueSheet = [Sheet]::new()
        $trackNo = 0
        $fileNo = 0
        $cueTxt = $InputObject -split '\r\n|\r|\n'
        Set-Variable i -Option AllScope
        for ($i = 0; $i -lt $cueTxt.count; $i++) {
            $line = $cueTxt[$i].trim() -split '\s+(?=(?:[^"]|"[^"]+")+$)' -replace '"', ''
            switch ($line[0]) {
                'Catalog' { $cueSheet.Catalog = $line[1]; continue }
                'CDTextFile' { $cueSheet.CDTextFile = $line[1]; continue }
                'Performer' { $cueSheet.Performer = $line[1]; continue }
                'Title' { $cueSheet.Title = $line[1]; continue }
                'Songwriter' { $cueSheet.Songwriter = $line[1]; continue }
                'File' {
                    $cueSheet.Files += [File]@{
                        FileName = $line[1]
                        FileType = $line[2]
                    }
                    :TrackLoop for ($i++; $i -lt $cueTxt.count; $i++) {
                        $line = $cueTxt[$i].trim() -split '\s+(?=(?:[^"]|"[^"]+")+$)'
                        switch ($line[0]) {
                            'Track' { 
                                $cueSheet.Files[$FileNo].Tracks += [Track]@{
                                    Number   = $line[1]
                                    DataType = $line[2]
                                }
                                :IndexLoop for ($i++; $i -lt $cueTxt.count; $i++) {
                                    $line = $cueTxt[$i].trim() -split '\s+(?=(?:[^"]|"[^"]+")+$)'
                                    switch ($line[0]) {
                                        'Index' {
                                            $cueSheet.Files[$FileNo].Tracks[$TrackNo].Indexes += [Index]@{
                                                Number = $line[1]
                                                Offset = [Time]$line[2]
                                            }
                                        }
                                        'Flags' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].Flags = $line[1..($line.count - 1)]; continue }
                                        'ISRC' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].ISRC = $line[1]; continue }                                        
                                        'PreGap' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].PreGap = $line[1]; continue }
                                        'Postgap' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].PostGap = $line[1]; continue }
                                        'Performer' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].Performer = $line[1]; continue }
                                        'Title' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].Title = $line[1]; continue }
                                        'Songwriter' { $cueSheet.Files[$FileNo].Tracks[$TrackNo].Songwriter = $line[1]; continue }
                                        'Track' { $i--; break IndexLoop }
                                        'File' { $i--; break TrackLoop }
                                        'Rem' { continue }
                                        '' { continue }
                                        Default { Write-Warning ("Line $($i): Invalid token in INDEX: $_") } 
                                    }
                                }
                                $trackNo++; continue
                            }
                            'File' { $i--; break TrackLoop }
                            'Rem' { continue }
                            '' { continue }
                            Default { Write-Warning ("Line $($i): Invalid token in FILE: $_") }
                        }
                    } 
                    $fileNo++; continue
                }         
                'Rem' {
                    if ($line[1] -eq 'SINGLE-DENSITY' -and $line[2] -eq 'AREA') {
                        $cueSheet.IsDreamcast = $true
                    }
                    continue
                }
                '' { continue }
                Default { Write-Warning ("Line $($i): Invalid token in ROOT: $_") }        
            }
        }
        $cueSheet 
    }
}
function ConvertTo-Cue {
    <#
    .SYNOPSIS
    Converts a collection of Cue.File objects to a Cue sheet string.
    .LINK
    ConvertFrom-Cue
    .EXAMPLE
    Get-content "Twisted Metal 4 (USA).cue" -raw | convertfrom-Cue | ConvertTo-cue
    Output:
    FILE "Twisted Metal 4 (USA) (Track 01).bin" BINARY
      TRACK 1 MODE2/2352
        INDEX 1 00:00:00
    FILE "Twisted Metal 4 (USA) (Track 02).bin" BINARY
      TRACK 2 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    FILE "Twisted Metal 4 (USA) (Track 03).bin" BINARY
      TRACK 3 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    FILE "Twisted Metal 4 (USA) (Track 04).bin" BINARY
      TRACK 4 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    FILE "Twisted Metal 4 (USA) (Track 05).bin" BINARY
      TRACK 5 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    FILE "Twisted Metal 4 (USA) (Track 06).bin" BINARY
      TRACK 6 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    FILE "Twisted Metal 4 (USA) (Track 07).bin" BINARY
      TRACK 7 AUDIO
        INDEX 0 00:00:00
        INDEX 1 00:02:00
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]   $InputObject
    )
    Process {
        $FileNum = 0
        If ($InputObject.Catalog) { "CATALOG $($InputObject.Catalog)" }
        If ($InputObject.CDTextFile) { "CDTEXTFILE `"$($InputObject.CDTextFile)`"" }
        If ($InputObject.Performer) { "PERFORMER `"$($InputObject.Performer)`"" }
        If ($InputObject.Title) { "TITLE `"$($InputObject.Title)`"" }
        If ($InputObject.Songwriter) { "SONGWRITER `"$($InputObject.Songwriter)`"" }
        foreach ($file in $InputObject.Files) {
            # This isn't optimal, lol. But DreamCast emulators only work with on split bins anyway.
            if ($InputObject.IsDreamcast) {  
                $FileNum++
            }
            if ($FileNum -eq 1) {
                'REM SINGLE-DENSITY AREA'
            }
            elseif ($FileNum -eq 3) {
                'REM HIGH-DENSITY AREA'
            }
            "FILE $file"
            foreach ($track in $file.Tracks) {
                "  TRACK $track"
                If ($track.ISRC) { "    ISRC $($track.ISRC)" }
                If ($track.Performer) { "    PERFORMER `"$($track.Performer)`"" }
                If ($track.Title) { "    TITLE `"$($track.Title)`"" }
                If ($track.Songwriter) { "    SONGWRITER `"$($track.Songwriter)`"" }
                If ($track.Flags) { "    FLAGS $($track.Flags -join ' ')" }
                If ($track.PreGap -gt 0) { "    PREGAP $($track.PreGap)" }
                foreach ($index in $track.indexes) {
                    "    INDEX $index"
                }
                If ($track.PostGap -gt 0) { "    POSTGAP $($track.PostGap)" }
            }
        }
    }
}