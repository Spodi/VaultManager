using module '.\Cue.psm1'
function Get-7zip {
    if ((Test-Path (Join-Path $PSScriptRoot '7z.exe') -PathType Leaf) -and (Test-Path (Join-Path $PSScriptRoot '7z.dll') -PathType Leaf)) {
        return (Join-Path $PSScriptRoot '7z.exe')
    }
    if ((Test-Path (Join-Path $PSScriptRoot '7za.exe') -PathType Leaf)) {
        return (Join-Path $PSScriptRoot '7za.exe')
    }
    if (Test-Path 'Registry::HKEY_CURRENT_USER\Software\7-Zip') {
        $path = (Get-ItemProperty 'Registry::HKEY_CURRENT_USER\Software\7-Zip').Path64
        if (!$path) {
            $path = (Get-ItemProperty 'Registry::HKEY_CURRENT_USER\Software\7-Zip').Path 
        }
        if ((Test-Path (Join-Path $path '7z.exe') -PathType Leaf) -and (Test-Path (Join-Path $path '7z.dll') -PathType Leaf)) {
            return (Join-Path $path '7z.exe')
        }
    }  
    if (Test-Path 'Registry::HKEY_LOCAL_MACHINE\Software\7-Zip') {
        $path = (Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\Software\7-Zip').Path64
        if (!$path) {
            $path = (Get-ItemProperty 'Registry::HKEY_LOCAL_MACHINE\Software\7-Zip').Path 
        }
        if ((Test-Path (Join-Path $path '7z.exe') -PathType Leaf) -and (Test-Path (Join-Path $path '7z.dll') -PathType Leaf)) {
            return (Join-Path $path '7z.exe')
        }
    }
}

function Compress-7z {
    [CmdletBinding(PositionalBinding = $false)]
    param (
        [Parameter(Mandatory, ParameterSetName = 'simple', Position = 0)][Parameter(Mandatory, ParameterSetName = 'advanced', Position = 0)]   [string] $DestinationPath,
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'simple', Position = 1)][Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'advanced', Position = 1)]   [string[]] $path,
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'advanced')][AllowEmptyString()]   [string] $type,
        [Parameter(ParameterSetName = 'simple')][Parameter(ParameterSetName = 'advanced')]   [string] $root,
        [Parameter(ParameterSetName = 'simple')][Parameter(ParameterSetName = 'advanced')]   [switch] $nonSolid
    ) 

    begin {
        if (![System.IO.Path]::IsPathRooted($DestinationPath)) {
            $DestinationPath = Join-Path (Get-Location) $DestinationPath
        }
        $7zip = Get-7zip
        if (!$7zip) {
            Write-Error 'No 7zip found!'
            break
        }
        if (!$root) {
            $root = '.'
        }
        if ($nonSolid) {
            $solid = 'off'
        }
        else {
            $solid = 'on'
        }
        $list = [System.Collections.ArrayList]::new()
    }
    process {
        [void]$List.add((
                [PSCustomObject]@{
                    Path = $path
                    Type = $type
                }
            ))
    }
    end {
        $list = $list | Group-Object Type
        $i = 0
        $ProgressParameters = @{
            Activity        = 'Compressing'
            Status          = "$i / $($List.count)"
            PercentComplete = ($i * 100 / $List.count)
        }
        Write-Progress @ProgressParameters

        foreach ($fileType in $List) {
            switch ($filetype.name) {
                'CD-Audio' { $options = '-mf=Delta:4 -m0=LZMA:x9:mt2:d1g:lc1:lp2'; break } 
                'Text' { $options = '-m0=PPmD:x9:o16'; break }
                'Binary' { $options = '-m0=LZMA:mt2:x9:d1g'; break }
                Default { $options = '-m0=LZMA:mt2:x9:d1g'; break }  
            }
            $files = "`"$($fileType.Group.path -join '" "')`""
            $Process = Start-Process -PassThru -Wait -WorkingDirectory $root -FilePath $7zip -ArgumentList @('a', '-r0', '-mqs', "-ms=$solid", $options, "`"$DestinationPath`"", $files)
            
            if ($Process.ExitCode -ne 0) {
                Write-Progress @ProgressParameters -Completed
                Write-Error "7zip aborted with an Exit-Code of $($Process.ExitCode)."
                return
            }

            $i++
            $ProgressParameters = @{
                Activity        = 'Compressing'
                Status          = "$i / $($List.count)"
                PercentComplete = ($i * 100 / $List.count)
            }
            Write-Progress @ProgressParameters
        }
        Write-Progress @ProgressParameters -Completed
    }

}
#endregion

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
        [switch]    $Move,
        [Parameter(ParameterSetName = 'white')] [Parameter(ParameterSetName = 'black')] [Parameter(ParameterSetName = 'all')]
        [switch]    $ESDE
    )

    Write-Host -NoNewline 'Retrieving file list, this can take a while... '
    $SourceFiles = Get-Files $source
    Write-Host 'Done'

    if ($all) {
        $FileList = $SourceFiles
    }
    elseif ($whitelist) {
        if ($RegEx) {
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    if ($file -match $whitelist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = & {
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
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    if ($file -notmatch $blacklist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -notin $blacklist) {
                        $file
                    }
                }   
            }
        }
    }
    
    if (!(Test-Path -LiteralPath $destination -PathType Container)) {
        New-Item $destination -ItemType Directory | Out-Null
    }
    if (!$FileList) { return }
    
    $FileList = $FileList | & { Process {
            # Remove file extension for the new folder name. Will fail on "nameless" files, like .htaccess
            # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
            $List = [PSCustomObject]@{
                Name        = $_
                FileName    = [System.IO.Path]::GetFileName($_)
                BaseName    = [System.IO.Path]::GetFileNameWithoutExtension($_).TrimEnd()
                Extension   = [System.IO.Path]::GetExtension($_)
                ID          = $null
                Main        = $false
                CleanedName = $null
                DestFolder  = $null
            }
            # also remove the Disc tag e.g. "(Disc 1)" at the end, to get all discs in one folder
            
            $List.CleanedName = ($List.BaseName -replace '\s*\((?:Disc|Track) \d?\d(?: of \d?\d)?\)', '' -replace '\.part\d', '' -replace '\[(?:(?:(?:[\da-f]){16})|(?:v\d*)|N?(?:(?:KA)|[CT])|DLC|UPD)]', '' -replace '\s\s+', ' ').Trim()
            if (($List.Extension -eq '.nsp') -or ($List.Extension -eq '.xci')) {
                if ($List.BaseName -match '\[(?:[\da-f]){16}]') {
                    $ID = $Matches.0 -replace '\[', '' -replace ']', ''
                    $List.ID = ([int64]::parse($ID, 'HexNumber') -band 0xFFFFFFFFFFFFE000).ToString("X16")
                    if ($ID -eq $List.ID) {
                        $List.Main = $true
                    }
                }
            }
            $List
        } } | Group-Object ID | & { Process { 
            $ShortestName = ($_.Group | Sort-Object { $_.CleanedName.Length } | Select-Object -First 1).CleanedName
            $_.Group | & { Process {
                    $_.CleanedName = $ShortestName
                    $_
                } }
        } }


    if ($ESDE) {
       
        $FileList = $FileList | Group-Object CleanedName | & { Process {
                $name = $null
                if ($_.count -gt 1) {

                    foreach ($file in $_.Group) {
                        if ($file.Extension -eq '.m3u') {
                            $name = $file.FileName
                            break
                        }
                        elseif ($file.Extension -eq '.gdi') {
                            $name = $file.FileName
                            break
                        }
                        elseif ($file.Extension -eq '.cue') {
                            $name = $file.FileName
                            break
                        }
                        elseif ((($file.Extension -eq '.nsp') -or ($file.Extension -eq '.xci')) -and $file.Main) {
                            Write-host 'a'
                            $name = $file.FileName
                            break
                        }
                    } 
                }
                
                # Join-Path doesn't have -LiteralPath, so use the .Net version instead...
                if ($name) {
                    $_.Group | & { Process { $_.DestFolder = [System.IO.Path]::Combine($destination, $name) } }
                }
                else {
                    $_.Group | & { Process { $_.DestFolder = $destination } }
                }
                $_.Group
            } } 
    }
    else {
        $Filelist = $Filelist | & { Process {
                $_.DestFolder = ([System.IO.Path]::Combine($destination, $_.CleanedName))
                $_
            } }
    }

    if (!$filelist) { return }

    $i = 0
    $ProgressParameters = @{
        Activity        = 'Folderize'
        Status          = "$i / $(@($FileList).count) Items"
        PercentComplete = ($i * 100 / @($FileList).count)
    }
    Write-Progress @ProgressParameters

    foreach ($SourceFile in $FileList) {


        if (!(Test-Path -LiteralPath $SourceFile.DestFolder -PathType Container)) {
            New-Item $SourceFile.DestFolder -ItemType Directory | Out-Null
        }
        # Join-Path doesn't have -LiteralPath, so use the .Net version instead...
        $DestFile = [System.IO.Path]::Combine($SourceFile.DestFolder, $SourceFile.FileName)
        $newDest = $SourceFile.DestFolder
        if (Test-Path -LiteralPath $DestFile -PathType Leaf) {
            for ($j = 2; ; $j++) {
                $newDest = ([System.IO.Path]::Combine($SourceFile.DestFolder, ($SourceFile.BaseName + " ($j)" + $SourceFile.Extension)))
                if (!(Test-Path -LiteralPath $newDest -PathType Leaf)) {
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
        $i++
        $ProgressParameters = @{
            Activity        = 'Folderize'
            Status          = "$i / $(@($FileList).count) Items"
            PercentComplete = ($i * 100 / @($FileList).count)
        }
        Write-Progress @ProgressParameters
    }
    Write-Progress @ProgressParameters -Completed
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
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    if ($file -match $whitelist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = & {
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
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    if ($file -notmatch $blacklist) {
                        $file
                    }
                }   
            }
        }      
        else {
            $FileList = & {
                foreach ($file in $SourceFiles) {
                    # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
                    if ([System.IO.Path]::GetExtension($file) -notin $blacklist) {
                        $file
                    }
                }   
            }
        }
    }

    if (!$filelist) { return }

    $i = 0
    $ProgressParameters = @{
        Activity        = 'Unfolderize'
        Status          = "$i / $(@($FileList).count) Items"
        PercentComplete = ($i * 100 / @($FileList).count)
    }
    Write-Progress @ProgressParameters

    foreach ($input in $FileList) {
        # Remove file extension for the new folder name. Will fail on "nameless" files, like .htaccess
        # We don't want to use Get-Item here, as that reads every file with much more metadata than we need.
        $SourceFile = [PSCustomObject]@{
            Name       = $input
            FileName   = [System.IO.Path]::GetFileName($input)
            BaseName   = [System.IO.Path]::GetFileNameWithoutExtension($input).TrimEnd()
            Extension  = [System.IO.Path]::GetExtension($input)
            DestFolder = $destination
        }

        if (!(Test-Path -LiteralPath $SourceFile.DestFolder -PathType Container)) {
            New-Item $SourceFile.DestFolder -ItemType Directory | Out-Null
        }
        # Join-Path doesn't have -LiteralPath, so use the .Net version instead...
        $DestFile = [System.IO.Path]::Combine($SourceFile.DestFolder, $SourceFile.FileName)
        $newDest = $SourceFile.DestFolder
        if (Test-Path -LiteralPath $DestFile -PathType Leaf) {
            for ($j = 2; ; $j++) {
                $newDest = ([System.IO.Path]::Combine($SourceFile.DestFolder, ($SourceFile.BaseName + " ($j)" + $SourceFile.Extension)))
                if (!(Test-Path -LiteralPath $newDest -PathType Leaf)) {
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
        $i++
        $ProgressParameters = @{
            Activity        = 'Unfolderize'
            Status          = "$i / $(@($FileList).count) Items"
            PercentComplete = ($i * 100 / @($FileList).count)
        }
        Write-Progress @ProgressParameters
    }
    Write-Progress @ProgressParameters -Completed
    Write-Host 'Finished organizing.' 
}
#endregion File managing

#region Merging/splitting file
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
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][Parameter(Mandatory, ValueFromPipeline, Position = 0)] [string]$fileIn,
        # Name and path of the new file. Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$fileOut,
        # Starting position of the area to copy in bytes (from start of the file).
        [uint64]$start = 0,
        # Size of the area to copy in bytes (bytes from starting position).
        [Parameter(Mandatory)] [uint64]$size
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    }
    Process {
        if (Test-Path -LiteralPath $fileOut -PathType Leaf) {
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
        [Parameter(Mandatory)] [string]$fileOut,
        # Ammount of added zeroed bytes at the begnning of the output file.
        [Parameter()] [uint32]$PreGap,
        # Ammount of added zeroed bytes at the end of the output file.
        [Parameter()] [uint32]$PostGap
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
        if (Test-Path -LiteralPath $fileOut -PathType Leaf) {
            Write-Error "$fileOut already exists."
            return
        }
        $destination = [System.IO.Path]::GetDirectoryName($fileOut)
        if (!(Test-Path -LiteralPath $destination -PathType Container)) {
            New-Item $destination -ItemType Directory | Out-Null
        }
        $write = [System.IO.File]::OpenWrite($fileOut)
        if ($PreGap -gt 0) {
            $gap = [byte[]]::new($PreGap)
            [void]$write.write($gap, 0, $PreGap)
        }
    }
    Process {
        foreach ($file in $filein) {

            $read = [System.IO.File]::OpenRead($file)
            [void]$read.CopyTo($write, 131072)
        }
        $read.close()
    }
    end {
        if ($PostGap -gt 0) {
            $gap = [byte[]]::new($PostGap)
            [void]$write.write($gap, 0, $PostGap)
        }
        $write.close()
        [System.IO.Directory]::SetCurrentDirectory($prevDir)
    }
}
#endregion Merging/splitting files

#region Cue sheets

function New-CueFromFiles {
    <#
    .SYNOPSIS
    Creates a CueSheet object for a collection of raw bin files.
    #>
    [CmdletBinding()]
    param(
        # Array of file path to .bin files included in the .cue. e.g @(.\Track1.bin, .\Track2.bin) ...
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)][ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })] [string[]] $SourceFiles
    )
    begin {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
        $DataPattern = [byte[]]@(0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0)
        $DreamcastPattern = [byte[]]@(83, 69, 71, 65, 32, 83, 69, 71, 65, 75, 65, 84, 65, 78, 65, 32, 83, 69, 71, 65, 32, 69, 78, 84, 69, 82, 80, 82, 73, 83, 69) #SEGA SEGAKATANA SEGA ENTERPRISE
        $buffer = New-Object Byte[] 352800
        $trackNo = 1
        $cueSheet = [Cue.Sheet]::new()
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

            if (!(Compare-Object $buffer[16..46] $DreamcastPattern)) {
                $CueSheet.IsDreamcast = $true
            }

            if (Compare-Object $buffer[0..11] $DataPattern) {
                # If no Data, try Dreamcast before Audio
                if (!(Compare-Object $buffer[176400..176411] $DataPattern) -and $cueSheet.IsDreamcast) {
                    if ($buffer[176415] -eq 1) {
                        $DataType = 'MODE1/2352'
                    }
                    elseif ($buffer[176415] -eq 2) {
                        $DataType = 'MODE2/2352'
                    }
                    else {
                        Write-Error "Can't detect Mode of Data Track $trackNo in `"$path`". No raw copy?"
                        return
                    }
                    $DreamcastData = $true
                }
                else {

                    $DataType = 'AUDIO'
                    $silence = $buffer | & { Process {
                            if ($_ -ne [Byte]0) { $false }
                        } end { $true } } | Select-Object -First 1
                    if ($bytesRead -ne 352800 -or !$silence ) {
                        Write-Warning "Audio Track $trackNo in `"$path`" has no 2 seconds of silence at the beginning. No raw copy?"
                    }
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
                $silence = $false
            }
            
            $CueSheet.Files += [Cue.File]@{
                FileName = $inFile.Name
                FileType = 'BINARY'

                Tracks   = [Cue.Track]@{
                    Number   = $trackNo
                    DataType = $DataType
                    Indexes  = . {
                        if ($DreamcastData) {
                            @([Cue.Index]@{
                                    Number = 0
                                    Offset = [Cue.Time]'00:00:00'
                                }, [Cue.Index]@{
                                    Number = 1
                                    Offset = [Cue.Time]'00:03:00'
                                })   
                        }
                        elseif ($silence) {
                            @([Cue.Index]@{
                                    Number = 0
                                    Offset = [Cue.Time]'00:00:00'
                                }, [Cue.Index]@{
                                    Number = 1
                                    Offset = [Cue.Time]'00:02:00'
                                })
                        }
                        else {
                            @([Cue.Index]@{
                                    Number = 1
                                    Offset = [Cue.Time]'00:00:00'
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
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string]$fileIn,
        # Folder where to put in the new cuesheet and split files. Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$destination
    )
    $prevNetDir = [System.IO.Directory]::GetCurrentDirectory()
    [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    Push-Location (Split-Path $FileIn)
    $cue = Get-Content -LiteralPath $fileIn -Raw | ConvertFrom-Cue
    if (!$cue) { Write-Error "`"$fileIn`" isn't a valid cue file!"; return }
    $allBinary = $cue.Files.FileType | & { Process {
            if ($_ -ne 'BINARY' -and $_ -ne 'MOTOROLA') { $false } 
        } end { $true } } | Select-Object -First 1
    if (!$allBinary) { Write-Error "`"$fileIn`" Includes files that are not flagged as raw binary. Wrong or corrupt cue sheet?"; return }
    $newcue = [Cue.Sheet]@{
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
            $newCue.Files += [Cue.File]@{
                FileName = [System.IO.Path]::GetFileName($newName)
                FileType = $File.FileType
                Tracks   = [Cue.Track]@{
                    Number     = $File.Tracks[$i].Number
                    DataType   = $File.Tracks[$i].DataType
                    Performer  = $File.Tracks[$i].Performer
                    Title      = $File.Tracks[$i].Title
                    Songwriter = $File.Tracks[$i].Songwriter
                    ISRC       = $File.Tracks[$i].ISRC
                    PreGap     = $File.Tracks[$i].PreGap
                    PostGap    = $File.Tracks[$i].PostGap

                    Indexes    = & { ForEach ($index in $File.Tracks[$i].Indexes) { 
                            [Cue.Index]@{
                                Number = $Index.Number
                                Offset = $index.Offset - [Cue.Time]::FromBytes($curPos)
                            }
                        } }
                }
            }
        }
    }
    Pop-Location
    $cuecontent = ConvertTo-Cue $newcue
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($destination, [System.IO.Path]::GetFileName($fileIn)), $cuecontent)
    [System.IO.Directory]::SetCurrentDirectory($prevNetDir)
    Write-Host 'Done writing files to', $destination
}
function Merge-CueBin {
    <#
    .SYNOPSIS
    Merges multiple raw .bin files according to the provided .cue.
    .LINK
    Split-CueBin
    #>
    [CmdletBinding()]
    param(
        # Merges the file specified in this cue sheet.
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string]$fileIn,
        # New name (and path) for the merged Cue sheet (.bin will get the same name). Won't overwrite existing files.
        [Parameter(Mandatory, Position = 1)] [string]$fileOut
    )
    $prevNetDir = [System.IO.Directory]::GetCurrentDirectory()
    [System.IO.Directory]::SetCurrentDirectory((Get-Location))
    Push-Location (Split-Path $FileIn)
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
    $newCue = [Cue.Sheet]@{
        Catalog    = $cue.Catalog
        CDTextFile = $cue.CDTextFile
        Performer  = $cue.Performer
        Title      = $cue.Title
        Songwriter = $cue.Songwriter
        Files      = [Cue.File]@{
            FileName = [System.IO.Path]::GetFileName($newName)
            FileType = $Cue.Files[0].FileType
            Tracks   = & {
                ForEach ($File in $cue.Files) {
                    $prevFile += $fileInfo.Length
                    $fileInfo = Get-Item (Join-Path (Split-Path $FileIn) $file.FileName)
                    if (!$fileInfo) { Write-Error "Could not find `"$file`". Wrong cue sheet or renamed/moved files?"; return }

                    ForEach ($track in $File.Tracks) {
                        [Cue.Track]@{
                            Number     = $track.Number
                            DataType   = $track.DataType
                            Performer  = $track.Performer
                            Title      = $track.Title
                            Songwriter = $track.Songwriter
                            ISRC       = $track.ISRC
                            PreGap     = $track.PreGap
                            PostGap    = $track.PostGap
                            Indexes    = & { ForEach ($index in $track.Indexes) { 
                                    [Cue.Index]@{
                                        Number = $Index.Number
                                        Offset = $index.Offset + [Cue.Time]::FromBytes($prevFile)
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
    Pop-Location
    $cuecontent = ConvertTo-Cue $newcue
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($destination, [System.IO.Path]::GetFileName($fileOut)), $cuecontent)
    [System.IO.Directory]::SetCurrentDirectory($prevNetDir)
    Write-Host 'Done writing files to', $destination
}

function Format-CueGaps {
    <#
    .SYNOPSIS
    Formats a Cue/Bin with Pre/Postgaps to one with Index 0 and prepends/appends zeros to the binaries accordingly.
    .LINK
    Merge-File
    #>
    param(
        # Cuesheet to process.
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string] $fileIn,
        # Destination folder for the altered cue/bin files.
        [string] $destination
    )
    Push-Location (Split-Path $FileIn)

    $cue = Get-Content -LiteralPath $fileIn -Raw | ConvertFrom-Cue
    if (!$cue) { Write-Error "`"$fileIn`" isn't a valid cue file!"; return }

    ForEach ($File in $cue.Files) {
        $PreGap = $null

        ForEach ($Track in $File.Tracks) {
            if (@($_.Indexes).Count -eq 1) {
                if ($Track.Pregap -gt 0) {
                    $PreGap = $Track.Pregap
                    $Track.Pregap = 0
                    foreach ($Index in $Track.Indexes) {
                        $index.Number = $index.Number.Number + 1
                        $Index.Offset = $Index.Offset + $PreGap
                    }                    
                    $Track.Indexes = . {
                        [Cue.Index]@{
                            Number = 0
                            Offset = 0
                        }
                        $Track.Indexes
                    }
                }
                if ($Track.PostGap -gt 0) {
                    $PostGap = $Track.PostGap
                    $Track.PostGap = 0
                }
            }
            else { Write-Error "`"$fileIn`" contains a file with multiple tracks. Converting is only possible with one track per file."; return }
        }
        try { Merge-File $File.FileName (Join-Path $destination $File.FileName) -Pregap $Pregap.TotalBytes -PostGap $PostGap.TotalBytes }
        catch { Write-Host 'Error in Merge-File:'; Write-Error $_; return }
        
    }
    $cuecontent = ConvertTo-Cue $cue
    Pop-Location
    [System.IO.File]::WriteAllLines([System.IO.Path]::Combine($destination, [System.IO.Path]::GetFileName($fileIn)), $cuecontent)
    Write-Host 'Done writing files to', $destination
}


function Compress-Disc {
    <#
    .SYNOPSIS
    Compresses a Cue/Bin with 7-Zip and optimized parameters.
    .NOTES
    Requires 7z.exe and 7z.dll in the VaultAssetes folder.
    This is just a silly thing to show that 7-Zip can often still compress such data better than CHD, if done right.
    #>
    param(
        [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })][Parameter(Mandatory, Position = 0)] [string] $fileIn,
        [Parameter(Mandatory, Position = 1)] [string] $fileOut
    )
    $cue = Get-Content -LiteralPath $fileIn -Raw | ConvertFrom-Cue
    if (!$cue) { Write-Error "`"$fileIn`" isn't a valid cue file!"; return }
    $cue.Files | & { Process {
            $test = ($_.Tracks | Group-Object DataType)
            if ($test.count -eq 1 -and $test.Name -eq 'AUDIO') {
                [PSCustomObject]@{
                    Path = $_.FileName
                    Type = 'CD-Audio'
                }
            }
            else {
                [PSCustomObject]@{
                    Path = $_.FileName
                    Type = 'Binary'
                }
            }
        } End {
            [PSCustomObject]@{
                Path = Split-Path $FileIn -Leaf
                Type = 'Text'
            }
        } } | Compress-7z $fileOut -root (Split-Path $FileIn) -nonSolid
}
#endregion Cue/Bin Tools

#endregion Functions
