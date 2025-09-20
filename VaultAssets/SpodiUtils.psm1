using namespace System.Collections.Generic

[Flags()] enum FSEntryType {
    None = 0
    File = 1
    Directory = 2
    All = 3
}

class FileSystemEntries {
   
    static [IEnumerable[string]] Get([string]$Path) {
        return [FileSystemEntries]::Get($Path, '*', [FSEntryType]::All, [System.IO.SearchOption]::TopDirectoryOnly)
    }

    static [IEnumerable[string]] Get([string]$Path, [string]$SearchPattern) {
        return [FileSystemEntries]::Get($Path, $SearchPattern, [FSEntryType]::All, [System.IO.SearchOption]::TopDirectoryOnly)
    }
    static [IEnumerable[string]] Get([string]$Path, [FSEntryType]$FSEntryType) {
        return [FileSystemEntries]::Get($Path, '*', $FSEntryType, [System.IO.SearchOption]::TopDirectoryOnly)
    }
    static [IEnumerable[string]] Get([string]$Path, [System.IO.SearchOption]$SearchOption) {
        return [FileSystemEntries]::Get($Path, '*', [FSEntryType]::All, $SearchOption)
    }

    static [IEnumerable[string]] Get([string]$Path, [string]$SearchPattern, [FSEntryType]$FSEntryType) {
        return [FileSystemEntries]::Get($Path, $SearchPattern, $FSEntryType, [System.IO.SearchOption]::TopDirectoryOnly)
    }
    static [IEnumerable[string]] Get([string]$Path, [string]$SearchPattern, [System.IO.SearchOption]$SearchOption) {
        return [FileSystemEntries]::Get($Path, $SearchPattern, [FSEntryType]::All, $SearchOption)
    }

    static [IEnumerable[string]] Get([string]$Path, [FSEntryType]$FSEntryType, [System.IO.SearchOption]$SearchOption) {
        return [FileSystemEntries]::Get($Path, '*', $FSEntryType, $SearchOption)
    }
        
    static [IEnumerable[string]] Get([string]$Path, [string]$SearchPattern, [FSEntryType]$FSEntryType, [System.IO.SearchOption]$SearchOption) {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))

        if ($SearchOption -eq [System.IO.SearchOption]::TopDirectoryOnly) {
            switch ($FSEntryType) {
                ([FSEntryType]::Directory) {
                    return [List[string]]([System.IO.Directory]::EnumerateDirectories($Path, $SearchPattern) | ForEach-Object { $_ + [System.IO.Path]::DirectorySeparatorChar })
                }
                ([FSEntryType]::File) {
                    return [System.IO.Directory]::EnumerateFiles($Path, $SearchPattern)
                }
            }
        }

        $Queue = [System.Collections.Queue]@()
        $Output = [List[string]]::new()
        $Queue.Enqueue($Path)
        while ($Queue.count -gt 0) {
            try {
                $Current = $Queue.Dequeue()
                [System.IO.Directory]::EnumerateDirectories($Current, $SearchPattern) | & { process {
                        if ($FSEntryType.HasFlag([FSEntryType]::Directory) ) { $Output.Add($_ + [System.IO.Path]::DirectorySeparatorChar) }
                        if ($SearchOption) { $Queue.Enqueue($_) }
                    } }
                if ($FSEntryType.HasFlag([FSEntryType]::File)) { $Output.AddRange([System.IO.Directory]::EnumerateFiles($Current, $SearchPattern)) }
            }
            catch [System.Management.Automation.RuntimeException], [System.Management.Automation.MethodInvocationException] {
                $catchedError = $_
                switch ($catchedError.Exception.InnerException.GetType().FullName) {
                    'System.UnauthorizedAccessException' { Write-Warning $catchedError.Exception.InnerException.Message }
                    'System.Security.SecurityException' { Write-Warning $catchedError.Exception.InnerException.Message }
                    'System.IO.DirectoryNotFoundException' { Write-Warning $catchedError.Exception.InnerException.Message }
                    default {
                        throw
                    }
                }
            }    
        }

        [System.IO.Directory]::SetCurrentDirectory($prevDir)
        if ($Output.Count -eq 0) {
            return $null
        }
        $Output.TrimExcess()
        return $Output
    }
}


function Get-FileSystemEntries {
    <#
    .NOTES
    #Deprecated
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [string] $Path,
        [Parameter()] [switch] $File,
        [Parameter()] [switch] $Directory,
        [Parameter()] [switch] $Recurse
    )

    $EntryType = 0
    $SearchOption = 0
    if ($File) {
        $EntryType = $EntryType + [FSEntryType]::File
    }
    if ($Directory) {
        $EntryType = $EntryType + [FSEntryType]::Directory
    }
    if (!$File -and !$Directory) {
        $EntryType = [FSEntryType]::All
    }
    if ($Recurse) {
        $SearchOption = [SearchOption]::AllDirectories
    }
    else {
        $SearchOption = [SearchOption]::TopDirectoryOnly
    }
    [FileSystemEntries]::Get($Path, $EntryType, $SearchOption) 
}
function Get-FolderSubs {
    <#
    .NOTES
    #Deprecated
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]  [string] $Path
    )
    process {
        [FileSystemEntries]::Get($Path, [FSEntryType]::Directory, [SearchOption]::TopDirectoryOnly) | & { process {
                [FileSystemEntries]::Get($_, [FSEntryType]::Directory, [SearchOption]::TopDirectoryOnly) | Write-Output
            } }
    }
}