class VaultAppBUtton_Old {
    [string] $Name = ''
    [string] $Path = ''
}
class VaultBase_Old {
    [string] $Name = ''
    [string] $Folder = ''
    [int16]  $SortIndex = 0
    [ValidateCount(3, 3)][VaultAppBUtton_Old[]] $Buttons = @([VaultAppBUtton_Old]@{
            Name = 'Start'
            Path = './Start.bat'
        },
        [VaultAppBUtton_Old]@{
            Name = 'Folder'
            Path = './'
        },
        [VaultAppBUtton_Old]@{
            Name = 'Readme'
            Path = './Readme.txt'
        })
}
class VaultCategorySort {
    [string] $Name = ''
    [int16]  $SortIndex = 0
}
class VaultTab_Old : VaultBase_Old {
    [string] $Color = ''
    [VaultCategorySort[]] $CategorySort
    [string] $Icon = ''
}
class VaultApp_Old : VaultBase_Old {
    [string] $Category = ''
    [int16]  $CategoryIndex = 0
    [string] $CategoryIcon = ''
    [string] $Icon = ''
}
class VaultData_Old : VaultApp_Old {
    [String] $Color = ''
    [String] $TabName = ''
    [int16]  $TabIndex = 0
    [String] $TabIcon = ''
}
function Get-VaultTabData_Old {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [string] $Directory,
        [Parameter()] [string] $TabName
    )
    process {
        if (!(Test-Path -LiteralPath $Directory -PathType Container)) {
            Write-Warning "Non-existent folder: `"$Directory`"."
            return
        }
        if (!$TabName) {
            $AddOns = [FileSystemEntries]::Get($Directory, 'Directory', 'TopDirectoryOnly') 
        }
        else {
            $AddOns = $Directory
        }
        if (!$AddOns) {
            Write-Warning "Empty folder or wrong structure: `"$Directory`"."
            return
        }
        $AddOns | & { process {
                $Data = [VaultTab_Old]@{
                    Folder = $_
                    Name   = Split-Path $_ -Leaf
                    Icon   = $Icon
                }

                $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')

                if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                    $manifest = Get-Content -Raw -LiteralPath $manifestpath | ConvertFrom-Json
                }
                foreach ($Property in ($Data.PSObject.Properties)) {
                    if ($Property.Name -ne 'Buttons') {
                        if ($manifest.($Property.Name)) {
                            $Data.($Property.Name) = $manifest.($Property.Name)
                        }
                    }
                    else {
                        if ($manifest.Buttons) {
                            for ($i = 0; $i -lt 3; $i++) {
                                if ($manifest.Buttons[$i]) {
                                    if ($manifest.Buttons[$i].Name) {
                                        $Data.Buttons[$i].Name = $manifest.Buttons[$i].Name
                                    }
                                    if ($manifest.Buttons[$i].Path) {
                                        $Data.Buttons[$i].Path = $manifest.Buttons[$i].Path
                                    }
                                }
                            }
                        }  
                    }
                }
                Write-Output $Data
            } }
    } 
}

function Get-VaultAppData_Old {
    [CmdletBinding()]
    param(
        [Parameter()] [string] $TabName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Folder,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [VaultAppBUtton_Old[]] $Buttons,
        [Parameter(ValueFromPipelineByPropertyName)] [VaultCategorySort[]] $CategorySort
    )
    process {
        if (!(Test-Path $Folder -PathType Container)) {
            Write-Warning "Non-existent folder: `"$Folder`""
            return
        }
        if ($TabName) {
            $tools = [FileSystemEntries]::Get($Folder, 'Directory', 'TopDirectoryOnly')
  
        }
        else {
            if ($Folder) {
                $tools = [FileSystemEntries]::Get($Folder, 'Directory', 'TopDirectoryOnly') | & { process {
                        [FileSystemEntries]::Get($_, 'Directory', 'TopDirectoryOnly')
                    } }
            }
        }

        if (!$tools) {
            Write-Warning "Empty folder or wrong structure: `"$Folder`"."
            return
        }
        $tools | & { process {
 
                $categoryPath = [System.IO.Path]::GetDirectoryName($_)
                $categoryFolder = Split-Path($categoryPath) -Leaf
                #$readmepath = [System.IO.Path]::Combine($_, 'Readme.txt')
                $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')
                $hasFiles = [FileSystemEntries]::Get($_) | & { process { if ($_ -notmatch 'VaultManifest\.json$') { $_ } } } | Select-Object -First 1
                if ($hasFiles.count -lt 1) {
                    Write-Warning "No objects in $_"
                    return
                }
                $Data = [VaultApp_Old]@{
                    Name     = Split-Path $_ -Leaf 
                    Category = $categoryFolder
                    Folder   = $_
                    Buttons  = [VaultAppBUtton_Old[]]($Buttons | ConvertTo-Json -Depth 1 | ConvertFrom-Json) # Simplest way to make a deep copy instead of a reference
                }
                $CurrentFolder = $_
                $Data.Buttons.ForEach( { $_.Path = Join-Path $CurrentFolder ($_.Path -replace '^\./|^\.\\', '') })
    
                $manifest = $null
                if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                    $manifest = Get-Content -Raw -LiteralPath $manifestpath | ConvertFrom-Json
                }
                foreach ($Property in ($Data.PSObject.Properties)) {
                    if ($Property.Name -ne 'Buttons') {
                        if ($manifest.($Property.Name)) {
                            $Data.($Property.Name) = $manifest.($Property.Name)
                        }
                    }
                    else {
                        if ($manifest.Buttons) {
                            for ($i = 0; $i -lt 3; $i++) {
                                if ($manifest.Buttons[$i]) {
                                    if ($manifest.Buttons[$i].Name) {
                                        $Data.Buttons[$i].Name = $manifest.Buttons[$i].Name
                                    }
                                    if ($manifest.Buttons[$i].Path) {
                                        $Data.Buttons[$i].Path = Join-Path $_ ($manifest.Buttons[$i].Path -replace '^\./|^\.\\', '')
                                    }
                                }
                            }
                        }  
                    }
                }
                
                if ($Data.Icon) {
                    $Data.Icon = Join-Path $_ ($Data.Icon -replace '^\./|^\.\\', '') 
                }
                if ($Data.CategoryIcon) {
                    $Data.CategoryIcon = Join-Path $CurrentFolder ($Data.CategoryIcon -replace '^\./|^\.\\', '') 
                }
                $Data.CategoryIndex = ($CategorySort | Where-Object 'Name' -EQ $Data.Category | Select-Object -First 1).SortIndex
                Write-Output $Data
            } }
    }
}