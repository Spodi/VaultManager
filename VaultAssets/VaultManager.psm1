$FolderizeWExts = @('.cue', '.ccd', '.bin', '.iso') #default extensions for whitelist go here. An empty string ('') means "files without extension".

#region Classes
class CueTime : IComparable {
    #region Definition
    #[ValidateRange(0, 3921501716349819)] #int64 for TotalBytes
    [ValidateRange(0, 7843003432699639)] #uint64 for TotalBytes
    [Int64]$TotalFrames = 0
    #endregion Definition
    #region Constructors
    CueTime() {}

    CueTime([SByte]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([int16]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([int32]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([int64]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([Byte]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([uint16]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([uint32]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([uint64]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([double]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }
    CueTime([float]$TotalFrames) {
        $this.TotalFrames = $TotalFrames
    }

    CueTime([TimeSpan]$Time) {
        [UInt32]$Modulo = 0
        $frames = [System.Numerics.BigInteger]::DivRem($Time.Ticks * 75, 10000000, [ref]$Modulo)
        if ($Modulo) {
            Write-Warning 'Lost precission. Converting from [TimeSpan] will only be accurate in increments of 80ms!'
        }
        $this.TotalFrames = $frames

    }

    CueTime([string]$timeString) {
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
    #endregion Constructors
    #Region Methods
    [int]CompareTo($other) {
        return $this.TotalFrames.CompareTo($other.TotalFrames)
    }
    [string]ToString() {
        return ('{0:d2}' -f $this.Minutes), ('{0:d2}' -f $this.Seconds), ('{0:d2}' -f $this.Frames) -join ':'
    }
    [TimeSpan]ToTimeSpan() {
        return [int64]($this.TotalFrames * 10000000 / 75)
    }
    static [CueTime]op_Addition([CueTime]$a, [CueTime]$b) {
        return $a.TotalFrames + $b.TotalFrames
    }
    static [CueTime]op_Subtraction([CueTime]$a, [CueTime]$b) {
        return $a.TotalFrames - $b.TotalFrames
    }
    static [CueTime]op_Division([CueTime]$a, [double]$b) {
        return $a.TotalFrames / $b
    }
    static [CueTime]op_Multiply([CueTime]$a, [double]$b) {
        return $a.TotalFrames * $b
    }
    [bool]Equals([object]$other) {
        return $this.TotalFrames -eq $other.TotalFrames
    }

    static [CueTime]FromBytes([uint64]$Bytes) {
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
    #endregion Methods
}
Update-TypeData -TypeName 'CueTime' -MemberType ScriptProperty -MemberName 'Minutes' -Value {
    [int64]([Math]::floor($this.TotalFrames / 4500))
} -Force
Update-TypeData -TypeName 'CueTime' -MemberType ScriptProperty -MemberName 'Seconds' -Value {
    [Byte]([Math]::floor(($this.TotalFrames % 4500) / 75))
} -Force
Update-TypeData -TypeName 'CueTime' -MemberType ScriptProperty -MemberName 'Frames' -Value {
    [Byte]([Math]::floor($this.TotalFrames % 75))
} -Force
Update-TypeData -TypeName 'CueTime' -MemberType ScriptProperty -MemberName 'TotalBytes' -Value {
    [uint64]([uint64]$this.TotalFrames * 2352)
} -Force


class CueIndex {
    #region Definition
    [Byte]$Number
    [CueTime]$Offset
    #endregion Definition
    #region Constructors

    #endregion Constructors
    #Region Methods
    [string]ToString() {
        return -join ('{0:d2}' -f $this.Number), $this.Offset
    }
    #endregion Methods    
}
class CueTrack {
    #region Definition
    [Byte]$Number
    [ValidateSet('AUDIO', 'CDG', 'MODE1/2048', 'MODE1/2352', 'MODE2/2048', 'MODE2/2324', 'MODE2/2336', 'MODE2/2352', 'CDI/2336', 'CDI/2352')][String]$DataType
    [ValidateSet('DCP', '4CH', 'PRE', 'SCMS', 'DATA')][String[]]$Flags
    [ValidatePattern('^[a-zA-Z0-9]{5}\d{7}$|^$')][String]$ISRC
    [ValidateLength(0, 80)][string]$Performer
    [ValidateLength(0, 80)][string]$Title
    [ValidateLength(0, 80)][string]$Songwriter
    [CueTime]$PreGap
    [CueIndex[]]$Indexes
    [CueTime]$PostGap
    #endregion Definition
    #region Constructors

    #endregion Constructors
    #Region Methods
    [string]ToString() {
        return -join ('{0:d2}' -f $this.Number), $this.DataType
    }
    #endregion Methods    
}
class CueFile {
    #region Definition
    [String]$FileName
    [ValidateSet('BINARY', 'MOTOROLA', 'AIFF', 'WAVE', 'MP3')][String]$FileType
    [CueTrack[]]$Tracks
    #endregion Definition
    #region Constructors
    [string]ToString() {

        return '"', $this.FileName, '" ', $this.FileType -join ''
    }
    #endregion Constructors
    #Region Methods

    #endregion Methods 
}
class CueSheet {
    #region Definition
    [ValidatePattern('^\d{13}$|^$')][String]$Catalog
    [String]$CDTextFile
    [ValidateLength(0, 80)][string]$Performer
    [ValidateLength(0, 80)][string]$Title
    [ValidateLength(0, 80)][string]$Songwriter
    [CueFile[]]$Files
    hidden [bool]$IsDreamcast
    #endregion Definition
    #region Constructors

    #endregion Constructors
    #Region Methods

    #endregion Methods 
}
#endregion Classes

#region Functions
#region file/folder list
function Get-Files {
    <#
    .SYNOPSIS
    Basically "Get-ChildItem -File -recurse", but slightly faster. Gets paths only.
    .LINK
    Get-Folders
    .LINK
    Get-FileSystemEntries
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]   [string] $path
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    process {
        Write-Output ([System.IO.Directory]::EnumerateFiles($path))
        [System.IO.Directory]::EnumerateDirectories($path) | & { process {
                if ($_) {
                    Get-Files $_
                }
            } } 
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
function Get-Folders {
    <#
    .SYNOPSIS
    Basically "Get-ChildItem -Directory -recurse", but slightly faster. Gets paths only.
    .LINK
    Get-Files
    .LINK
    Get-FileSystemEntries
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]  [string] $path,
        [Parameter()]  [string] $recurse
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    process {
        [System.IO.Directory]::EnumerateDirectories($path) | & { process {
                if ($_) {
                    Write-Output $_
                    if ($recurse) {
                        Get-Folders $_
                    }
                }
            } }
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
function Get-FolderSubs {
    <#
    .SYNOPSIS
    Basically "Get-ChildItem -Directory -recurse", but slightly faster. Gets paths only.
    .LINK
    Get-Files
    .LINK
    Get-FileSystemEntries
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]  [string] $path
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    process {
        [System.IO.Directory]::EnumerateDirectories($path) | & { process {
                if ($_) {
                    Write-Output ([System.IO.Directory]::EnumerateDirectories($_))
                }
            } }
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
function Get-FileSystemEntries {
    <#
    .SYNOPSIS
    Basically "Get-ChildItem -recurse", but slightly faster. Gets paths only.
    .LINK
    Get-Files
    .LINK
    Get-Folders
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)] [string] $path
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    process {
        Write-Output ([System.IO.Directory]::EnumerateFiles($Path)) 
        [System.IO.Directory]::EnumerateDirectories($Path) | & { process {
                if ($_) {
                    Write-Output $_
                    Get-FileSystemEntries $_
                }
            } }
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
#endregion file/folder list

#region File managing
function Remove-EmptyFolders {
    <#
    .SYNOPSIS
    Recursely removes all empty folders in a given path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [string] $Path
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    Process {
        foreach ($childDirectory in [System.IO.Directory]::EnumerateDirectories($path)) {
            Remove-EmptyFolders -Path $childDirectory
        }
        $currentChildren = Write-Output ([System.IO.Directory]::EnumerateFileSystemEntries($path))
        if ($null -eq $currentChildren) {
            Write-Host "Removing empty folder at path '${Path}'."
            Remove-Item -Force -LiteralPath $Path
        }
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
function Folderize {
    <#
    .SYNOPSIS
    Copys or moves files and sorts them in folders named like the files. "(Track 00)" and "(Disc 00)" in the filename are ignored.
    .LINK
    UnFolderize
    #>
    [CmdletBinding(DefaultParameterSetName = 'white')]
    param (
        # Source folder (from)
        [Parameter(Mandatory, ParameterSetName = 'white', Position = 0)] [Parameter(Mandatory, ParameterSetName = 'black', Position = 0)] [Parameter(Mandatory, ParameterSetName = 'all', Position = 0)]
        [string]    $source,
        # Destinantion folder (to)
        [Parameter(Mandatory, ParameterSetName = 'white', Position = 1)] [Parameter(Mandatory, ParameterSetName = 'black', Position = 1)] [Parameter(Mandatory, ParameterSetName = 'all', Position = 1)]
        [string]    $destination,
        # Processes only files with this extensions. Accepts an array of extensions. Defaults to @('.cue', '.ccd', '.bin', '.iso') and is the default mode if neither white- or blacklist is specified.
        [Parameter(ParameterSetName = 'white')]
        [string[]]  $whitelist = $FolderizeWExts,
        # Processes only files without this extensions. Accepts an array of extensions, e.g. @('.cue', '.ccd', '.bin', '.iso').
        [Parameter(ParameterSetName = 'black')]
        [string[]]  $blacklist = $FolderizeBExts,
        # Use RegEx instead of file extensions.
        [Parameter(ParameterSetName = 'white')] [Parameter(ParameterSetName = 'black')]
        [switch] $RegEx,
        # Processes all files.
        [Parameter(Mandatory, ParameterSetName = 'all')]
        [switch]    $all,
        # Moves files instead of copying them. Be careful with that.
        [Parameter(ParameterSetName = 'white')] [Parameter(ParameterSetName = 'black')] [Parameter(ParameterSetName = 'all')]
        [switch]    $Move
    )

    Write-Host -NoNewline 'Retrieving file list, this can take a while... '
    $SourceFiles = Get-Files $source
    Write-Host 'Done'

    if ($all) {
        $FileList = $SourceFiles
    }
    elseif ($whitelist) {
        if ($RegEx) {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    if ($file -match $whitelist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -in $whitelist) {
                        $file
                    }
                }   
            }
        }
    }
    elseif ($blacklist) {
        if ($RegEx) {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    if ($file -notmatch $blacklist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -notin $black) {
                        $file
                    }
                }   
            }
        }
    }
    
    if (!(Test-Path -LiteralPath $destination -PathType Container)) {
        New-Item $destination -ItemType Directory | Out-Null
    }
    if (!$filelist) { return }

    foreach ($input in $FileList) {
        # Remove file extension for the new folder name. Will fail on "nameless" files, like .htaccess
        # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
        $SourceFile = @{}
        $SourceFile.Name = $input
        $SourceFile.FileName = [System.IO.Path]::GetFileName($input)
        $SourceFile.BaseName = [System.IO.Path]::GetFileNameWithoutExtension($input).TrimEnd()
        $SourceFile.Extension = [System.IO.Path]::GetExtension($input)
        # also remove the Disc tag e.g. "(Disc 1)" at the end, to get all discs in one folder
        # Join-Path doesn't have -LiteralPath, so use the .Net version instead...
        $DestFolder = [System.IO.Path]::Combine($destination, ($SourceFile.BaseName -replace '\s*\((?:Disc|Track) \d?\d(?: of \d?\d)?\)', '' -replace '\s\s+', '\s').Trim())


        if (!(Test-Path -LiteralPath $DestFolder -PathType Container)) {
            New-Item $DestFolder -ItemType Directory | Out-Null
        }
        $DestFile = [System.IO.Path]::Combine($DestFolder, $SourceFile.FileName)
        $newDest = $DestFolder
        if (Test-Path $DestFile -PathType Leaf) {
            for ($i = 2; ; $i++) {
                $newDest = ([System.IO.Path]::Combine($DestFolder, ($SourceFile.BaseName + " ($i)" + $SourceFile.Extension)))
                if (!(Test-Path $newDest -PathType Leaf)) {
                    Write-Warning "`"$DestFile`" already exists in the destination. File will be renamed."
                    break
                }
            }
        }
        if ($Move) {
            Write-Host -Separator '' "[Move]`t `"", $SourceFile.Name, '" to "', ($newDest -replace '/', '\'), '"'
            Move-Item -LiteralPath $SourceFile.Name $newDest
        }
        else {
            Write-Host -Separator '' "[Copy]`t `"", $SourceFile.Name, '" to "', ($newDest -replace '/', '\'), '"'
            Copy-Item -LiteralPath $SourceFile.Name $newDest
        }
    }
    Write-Host 'Finished organizing.' 
}
function UnFolderize {
    <#
    .SYNOPSIS
    Copys or moves files and flattens the file structure to all files in one folder (no sub-folders).
    .LINK
    Folderize
    #>
    param (
        # Source folder (from)
        [Parameter(Mandatory, ParameterSetName = 'white', Position = 0)] [Parameter(Mandatory, ParameterSetName = 'black', Position = 0)] [Parameter(Mandatory, ParameterSetName = 'all', Position = 0)]
        [string]    $source,
        # Destinantion folder (to)
        [Parameter(Mandatory, ParameterSetName = 'white', Position = 1)] [Parameter(Mandatory, ParameterSetName = 'black', Position = 1)] [Parameter(Mandatory, ParameterSetName = 'all', Position = 1)]
        [string]    $destination,
        # Processes only files with this extensions. Accepts an array of extensions. Defaults to @('.cue', '.ccd', '.bin', '.iso') and is the default mode if neither white- or blacklist is specified.
        [Parameter(ParameterSetName = 'white')]
        [string[]]  $whitelist = $FolderizeWExts,
        # Processes only files without this extensions. Accepts an array of extensions, e.g. @('.cue', '.ccd', '.bin', '.iso').
        [Parameter(ParameterSetName = 'black')]
        [string[]]  $blacklist = $FolderizeBExts,
        # Use RegEx instead of file extensions.
        [Parameter(ParameterSetName = 'white')] [Parameter(ParameterSetName = 'black')]
        [switch] $RegEx,
        # Processes all files.
        [Parameter(Mandatory, ParameterSetName = 'all')]
        [switch]    $all,

        # Moves files instead of copying them. Be careful with that.
        [Parameter(ParameterSetName = 'white')] [Parameter(ParameterSetName = 'black')] [Parameter(ParameterSetName = 'all')]
        [switch]    $Move
    )

    Write-Host -NoNewline 'Retrieving file list, this can take a while... '
    $SourceFiles = Get-Files $source
    Write-Host 'Done'

    if ($all) {
        $FileList = $SourceFiles
    }
    elseif ($whitelist) {
        if ($RegEx) {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    if ($file -match $whitelist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -in $whitelist) {
                        $file
                    }
                }   
            }
        }
    }
    elseif ($blacklist) {
        if ($RegEx) {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    if ($file -notmatch $blacklist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = . {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -notin $black) {
                        $file
                    }
                }   
            }
        }
    }

    if (!$filelist) { return }
    foreach ($input in $FileList) {
        $SourceFile = @{}
        $SourceFile.Name = $input
        $SourceFile.FileName = [System.IO.Path]::GetFileName($input)
        $SourceFile.BaseName = [System.IO.Path]::GetFileNameWithoutExtension($input).TrimEnd()
        $SourceFile.Extension = [System.IO.Path]::GetExtension($input)

        $DestFolder = $destination
        if (!(Test-Path -LiteralPath $destination -PathType Container)) {
            New-Item $destination -ItemType Directory | Out-Null
        }
        $DestFile = [System.IO.Path]::Combine($DestFolder, $SourceFile.FileName)
        $newDest = $DestFolder
        if (Test-Path $DestFile -PathType Leaf) {
            for ($i = 2; ; $i++) {
                $newDest = ([System.IO.Path]::Combine($DestFolder, ($SourceFile.BaseName + " ($i)" + $SourceFile.Extension)))
                if (!(Test-Path $newDest -PathType Leaf)) {
                    Write-Warning "`"$DestFile`" already exists in the destination. File will be renamed."
                    break
                }
            }
        }
        if ($Move) {
            Write-Host -Separator '' "[Move]`t `"", $SourceFile.Name, '" to "', ($newDest -replace '/', '\'), '"'
            Move-Item -LiteralPath $SourceFile.Name $newDest
        }
        else {
            Write-Host -Separator '' "[Copy]`t `"", $SourceFile.Name, '" to "', ($newDest -replace '/', '\'), '"'
            Copy-Item -LiteralPath $SourceFile.Name $newDest
        }
    }
    Write-Host 'Finished organizing.' 
}
#endregion File managing

#region Merging/splitting files
function Split-File {
    <#
    .SYNOPSIS
    Makes a new file out of another by copying only a specific area.
    .LINK
    Merge-File
    Split-CueBin
    .NOTES
    If you want to split up a binary CD-Image use Split-CueBin, as that will calculate the splits from a cue sheet and also generate a new cue sheet.
    #>
    [CmdletBinding()]
    param(
        # The source file to get the data from.
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipeline, Position = 0)] [string]$fileIn,
        # Name and path of the new file. Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$fileOut,
        # Starting position of the area to copy in bytes (from start of the file).
        [int]$start = 0,
        # Size of the area to copy in bytes (bytes from starting position).
        [Parameter(Mandatory)] [int]$size
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    Process {
        if (Test-Path -Path $fileOut -PathType Leaf) {
            Write-Error "$fileOut already exists."
            return
        }
        $destination = [System.IO.Path]::GetDirectoryName($fileOut)
        if (!(Test-Path -LiteralPath $destination -PathType Container)) {
            New-Item $destination -ItemType Directory | Out-Null
        }
        $read = [System.IO.File]::OpenRead($fileIn)
        $write = [System.IO.File]::OpenWrite($fileOut)
        $buffer = New-Object Byte[] 131072
        $BytesToRead = $size
        [void]$read.seek($start, 0)
        while ($BytesToRead -gt 0) {
            if ($BytesToRead -lt $buffer.Count) {
                $n = $read.read($buffer, 0, $BytesToRead)
                [void]$write.write($buffer, 0, $BytesToRead)
            }
            else {
                $n = $read.read($buffer, 0, $buffer.Count)
                [void]$write.write($buffer, 0, $buffer.Count)
            }
            if ($n -eq 0) { break }
            $BytesToRead = $BytesToRead - $n
        }
        $read.close()
        $write.close()
    
    }
    end {
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
function Merge-File {
    <#
    .SYNOPSIS
    Merge multiple files to on file by appending the raw data to the previous file.
    .LINK
    Split-File
    Merge-CueBin
    .NOTES
    If you want to merge a binary CD-Image use Merge-CueBin, as that will calculate the splits from a cue sheet and also generate a new cue sheet.
    #>
    [CmdletBinding()]
    param(
        # Array of files paths to merge together (same order as in the array). E.g. @('test1.bin', 'Test2.bin', 'Test3.bin')
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })][Parameter(ValueFromPipeline)] [string[]]$fileIn,
        # Name and path of the new merged file. Won't overwrite existing files.
        [Parameter(Mandatory)] [string]$fileOut
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
        if (Test-Path -Path $fileOut -PathType Leaf) {
            Write-Error "$fileOut already exists."
            return
        }
        $destination = [System.IO.Path]::GetDirectoryName($fileOut)
        if (!(Test-Path -LiteralPath $destination -PathType Container)) {
            New-Item $destination -ItemType Directory | Out-Null
        }
        $write = [System.IO.File]::OpenWrite($fileOut)
    }
    Process {
        foreach ($file in $filein) {

            $read = [System.IO.File]::OpenRead($file)
            [void]$read.CopyTo($write, 131072)
        }
        $read.close()
    }
    end {
        $write.close()
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
#endregion Merging/splitting files

#region Cue sheets
function ConvertFrom-Cue {
    <#
    .SYNOPSIS
    Converts a Cue sheet formatted string to a collection of CueFile objects.
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
        $cueSheet = [CueSheet]::new()
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
                    $cueSheet.Files += [CueFile]@{
                        FileName = $line[1]
                        FileType = $line[2]
                    }
                    :TrackLoop for ($i++; $i -lt $cueTxt.count; $i++) {
                        $line = $cueTxt[$i].trim() -split '\s+(?=(?:[^"]|"[^"]+")+$)'
                        switch ($line[0]) {
                            'Track' { 
                                $cueSheet.Files[$FileNo].Tracks += [CueTrack]@{
                                    Number   = $line[1]
                                    DataType = $line[2]
                                }
                                :IndexLoop for ($i++; $i -lt $cueTxt.count; $i++) {
                                    $line = $cueTxt[$i].trim() -split '\s+(?=(?:[^"]|"[^"]+")+$)'
                                    switch ($line[0]) {
                                        'Index' {
                                            $cueSheet.Files[$FileNo].Tracks[$TrackNo].Indexes += [CueIndex]@{
                                                Number = $line[1]
                                                Offset = [CueTime]$line[2]
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
                'Rem' { continue }
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
    Converts a collection of CueFile objects to a Cue sheet string.
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
        If ($InputObject.Catalog) { "CATALOG $($InputObject.Catalog)" }
        If ($InputObject.CDTextFile) { "CDTEXTFILE `"$($InputObject.CDTextFile)`"" }
        If ($InputObject.Performer) { "PERFORMER `"$($InputObject.Performer)`"" }
        If ($InputObject.Title) { "TITLE `"$($InputObject.Title)`"" }
        If ($InputObject.Songwriter) { "SONGWRITER `"$($InputObject.Songwriter)`"" }
        foreach ($file in $InputObject.Files) {
            "FILE $file"
            foreach ($track in $file.Tracks) {
                "  TRACK $track"
                If ($track.ISRC) { "    ISRC $($track.ISRC)" }
                If ($track.Performer) { "    PERFORMER `"$($track.Performer)`"" }
                If ($track.Title) { "    TITLE `"$($track.Title)`"" }
                If ($track.Songwriter) { "    SONGWRITER `"$($track.Songwriter)`"" }
                If ($track.Flags) { "    FLAGS $($track.Flags -join ' ')" }
                If ($track.PreGap) { "    PREGAP $($track.PreGap)" }
                foreach ($index in $track.indexes) {
                    "    INDEX $index"
                }
                If ($track.PostGap) { "    POSTGAP $($track.PostGap)" }
            }
        }
    }
}
function New-CueFromFiles {
    <#
    .SYNOPSIS
    Creates a CueSheet object for a collection of raw bin files.
    #>
    [CmdletBinding()]
    param(
        # Array of file path to .bin files included in the .cue. e.g @(.\Track1.bin, .\Track2.bin) ...
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)][ValidateScript({ Test-Path -Path $_ -PathType Leaf })] [string[]] $SourceFiles
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
        $DataPattern = [byte[]]@(0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0)
        $DreamcastPattern = [byte[]]@(83, 69, 71, 65, 32, 83, 69, 71, 65, 75, 65, 84, 65, 78, 65, 32, 83, 69, 71, 65, 32, 69, 78, 84, 69, 82, 80, 82, 73, 83, 69) #SEGA SEGAKATANA SEGA ENTERPRISE
        $buffer = New-Object Byte[] 352800
        $trackNo = 1
        $cueSheet = [CueSheet]::new()
    }
    Process {
        foreach ($path in $SourceFiles) {
            $inFile = Get-Item $path
            if ($inFile.Length -lt 2352) {
                Write-Error "`"$path`" is too small to be a track!"
                return
            }
            $read = [System.IO.File]::OpenRead($infile)
            $bytesRead = $read.read($buffer, 0, 352800)
            $read.close()
            if (Compare-Object $buffer[0..11] $DataPattern) {
                $DataType = 'AUDIO'
                $silence = $buffer | & { Process {
                        if ($_ -ne [Byte]0) { $false }
                    } end { $true } } | Select-Object -First 1
                if ($bytesRead -ne 352800 -or !$silence ) {
                    Write-Warning "Audio Track $trackNo in `"$path`" has no 2 seconds of silence at the beginning. No raw copy?"
                }
            }
            else {
                if ($buffer[15] -eq 1) {
                    $DataType = 'MODE1/2352'
                }
                elseif ($buffer[15] -eq 2) {
                    $DataType = 'MODE2/2352'
                }
                else {
                    Write-Error "Can't detect Mode of Data Track $trackNo in `"$path`". No raw copy?"
                    return
                }
                if (!(Compare-Object $buffer[16..46] $DreamcastPattern)) {
                    $CueSheet.IsDreamcast = $true
                }
                $silence = $false
            }
            $CueSheet.Files += [CueFile]@{
                FileName = $inFile.Name
                FileType = 'BINARY'

                Tracks   = [CueTrack]@{
                    Number   = $trackNo
                    DataType = $DataType
                    Indexes  = . {
                        if ($silence) {
                            @([CueIndex]@{
                                    Number = 0
                                    Offset = [CueTime]'00:00:00'
                                }, [CueIndex]@{
                                    Number = 1
                                    Offset = [CueTime]'00:02:00'
                                })
                        }
                        else {
                            @([CueIndex]@{
                                    Number = 1
                                    Offset = [CueTime]'00:00:00'
                                })
                        }
                    }
                }
            }
            $trackNo++
        }
    }
    end {
        $CueSheet
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
#endregion Cue sheets

#region Cue/Bin Tools
function Split-CueBin {
    <#
    .SYNOPSIS
    Splits a raw .bin file according to the provided .cue.
    .LINK
    Merge-CueBin
    #>
    [CmdletBinding()]
    param(
        # Splits the files specified in this cue sheet according to the tracks.
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string]$fileIn,
        # Folder where to put in the new cuesheet and split files. Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$destination
    )
    $prevDir = Get-Location
    Set-Location (Split-Path $FileIn)
    $cue = Get-Content -LiteralPath $fileIn -Raw | ConvertFrom-Cue
    if (!$cue) { Write-Error "`"$fileIn`" isn't a valid cue file!"; return }
    $allBinary = $cue.Files.FileType | & { Process {
            if ($_ -ne 'BINARY' -and $_ -ne 'MOTOROLA') { $false } 
        } end { $true } } | Select-Object -First 1
    if (!$allBinary) { Write-Error "`"$fileIn`" Includes files that are not flagged as raw binary. Wrong or corrupt cue sheet?"; return }
    $newcue = [CueSheet]@{
        Catalog    = $cue.Catalog
        CDTextFile = $cue.CDTextFile
        Performer  = $cue.Performer
        Title      = $cue.Title
        Songwriter = $cue.Songwriter
    }

    ForEach ($File in $cue.Files) {
        $fileInfo = Get-Item $file.FileName
        if (!$fileInfo) { Write-Error "Could not find `"$(Join-Path (Split-Path $FileIn) $file.FileName)`". Wrong cue sheet or renamed/moved files?"; return }

        For ($i = 0; $i -lt $File.Tracks.count; $i++) { 
            $curPos = $File.Tracks[$i].Indexes[0].Offset.TotalBytes
            if (($i + 1) -ge $File.Tracks.count) {
                $nextPos = $FileInfo.Length  
            }
            else {
                $nextPos = $File.Tracks[($i + 1)].Indexes[0].Offset.TotalBytes
            }  
            $newName = [System.IO.Path]::Combine($destination, ($fileInfo.BaseName + " (Track $('{0:d2}' -f $File.Tracks[$i].Number))" + $fileInfo.Extension))
            $size = $nextPos - $curPos
            try { Split-File $fileInfo $newName -Start $curPos -size $size -ErrorAction Stop }
            catch { Write-Host 'Error in Split-File:'; Write-Error $_; return }
            $newCue.Files += [CueFile]@{
                FileName = [System.IO.Path]::GetFileName($newName)
                FileType = $File.FileType
                Tracks   = [CueTrack]@{
                    Number     = $File.Tracks[$i].Number
                    DataType   = $File.Tracks[$i].DataType
                    Performer  = $File.Tracks[$i].Performer
                    Title      = $File.Tracks[$i].Title
                    Songwriter = $File.Tracks[$i].Songwriter
                    ISRC       = $File.Tracks[$i].ISRC
                    PreGap     = $File.Tracks[$i].PreGap
                    PostGap    = $File.Tracks[$i].PostGap

                    Indexes    = & { ForEach ($index in $File.Tracks[$i].Indexes) { 
                            [CueIndex]@{
                                Number = $Index.Number
                                Offset = $index.Offset - [CueTime]::FromBytes($curPos)
                            }
                        } }
                }
            }
        }
    }
    Set-Location $prevDir
    $cuecontent = ConvertTo-Cue $newcue
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($destination, [System.IO.Path]::GetFileName($fileIn)), $cuecontent)
    Write-Host 'Done writing files to', $destination
}
function Merge-CueBin {
    <#
    .SYNOPSIS
    Merges multiple raw .bin file according to the provided .cue.
    .LINK
    Split-CueBin
    #>
    [CmdletBinding()]
    param(
        # Merges the file specified in this cue sheet.
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string]$fileIn,
        # New name (and path) for the merged Cue sheet (.bin will get the same name). Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$fileOut
    )
    $prevDir = Get-Location
    Set-Location (Split-Path $FileIn)
    $destination = [System.IO.Path]::GetDirectoryName($fileOut)
    if (!$destination)
    { $destination = '.\' }
    $cue = Get-Content -LiteralPath $fileIn -Raw | ConvertFrom-Cue
    if (!$cue) { Write-Error "`"$fileIn`" isn't a valid cue file!"; return }
    $allBinary = $cue.Files.FileType | & { Process {
            if ($_ -ne 'BINARY' -and $_ -ne 'MOTOROLA') { $false } 
        } end { $true } } | Select-Object -First 1
    if (!$allBinary) { Write-Error "`"$fileIn`" Can't merge images that includes non-binary files."; return }
    $newName = [System.IO.Path]::Combine($destination, ([System.IO.Path]::GetFileNameWithoutExtension($Fileout) + '.bin'))
    $newCue = [CueSheet]@{
        Catalog    = $cue.Catalog
        CDTextFile = $cue.CDTextFile
        Performer  = $cue.Performer
        Title      = $cue.Title
        Songwriter = $cue.Songwriter
        Files      = [CueFile]@{
            FileName = [System.IO.Path]::GetFileName($newName)
            FileType = $Cue.Files[0].FileType
            Tracks   = & {
                ForEach ($File in $cue.Files) {
                    $prevFile += $fileInfo.Length
                    $fileInfo = Get-Item (Join-Path (Split-Path $FileIn) $file.FileName)
                    if (!$fileInfo) { Write-Error "Could not find `"$file`". Wrong cue sheet or renamed/moved files?"; return }

                    ForEach ($track in $File.Tracks) {
                        [CueTrack]@{
                            Number     = $track.Number
                            DataType   = $track.DataType
                            Performer  = $track.Performer
                            Title      = $track.Title
                            Songwriter = $track.Songwriter
                            ISRC       = $track.ISRC
                            PreGap     = $track.PreGap
                            PostGap    = $track.PostGap
                            Indexes    = & { ForEach ($index in $track.Indexes) { 
                                    [CueIndex]@{
                                        Number = $Index.Number
                                        Offset = $index.Offset + [CueTime]::FromBytes($prevFile)
                                    }
                                } }
                        }
                    }
                }
            }
        }
    }
    try { Merge-File $cue.Files.FileName $newName -ErrorAction Stop }
    catch { Write-Host 'Error in Merge-File:'; Write-Error $_; return }
    Set-Location $prevDir
    $cuecontent = ConvertTo-Cue $newcue
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($destination, [System.IO.Path]::GetFileName($fileOut)), $cuecontent)
    Write-Host 'Done writing files to', $destination
}
#endregion Cue/Bin Tools
#endregion Functions