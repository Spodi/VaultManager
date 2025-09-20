using namespace System.Collections.Generic
using module '.\SpodiUtils.psm1'
using module '.\VaultTypes_old.psm1'

enum VaultMergeType {
    ManifestDefined
    MergeEmpty
    Keep
    Overwrite
}
class VaultBase {
    [string] $Name = ''
    [string] $Icon = ''
    [VaultMergeType] $MergeType = [VaultMergeType]::MergeEmpty
}
Update-TypeData -Force -TypeName 'VaultBase' -DefaultKeyPropertySet @('Name')
class VaultSortable : VaultBase, IComparable {
    [SByte]  $SortIndex = 0

    [int] CompareTo([object]$other) {
        if ($this.SortIndex -eq $other.SortIndex) {
            if ($this.Name -eq $other.Name) {
                return 0
            }
            return $this.Name.CompareTo($other.Name)
        }
        return $this.SortIndex.CompareTo($other.SortIndex)
    }
}
Update-TypeData -Force -TypeName 'VaultSortable' -DefaultKeyPropertySet @('SortIndex', 'Name')
class VaultData {
    [List[VaultTab]] $Tabs = [List[VaultTab]]::new(1)

    VaultData() {}

    VaultData([VaultData_Old[]]$Object) {
   
        foreach ($OldTab in ($Object | Group-Object TabName)) {
            $NewTab = [VaultTab]::new()
            $NewTab.Name = $OldTab.Name
            $NewTab.Color = $OldTab.Group.Color | Select-Object -First 1
            $NewTab.SortIndex = $OldTab.Group.TabIndex | Select-Object -First 1
            $NewTab.Icon = $OldTab.Group.TabIcon | Select-Object -First 1
            $this.Tabs.Add($NewTab)
            foreach ($OldCategory in (($OldTab.Group | Group-Object Category))) {
                $NewCategory = [VaultCategory]::new()
                $NewCategory.Name = $OldCategory.Name
                $NewCategory.Icon = $OldCategory.Group.CategoryIcon | Select-Object -First 1
                $NewCategory.SortIndex = $OldCategory.Group.CategoryIndex | Select-Object -First 1       
                $NewTab.Categories.Add($NewCategory)
                foreach ($OldApp in ($OldCategory.Group)) {
                    $NewApp = [VaultApp]::new()
                    $NewApp.Name = $OldApp.Name
                    $NewApp.Icon = $OldApp.Icon -replace ($OldApp.Folder -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1'), '.\'
                    $NewApp.BasePath = $OldApp.Folder
                    $NewApp.SortIndex = $OldApp.SortIndex    
                    $NewCategory.Apps.Add($NewApp)
                    foreach ($OldButton in ($OldApp.Buttons)) {
                        $NewButton = [VaultAppButton]::new()
                        $NewButton.Name = $OldButton.Name
                        $NewButton.Path = $OldButton.Path -replace ($OldApp.Folder -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1'), '.\'
                        $NewApp.Buttons.Add($NewButton)
                    }
                }
                
            }
            
        }
    }

    VaultData([Object]$Object) {
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -eq 'Tabs') {
                [List[VaultTab]]$this.Tabs = [VaultTab[]]$object.Tabs
            }
            else {
                $this.$Property = $Object.$Property
            }
        }
    }

    static [VaultData] FromManifest([string] $Path) {
        if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
            Write-Warning "Manifest file not found: `"$Path`"."
            return $null
        }
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }

    static [VaultData] FromDirectory([string] $Path) {
        if (!(Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Warning "Directory not found: `"$Path`"."
            return $null
        }
        $Data = [VaultData]::new()
        $Directories = [FileSystemEntries]::Get($Path, [FSEntryType]::Directory, [System.IO.SearchOption]::TopDirectoryOnly)
        foreach ($Tab in  $Directories) {
            $Data.Tabs.Add([VaultTab]::FromDirectory($Tab))
        }
        $Data.Tabs.TrimExcess()
        return $Data
    }



    [void] Merge([VaultData] $other) {
        $this.Merge($other, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined)
    }

    [void] Merge([VaultData] $other, [VaultMergeType] $MergeTypeTabs, [VaultMergeType] $MergeTypeCategories, [VaultMergeType] $MergeTypeApps, [VaultMergeType] $MergeTypeButtons) {
        foreach ($Tab in $other.Tabs) {
            if ($Tab.Name -in $this.Tabs.Name) {
                ($this.Tabs | Where-Object Name -EQ $Tab.Name).Merge($Tab, $MergeTypeTabs, $MergeTypeCategories, $MergeTypeApps, $MergeTypeButtons)    
            }
            else {
                $this.Tabs.Add($Tab)
            }
        }
    }


    [void] Sort () {
        $this.Tabs.Sort()
        foreach ($Tab in $this.Tabs) {
            $Tab.Sort() 
        }
    }

    [void] Cleanup () {
        foreach ($Tab in $this.Tabs.ToArray()) {
            $Tab.Cleanup()
            if ($Tab.Categories.Count -lt 1) {
                $this.Tabs.Remove($Tab)
            }
        }
    }
}
class VaultTab : VaultSortable {
    [string] $Color = ''
    [List[VaultCategory]] $Categories = [List[VaultCategory]]::new(1)

    VaultTab() {}

    VaultTab([Object]$Object) {
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -eq 'Category') {
                [List[VaultCategory]]$this.Categories = [VaultCategory[]]$object.Categories
            }
            else {
                $this.$Property = $Object.$Property
            }
        }
    }
    

    static [VaultTab] FromDirectory([string] $Path) {
        if (!(Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Warning "Directory not found: `"$Path`"."
            return $null
        }
        $Data = [VaultTab]::new()
        $Data.Name = Split-Path $Path -Leaf
        $Directories = [FileSystemEntries]::Get($Path, 'Directory', 'TopDirectoryOnly')
        foreach ($Category in  $Directories) {
            $Data.Categories.Add([VaultCategory]::FromDirectory($Category))
        }
        $Data.Categories.TrimExcess()
        return $Data
    }



    [void] Merge([VaultTab] $other) {
        $this.Merge($other, $other.MergeType)
    }
    [void] Merge([VaultTab] $other, [VaultMergeType] $MergeTypeTabs) {
        $this.Merge($other, $MergeTypeTabs, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined)
    }
    
    [void] Merge([VaultTab] $other, [VaultMergeType] $MergeTypeTabs, [VaultMergeType] $MergeTypeCategories, [VaultMergeType] $MergeTypeApps, [VaultMergeType] $MergeTypeButtons) {
        if ($MergeTypeTabs -eq [VaultMergeType]::ManifestDefined) {
            $MergeTypeTabs = $other.MergeType
            if ($MergeTypeTabs -eq [VaultMergeType]::ManifestDefined) {
                $MergeTypeTabs = [VaultMergeType]::MergeEmpty
            } 
        }
        foreach ($Category in $other.Categories) {
            if ($Category.Name -in $this.Categories.Name) {
                ($this.Categories | Where-Object Name -EQ $Category.Name).Merge($Category, $MergeTypeCategories, $MergeTypeApps, $MergeTypeButtons)
            }
            else {
                $this.Categories.Add($Category)
            }
        }
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -ne 'Categories') {
                switch ($MergeTypeTabs) {
                    ([VaultMergeType]::MergeEmpty) {
                        if (!$this.$Property -and $other.$Property) { $this.$Property = $other.$Property }
                        break
                    }
                    ([VaultMergeType]::Overwrite) {
                        $this.$Property = $other.$Property
                        break
                    }
                    ([VaultMergeType]::Keep) {
                        # Keep own properties
                        break
                    }
                    Default {
                        throw "[VaultTab] Unknown MergeType `"$_`""
                    }
                }
            }
        }
    }
    

    [void] Sort () {
        $this.Categories.Sort()
        foreach ($Category in $this.Categories) {
            $Category.Sort() 
        }
    }

    [void] Cleanup () {
        foreach ($Category in $this.Categories.ToArray()) {
            $Category.Cleanup()
            if ($Category.Apps.Count -lt 1) {
                $this.Categories.Remove($Category)
            }
        }
    }
}

#Update-TypeData  -Force -TypeName 'VaultTab' -MemberType AliasProperty -MemberName 'Folder' -Value 'Path'
class VaultCategory : VaultSortable {
    [List[VaultApp]] $Apps = [List[VaultApp]]::new(1)

    VaultCategory() {}

    VaultCategory([Object]$Object) {
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -eq 'Apps') {
                [List[VaultApp]]$this.Apps = [VaultApp[]]$object.Apps
            }
            else {
                $this.$Property = $Object.$Property
            }
        }
    }
    

    static [VaultCategory] FromDirectory([string] $Path) {
        if (!(Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Warning "Directory not found: `"$Path`"."
            return $null
        }
        $Data = [VaultCategory]::new()
        $Data.Name = Split-Path $Path -Leaf
        $Directories = [FileSystemEntries]::Get($Path, [FSEntryType]::Directory, [System.IO.SearchOption]::TopDirectoryOnly)
        foreach ($App in  $Directories) {
            $Data.Apps.Add([VaultApp]::FromDirectory($App))
        }
        $Data.Apps.TrimExcess()
        return $Data
    }


    [void] Merge([VaultCategory] $other) {
        $this.Merge($other, $other.MergeType)
    }

    [void] Merge([VaultCategory] $other, [VaultMergeType] $MergeTypeCategories) {
        $this.Merge($other, $MergeTypeCategories, [VaultMergeType]::ManifestDefined, [VaultMergeType]::ManifestDefined)
    }
    
    [void] Merge([VaultCategory] $other, [VaultMergeType] $MergeTypeCategories, [VaultMergeType] $MergeTypeApps, [VaultMergeType] $MergeTypeButtons) {
        if ($MergeTypeCategories -eq [VaultMergeType]::ManifestDefined) {
            $MergeTypeCategories = $other.MergeType
            if ($MergeTypeCategories -eq [VaultMergeType]::ManifestDefined) {
                $MergeTypeCategories = [VaultMergeType]::MergeEmpty
            }
        }
        foreach ($App in $other.Apps) {
            if ($App.Name -in $this.Apps.Name) {
                ($this.Apps | Where-Object Name -EQ $App.Name).Merge($App, $MergeTypeApps, $MergeTypeButtons)
            }
            else {
                $this.Apps.Add($App)
            }
        }
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -ne 'Apps') {
                switch ($MergeTypeCategories) {
                    ([VaultMergeType]::MergeEmpty) {
                        if (!$this.$Property -and $other.$Property) { $this.$Property = $other.$Property }
                        break
                    }
                    ([VaultMergeType]::Overwrite) {
                        $this.$Property = $other.$Property
                        break
                    }
                    ([VaultMergeType]::Keep) {
                        # Keep own properties
                        break
                    }
                    Default {
                        throw "[VaultCategory] Unknown MergeType `"$_`""
                    }
                }
            }
        }
    }

    [void] Sort () {
        $this.Apps.Sort()
        foreach ($App in $this.App) {
            $App.Sort() 
        }
    }

    [void] Cleanup () {
        foreach ($App in $this.Apps.ToArray()) {
            $App.Cleanup()
            if ($App.Buttons.Count -lt 1) {
                $this.Apps.Remove($App)
            }
        }
    }
}
class VaultApp : VaultSortable {
    [string] $BasePath = '.\'
    [List[VaultAppButton]]  $Buttons = [List[VaultAppButton]]::new(3)

    VaultApp() {}

    VaultApp([Object]$Object) {
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -eq 'Buttons') {
                [List[VaultAppButton]]$this.Buttons = [VaultAppButton[]]$object.Buttons
            }
            else {
                $this.$Property = $Object.$Property
            }
        }
    }

    static [VaultApp] FromDirectory([string] $Path) {
        if (!(Test-Path -LiteralPath $Path -PathType Container)) {
            Write-Warning "Directory not found: `"$Path`"."
            return $null
        }
        $Data = [VaultApp]::new()
        $Data.Name = Split-Path $Path -Leaf
        $Data.BasePath = $Path
        $Data.Buttons.Add([VaultAppButton]::new())
        return $Data
    }



    [void] Merge([VaultApp] $other) {
        $this.Merge($other, $other.MergeType)
    }

    [void] Merge([VaultApp] $other, [VaultMergeType] $MergeTypeApps) {
        $this.Merge($other, $MergeTypeApps, [VaultMergeType]::ManifestDefined)
    }
    
    [void] Merge([VaultApp] $other, [VaultMergeType] $MergeTypeApps, [VaultMergeType] $MergeTypeButtons) {
        if ($MergeTypeApps -eq [VaultMergeType]::ManifestDefined) {
            $MergeTypeApps = $other.MergeType
            if ($MergeTypeApps -eq [VaultMergeType]::ManifestDefined) {
                $MergeTypeApps = [VaultMergeType]::MergeEmpty
            }
        }
        foreach ($Button in $other.Buttons) {
            if ($Button.Name -in $this.Buttons.Name) {
                ($this.Buttons | Where-Object Name -EQ $Button.Name).Merge($Button, $MergeTypeButtons)
            }
            else {
                $this.Buttons.Add($Button)
            }
        }
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            if ($Property -ne 'Buttons') {
                switch ($MergeTypeApps) {
                    ([VaultMergeType]::MergeEmpty) {
                        if (!$this.$Property -and $other.$Property) { $this.$Property = $other.$Property }
                        break
                    }
                    ([VaultMergeType]::Overwrite) {
                        $this.$Property = $other.$Property
                        break
                    }
                    ([VaultMergeType]::Keep) {
                        # Keep own properties
                        break
                    }
                    Default {
                        throw "[VaultApp] Unknown MergeType `"$_`""
                    }
                }
            }
        }
    }

    [void] Sort () {
        $this.Buttons.Sort()
    }

    [void] Cleanup () {
        foreach ($Button in $this.Buttons.ToArray()) {
            $ButtonPath = Join-Path $this.BasePath ($Button.path -replace '^\.\\', '')
            if (!(Test-Path -LiteralPath $ButtonPath) -or $Button.path -eq '') {
                $this.Buttons.Remove($Button)
            }
        }
    }
}

#Update-TypeData  -Force -TypeName 'VaultApp' -MemberType AliasProperty -MemberName 'Folder' -Value 'BasePath'
class VaultAppButton : IComparable {

    [string] $Name = ''
    [string] $Path = ''
    [SByte]  $SortIndex = 0
    [VaultMergeType] $MergeType = [VaultMergeType]::MergeEmpty

    [int] CompareTo([object]$other) {
        return $this.SortIndex.CompareTo($other.SortIndex)
    }

    [void] Merge([VaultAppButton] $other) {
        $this.Merge($other, $other.MergeType)
    }

    [void] Merge([VaultAppButton] $other, [VaultMergeType] $MergeTypeButtons) {
        if ($MergeTypeButtons -eq [VaultMergeType]::ManifestDefined) {
            $MergeTypeButtons = $other.MergeType
            if ($MergeTypeButtons -eq [VaultMergeType]::ManifestDefined) {
                $MergeTypeButtons = [VaultMergeType]::MergeEmpty
            }
        }
        foreach ($Property in (($this | Get-Member -MemberType Properties).Name)) {
            switch ($MergeTypeButtons) {
                ([VaultMergeType]::MergeEmpty) {
                    if (!$this.$Property -and $other.$Property) { $this.$Property = $other.$Property }
                    break
                }
                ([VaultMergeType]::Overwrite) {
                    $this.$Property = $other.$Property
                    break
                }
                ([VaultMergeType]::Keep) {
                    # Keep own properties
                    break
                }
                Default {
                    throw "[VaultAppButton] Unknown MergeType `"$_`""
                }
            }
        }
    }
}
Update-TypeData -Force -TypeName 'VaultAppButton' -DefaultKeyPropertySet @('SortIndex')