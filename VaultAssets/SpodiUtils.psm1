using namespace System.Collections.Generic
[Flags()] enum FSEntryType {
    None = 0
    File = 1
    Directory = 2
    All = 3
}

enum SearchOption {
    TopDirectoryOnly = 0
    AllDirectories = 1
}
class FileSystemEntries {
   
    static [List[string]] Get([string]$Path) {
        return [FileSystemEntries]::Get($Path, [FSEntryType]::All, [SearchOption]::TopDirectoryOnly)
    }

    static [List[string]] Get([string]$Path, [FSEntryType]$FSEntryType) {
        return [FileSystemEntries]::Get($Path, $FSEntryType, [SearchOption]::TopDirectoryOnly)
    }
        
    static [List[string]] Get([string]$Path, [FSEntryType]$FSEntryType, [SearchOption]$SearchOption) {
        $prevDir = [System.IO.Directory]::GetCurrentDirectory()
        [System.IO.Directory]::SetCurrentDirectory((Get-Location))
        $Queue = [System.Collections.Queue]@()
        $Output = [List[string]]::new()
        $Queue.Enqueue($Path)
        while ($Queue.count -gt 0) {
            try {
                $Current = $Queue.Dequeue()
                [System.IO.Directory]::EnumerateDirectories($Current) | & { process {
                        if ($FSEntryType.HasFlag([FSEntryType]::Directory) ) { $Output.Add($_ + [System.IO.Path]::DirectorySeparatorChar) }
                        if ($SearchOption) { $Queue.Enqueue($_) }
                    } }
                if ($FSEntryType.HasFlag([FSEntryType]::File)) { $Output.AddRange([System.IO.Directory]::EnumerateFiles($Current)) }
            }
            catch [System.Management.Automation.RuntimeException] {
                $catchedError = $_
                switch ($catchedError.Exception.InnerException.GetType().FullName) {
                    'System.UnauthorizedAccessException' { Write-Warning $catchedError.Exception.InnerException.Message }
                    'System.Security.SecurityException' { Write-Warning $catchedError.Exception.InnerException.Message }
                    default {
                        throw $catchedError
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
    } else {
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
        [FileSystemEntries]::Get($Path, 'Directory', 'TopDirectoryOnly') | & { process {
                [FileSystemEntries]::Get($_, 'Directory', 'TopDirectoryOnly') | Write-Output
            } }
    }
}