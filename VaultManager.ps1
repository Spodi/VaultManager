[CmdletBinding()]
param (
    [Parameter()][switch]$NoGUI,
    [Parameter(Position = 0)][string]$WorkingDir
)

Clear-Host
$PSScriptRootEsc = $PSScriptRoot -replace '(\?|\*|\[)', '`$1'
if ($WorkingDir) { Push-Location $WorkingDir }

$host.ui.RawUI.WindowTitle = 'VaultManager Console'
Write-Host -ForegroundColor Magenta '##### Vault Manager #####'
Import-Module (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.psm1') -Force

if ($NoGUI) {
    Write-Host 'This is a normal PowerShell session, but with all functions provided by the VaultManager module.'
    Write-Host
    Write-Host 'Loaded additional functions:'
    (Get-Command -Module 'VaultManager' | Format-Wide -Property Name -AutoSize | Out-String).Trim() | Write-Host -ForegroundColor DarkYellow
    Write-Host
    Write-Host 'Type "' -NoNewline
    Write-Host 'Get-Help ' -ForegroundColor Yellow -NoNewline
    Write-Host '<function>' -ForegroundColor DarkYellow -NoNewline
    Write-Host ' -ShowWindow' -ForegroundColor DarkGray -NoNewline
    Write-Host '" to display help for ' -NoNewline
    Write-Host '<function>' -ForegroundColor DarkYellow -NoNewline
    Write-Host ' in an additional window.'
    Write-Host
    return
}

Write-Host -ForegroundColor DarkRed 'Closing this console kills the GUI and any function currently running!'
Write-Host

class ManifestButton {
    [string] $Name
    [string] $Path
}
class VaultManifest {
    [string] $Name
    [string] $Folder
    [int16]  $SortIndex = 0
    [ValidateCount(3, 3)][ManifestButton[]] $Buttons = @([ManifestButton]@{
            Name = 'Start'
            Path = './Start.bat'
        },
        [ManifestButton]@{
            Name = 'Folder'
            Path = './'
        },
        [ManifestButton]@{
            Name = 'Readme'
            Path = './Readme.txt'
        })
}
class VaultCategorySort {
    [string] $Name
    [int16]  $SortIndex = 0
}
class VaultTabManifest : VaultManifest {
    [string] $Color
    [VaultCategorySort[]] $CategorySort
}
class VaultCardManifest : VaultManifest {
    [string] $Category
    [int16]  $CategoryIndex = 0
    [string] $CategoryIcon
    [string] $Icon
}

class WPFTab {
    $Object
    $InnerObject
}
Update-TypeData -TypeName 'WPFTab' -MemberType ScriptProperty -MemberName 'InnerObject' -Value {
    $this.Object.Content.Content.Children
} -Force
class WPFCategory {
    $Object
    $InnerObject
}
Update-TypeData -TypeName 'WPFCategory' -MemberType ScriptProperty -MemberName 'InnerObject' -Value {
    $this.Object.Child.Children[1].Child
} -Force


#region GUI functions
function Show-MessageBox {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]																													[string]	$Message,
        [Parameter(Mandatory = $true)]																													[string]	$Title,
        [Parameter(Mandatory = $false)]	[ValidateSet('OK', 'OKCancel', 'RetryCancel', 'YesNo', 'YesNoCancel', 'AbortRetryIgnore')]						[string]	$Button = 'OK',
        [Parameter(Mandatory = $false)] [ValidateSet('Asterisk', 'Error', 'Exclamation', 'Hand', 'Information', 'None', 'Question', 'Stop', 'Warning')]	[string]	$Icon = 'None'
    )
    begin {
        Add-Type -AssemblyName System.Windows.Forms | Out-Null
        [System.Windows.Forms.Application]::EnableVisualStyles()
    }
    process {
        $button = [System.Windows.Forms.MessageBoxButtons]::$Button
        $icon = [System.Windows.Forms.MessageBoxIcon]::$Icon
    }
    end {
        return [System.Windows.Forms.MessageBox]::Show($Message, $Title, $Button, $Icon)
    }
}
function New-XMLNamespaceManager {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [xml]
        $XmlDocument,
        [string]
        $DefaultNamespacePrefix
    )

    $NsMgr = New-Object -TypeName System.Xml.XmlNamespaceManager -ArgumentList $XmlDocument.NameTable

    $DefaultNamespace = $XmlDocument.DocumentElement.GetAttribute('xmlns')
    if ($DefaultNamespace -and $DefaultNamespacePrefix) {
        $NsMgr.AddNamespace($DefaultNamespacePrefix, $DefaultNamespace)
    }

    $XmlDocument.DocumentElement.Attributes | 
    Where-Object { $_.Prefix -eq 'xmlns' } |
    ForEach-Object {
        $NsMgr.AddNamespace($_.LocalName, $_.Value)
    }

    return , $NsMgr # unary comma wraps $NsMgr so it isn't unrolled
}
#endregion GUI functions
#region VaultApp func
function Get-VaultTabData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)] [string] $Directory,
        [Parameter()] [string] $TabName
    )
    Process {
        if (!(Test-Path -LiteralPath $Directory -PathType Container)) {
            Write-Warning "Non-existent folder: `"$Directory`"."
            return
        }
        if (!$TabName) {
            $AddOns = Get-FileSystemEntries -Directory $Directory
        }
        else {
            $AddOns = $Directory
        }
        if (!$AddOns) {
            Write-Warning "Empty folder or wrong structure: `"$Directory`"."
            return
        }
        $AddOns | & { Process {
                $Data = [VaultTabManifest]@{
                    Folder = $_
                    Name   = Split-Path $_ -Leaf
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
                                If ($manifest.Buttons[$i]) {
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

function Get-VaultAppData {
    [CmdletBinding()]
    param(
        [Parameter()] [string] $TabName,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string] $Folder,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ManifestButton[]] $Buttons,
        [Parameter(ValueFromPipelineByPropertyName)] [VaultCategorySort[]] $CategorySort
    )
    Process {
        if (!(Test-Path $Folder -PathType Container)) {
            Write-Warning "Non-existent folder: `"$Folder`""
            return
        }
        if ($TabName) {
            $tools = Get-FileSystemEntries -Directory $Folder
        }
        else {
            if ($Folder) {
                $tools = Get-FolderSubs $Folder
            }
        }

        if (!$tools) {
            Write-Warning "Empty folder or wrong structure: `"$Folder`"."
            return
        }
        $tools | & { Process {
                $categoryPath = [System.IO.Path]::GetDirectoryName($_)
                $categoryFolder = Split-Path($categoryPath) -Leaf
                #$readmepath = [System.IO.Path]::Combine($_, 'Readme.txt')
                $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')
                $hasFiles = Get-FileSystemEntries $_ | & { Process { if ($_ -NotMatch 'VaultManifest\.json$') { $_ } } } | Select-Object -First 1
                if ($hasFiles.count -lt 1) {
                    Write-Warning "No objects in $_"
                    return
                }
                $Data = [VaultCardManifest]@{
                    Name     = Split-Path $_ -Leaf 
                    Category = $categoryFolder
                    Buttons  = [ManifestButton[]]($Buttons | ConvertTo-Json -Depth 1 | ConvertFrom-Json) # Simplest way to make a deep copy instead of a reference
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
                                If ($manifest.Buttons[$i]) {
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
function Write-VaultManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory, ValueFromPipeline)] [VaultManifest] $ManifestData
    )
    Process {
        
    }
}
#endregion VaultApp func
#region WPF init
$myType = (Add-Type -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.cs') -ReferencedAssemblies (@('PresentationFramework', 'System.Windows.Forms')) -PassThru).Assembly | Sort-Object -Unique

$GUI = [hashtable]::Synchronized(@{}) #Syncronized in case we want parrallel (async) actions that don't lock up the window.
[string]$XAML = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.xaml')) -replace 'mc:Ignorable="d"' -replace '^<Window .*?x:Class=".*?"', '<Window' # This is needed for WPF in PS
[string]$XAML = $XAML -replace '"\/(.*)"', "`"$($PSScriptRoot+'\VaultAssets\')`$1`"" # Hack to make relative paths work for WPF in PS
[string]$XAML = $XAML -replace 'CyberOasis.VaultManager;assembly=', "CyberOasis.VaultManager;assembly=$($myType)" # to make our converter and folder select window work


#Light Theme (currently not implemented)
$LightTheme = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme
if ($LightTheme) {
    $XAML = $XAML -replace 'BasedOn="{StaticResource DarkTheme}"', 'BasedOn="{StaticResource LightTheme}"'
    $XAML = $XAML -replace 'Style="{StaticResource DarkThemeButton}"', 'Style="{StaticResource LightThemeButton}"'
}
#Round corners in win11
if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild -ge 22000) {
    $XAML = $XAML -replace 'Property="CornerRadius" Value="0"', 'Property="CornerRadius" Value="3"' -replace 'Property="CornerRadius" Value="0,0,0,0"', 'Property="CornerRadius" Value="3,3,0,0"'
}
# $xaml | Out-File Debug.xaml 
[xml]$XAML = $XAML

$GUI.NsMgr = (New-XMLNamespaceManager $XAML)
$GUI.WPF = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $XAML) )
#Getting Named GUI elements for easier editing
$GUI.Nodes = $XAML.SelectNodes('//*[@x:Name]', $GUI.NsMgr) | ForEach-Object {
    @{ $_.Name = $GUI.WPF.FindName($_.Name) }
}
#endregion WPF init	

#region VaultApp GUI func
function New-WPFTab {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)] [string]    $Name,
        [Parameter()] [string]    $color = "Orange"
    ) 
    process {
        if ($color) {
            $Tab = [System.Windows.Controls.TabItem]@{
                Header     = $Name
                Foreground = $color
            }
        }
        else {
            $Tab = [System.Windows.Controls.TabItem]@{
                Header = $Name
            }
        }
        $TabScroll = [System.Windows.Controls.ScrollViewer]@{
            VerticalScrollBarVisibility = 'Auto'
        }
        $TabGrid = [System.Windows.Controls.Grid]@{
        }
        $TabWrap = [System.Windows.Controls.WrapPanel]@{
        }

        $TabGrid.AddChild($TabWrap)
        $TabScroll.AddChild($TabGrid)
        $Tab.AddChild($TabScroll)

        return [WPFTab]@{
            Object = $Tab
        }
    }
}

function New-WPFCategory {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)] [string]    $Name,
        [Parameter()] [string] $Icon
    )  
    Process {
        $CategoryBorder = [System.Windows.Controls.Border]@{
            Style = $GUI.WPF.FindResource('UtilitiesCategoryBorder')
        }
        $CategoryPanel = [System.Windows.Controls.StackPanel]@{
            Orientation = 'Vertical'
        }
        $CategoryLabelPanel = [System.Windows.Controls.StackPanel]@{
            Style       = $GUI.WPF.FindResource('UtilitiesCategoryLabelPanel')
            Orientation = 'Horizontal'
        }
        if ($Icon) {
            $CategoryIcon = [System.Windows.Controls.Image]@{
                Height = '32'
                Width  = '32'
                Source = [System.Windows.Media.Imaging.BitmapFrame]::Create($Icon)
            }
        }
        $CategoryLabel = [System.Windows.Controls.Label]@{
            Style   = $GUI.WPF.FindResource('UtilitiesCategoryLabel')
            Content = $Name 
        }
        $CategoryInnerBorder = [System.Windows.Controls.Border]@{
            Style = $GUI.WPF.FindResource('CategoryInnerBorder') 
        }
        $CategoryInnerPanel = [System.Windows.Controls.WrapPanel]@{
            Orientation = 'Horizontal'
        }
        $CategoryBorder.AddChild($CategoryPanel)
        $CategoryPanel.AddChild($CategoryLabelPanel)
        if ($CategoryIcon) { $CategoryLabelPanel.AddChild($CategoryIcon) }
        $CategoryLabelPanel.AddChild($CategoryLabel)
        $CategoryPanel.AddChild($CategoryInnerBorder)
        $CategoryInnerBorder.AddChild($CategoryInnerPanel)
        
        return [WPFCategory]@{
            Object = $CategoryBorder
        }
    }
}

function New-WPFCard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [string]                $Name,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] [ManifestButton[]]      $Buttons,
        [Parameter(ValueFromPipelineByPropertyName)] [string] $Icon
    )
    Process {
        # in CategoryInnerPanel
        $AppOuterBorder = [System.Windows.Controls.Border]@{
            Style = $GUI.WPF.FindResource('UtilitiesCardOuterBorder')
        }
        $AppPanel = [System.Windows.Controls.StackPanel]@{
            Orientation = 'Vertical'
        } 
        $AppLabelPanel = [System.Windows.Controls.StackPanel]@{
            Style       = $GUI.WPF.FindResource('UtilitiesAppLabelPanel')
            Orientation = 'Horizontal'
        }
        if ($Icon) {
            $AppIcon = [System.Windows.Controls.Image]@{
                Height = '16'
                Width  = '16'
                Source = [System.Windows.Media.Imaging.BitmapFrame]::Create($Icon)
            }
        }
        $AppLabel = [System.Windows.Controls.Label]@{
            Style   = $GUI.WPF.FindResource('UtilitiesAppLabel')
            Content = $Name
        }
        $AppInnerBorder = [System.Windows.Controls.Border]@{
            Style = $GUI.WPF.FindResource('CardInnerBorder')  
        }
        $AppButtonPanel = [System.Windows.Controls.Grid]@{
            Style = $GUI.WPF.FindResource('CardButtonPanel')
        }

        if ($Buttons[0] -and (Test-Path -LiteralPath $Buttons[0].path)) {
            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                            Style               = $GUI.WPF.FindResource('MiscOpenButton')
                            Name                = 'MiscOpenButton'  
                            Content             = ($Buttons[0]).Name
                            HorizontalAlignment = 'Left'
                            Tooltip             = ($Buttons[0]).Path.tostring()
                        } } | Add-Member -PassThru 'Path' ($Buttons[0]).Path)) #feels like this shoudn't be possible. but it is!
        }
        if ($Buttons[1] -and (Test-Path -LiteralPath $Buttons[1].path)) {
            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                            Style               = $GUI.WPF.FindResource('MiscOpenButton')
                            Content             = ($Buttons[1]).Name
                            Name                = 'MiscOpenButton'
                            HorizontalAlignment = 'Center'
                            Tooltip             = ($Buttons[1]).Path.tostring()
                        } } | Add-Member -PassThru 'Path' ($Buttons[1]).Path))
        }
        if ($Buttons[2] -and (Test-Path -LiteralPath $Buttons[2].path)) {
            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                            Style               = $GUI.WPF.FindResource('MiscOpenButton')
                            Content             = ($Buttons[2]).Name
                            Name                = 'MiscOpenButton'
                            HorizontalAlignment = 'Right'
                            Tooltip             = ($Buttons[2]).Path.tostring()
                        } } | Add-Member -PassThru 'Path' ($Buttons[2]).Path))
        }

        $AppPanel.AddChild($AppLabelPanel)
        if ($AppIcon) { $AppLabelPanel.AddChild($AppIcon) }
        $AppLabelPanel.AddChild($AppLabel)
        $AppPanel.AddChild($AppInnerBorder)
        $AppInnerBorder.AddChild($AppButtonPanel)
        $AppOuterBorder.AddChild($AppPanel) 
        Write-Output $AppOuterBorder               
    }
}

function Add-VaultAppTab {
    [CmdletBinding()]
    param(
        [Parameter()] [string] $TabName,
        [Parameter(Mandatory)] [string] $Directory
    )
    Process {
        if ($TabName) {
            $TabData = Get-VaultTabData $Directory $TabName | Sort-Object SortIndex, Name
        }
        else {
            $TabData = Get-VaultTabData $Directory | Sort-Object SortIndex, Name
        }

        foreach ($Data in $TabData) { 
            
            if ($TabName) {
                $VaultAppData = $Data | Get-VaultAppData $TabName | Sort-Object CategoryIndex, Category, SortIndex, Name
            }
            else {
                $VaultAppData = $Data | Get-VaultAppData | Sort-Object CategoryIndex, Category, SortIndex, Name
            }
            if (!$VaultAppData) {
                return
            }
            if ($Data.Color) {
                $Tab = New-WPFTab $Data.Name $Data.Color
            }
            else {
                $Tab = New-WPFTab $Data.Name
            }
            $VaultAppData | Group-Object Category | & { Process {
                
                    if ($_.Group.CategoryIcon) {
                        $Category = New-WPFCategory $_.Name -Icon ($_.Group.CategoryIcon | Select-Object -First 1)
                    }
                    else {
                        $Category = New-WPFCategory $_.Name
                    }

                    foreach ($Group in ($_.Group)) {
                        $Category.InnerObject.AddChild(($Group | New-WPFCard))
                    }

                    $Tab.InnerObject.AddChild($Category.Object)
                } }
            $GUI.Nodes.Tabs.AddChild($Tab.Object)
        }      
    }
}
#endregion VaultApp GUI func

#region Code behind
$defaultinput = Join-Path (Get-Location) 'input'
$defaultoutput = Join-Path (Get-Location) 'output'
$defaultbackup = Join-Path (Get-Location) 'backup'
$extensionListPath = (Join-Path $PSScriptRootEsc '.\VaultAssets\FileExtensions.json')

$GUI.Nodes.FolderizeInput.Text = $defaultinput
$GUI.Nodes.InputMerge.Text = Join-Path $defaultinput 'input.cue'
$GUI.Nodes.OutputMerge.Text = Join-Path $defaultoutput 'Merged.cue'
$GUI.Nodes.Outputsplit.Text = $defaultoutput
$GUI.Nodes.FolderizeOutput.Text = $defaultoutput
$GUI.Nodes.Cuegen.Text = $defaultinput
$GUI.Nodes.Backup.Text = $defaultbackup

$extensionListW = @()
if (Test-Path -PathType Leaf -LiteralPath $extensionListPath) {
    $extensionListW = Get-Content -Raw -LiteralPath $extensionListPath | ConvertFrom-Json
}

$GUI.Nodes.ListFolderizeExtWhite.ItemsSource = $extensionListW
$extensionListB = $GUI.Nodes.ListFolderizeExtWhite.ItemsSource.ForEach({
        [Object[]]$out = @($_[0], $true)
        if ($_.count -gt 0) {
            if ($_[1]) {
                [bool]$out[1] = !$_[1]
            }
        }
        Write-Output -NoEnumerate $out
    }) | ForEach-Object { , @($_) } # Don't ask, I don't know myself...
$GUI.Nodes.ListFolderizeExtBlack.ItemsSource = $extensionListB

$RegexW = $GUI.Nodes.ListFolderizeExtWhite.ItemsSource.where({ $_[1] }).ForEach({ ($_[0] -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1') + '$' }) -join '|'
$GUI.Nodes.FolderizeRegexWhite.Text = $RegexW
$RegexB = $GUI.Nodes.ListFolderizeExtBlack.ItemsSource.where({ $_[1] }).ForEach({ ($_[0] -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1') + '$' }) -join '|'
$GUI.Nodes.FolderizeRegexBlack.Text = $RegexB

#Add Auto-Tabs
Add-VaultAppTab -TabName 'Emulators' -Directory (Join-Path $PSScriptRootEsc 'Emulators')
Add-VaultAppTab -Directory (Join-Path $PSScriptRootEsc 'AddOns')

#give anything clickable an event
$GUI.WPF.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]({
            $object = $_
            if ($object.OriginalSource -is [System.Windows.Controls.Button]) {
                switch -CaseSensitive -regex ($object.OriginalSource.Name) {
                    '^MiscOpenButton$' {
                        $path = Resolve-Path $object.OriginalSource.Path
                        if (Test-Path -PathType Leaf -LiteralPath $object.OriginalSource.Path) {
                            $AppStart = $path
                            $AppWorkingDir = Split-Path $path
                        }
                        else {
                            $AppStart = Join-Path $path '\' #Safeguard against executing "Folder.cmd" instead of opening "Folder"
                            $AppWorkingDir = $path
                        }
                        Start-Process $AppStart -WorkingDirectory $AppWorkingDir
                        continue
                    }
                    '^SaveFile_' {
                        $textbox = $_ -creplace '^SaveFile_', ''
                        $objForm = New-Object System.Windows.Forms.SaveFileDialog
                        $objForm.Filter = 'Cue-Sheet|*.cue'
                        if ($GUI.Nodes.($textbox).Text) {
                            $objForm.InitialDirectory = Split-Path $GUI.Nodes.($textbox).Text -Parent
                        }
                        if ($objForm.ShowDialog() -eq 'OK') {
                            $GUI.Nodes.($textbox).Text = $objForm.FileName
                        }
                        continue
                    }
                    '^OpenFile_' {
                        $textbox = $_ -creplace '^OpenFile_', ''
                        $objForm = New-Object System.Windows.Forms.OpenFileDialog
                        $objForm.Filter = 'Cue-Sheet|*.cue'
                        if ($GUI.Nodes.($textbox).Text) {
                            $objForm.InitialDirectory = Split-Path $GUI.Nodes.($textbox).Text -Parent
                        }
                        if ($objForm.ShowDialog() -eq 'OK') {
                            $GUI.Nodes.($textbox).Text = $objForm.FileName
                        }
                        continue
                    }
                    '^Browse_' {
                        $textbox = $_ -creplace '^Browse_', ''
                        $objForm = New-Object CyberOasis.VaultManager.FolderSelectDialog
                        if ($GUI.Nodes.($textbox).Text) {
                            $objForm.InitialDirectory = $GUI.Nodes.($textbox).Text
                        }
                        if ($objForm.Show()) {
                            $GUI.Nodes.($textbox).Text = $objForm.FileName
                        }
                        continue
                    }
                    '^ButtonFolderizeStart$' {
                        $Values = @{
                            Source      = $GUI.Nodes.FolderizeInput.Text
                            Destination = $GUI.Nodes.FolderizeOutput.Text
                            Move        = $GUI.Nodes.FolderizeMove.IsChecked
                            ESDE        = $GUI.Nodes.FolderizeESDE.IsChecked
                        }
                        if ($GUI.Nodes.RadioFolderizeWhitelist.IsChecked) {
                            if ($GUI.Nodes.FolderizeRegex.IsChecked) {
                                $Values.add('RegEx', $true)
                                $Values.add('whitelist', $GUI.Nodes.FolderizeRegexWhite)
                            }
                            else {
                                $Values.add('whitelist', $GUI.Nodes.ListFolderizeExtWhite.ItemsSource.where({ $_[1] }).ForEach({ $_[0] }))
                            }
                        }
                        elseif ($GUI.Nodes.RadioFolderizeBlacklist.IsChecked) {
                            if ($GUI.Nodes.FolderizeRegex.IsChecked) {
                                $Values.add('RegEx', $true)
                                $Values.add('blacklist', $GUI.Nodes.FolderizeRegexBlack)
                            }
                            else {
                                $Values.add('blacklist', $GUI.Nodes.ListFolderizeExtBlack.ItemsSource.where({ $_[1] }).ForEach({ $_[0] }))
                            }

                        }
                        else {
                            $Values.add('all', $true)
                        }
                        if ($GUI.Nodes.RadioFolderize.IsChecked) {
                            Folderize @Values
                        }
                        else {
                            $Values.remove('ESDE')
                            $Values.remove('all')
                            UnFolderize @Values
                        }
                        if ($GUI.Nodes.FolderizeMove.IsChecked -and $GUI.Nodes.FolderizeEmptyFolders.IsChecked) {
                            Remove-EmptyFolders $GUI.Nodes.FolderizeInput.Text
                        }
                        continue
                    }
                    '^ButtonMergeStart$' {
                        $Values = @{
                            fileIn = $GUI.Nodes.InputMerge.Text
                        }
                        if ($GUI.Nodes.RadioMerge.IsChecked) {
                            $Values.add('fileOut', $GUI.Nodes.OutputMerge.Text)
                            Merge-CueBin @Values
                        }
                        else {
                            $Values.add('destination', $GUI.Nodes.OutputSplit.Text)
                            Split-CueBin @Values
                        }
                        continue
                    }
                    '^ButtonCueGenStart$' {
                        $files = Get-FileSystemEntries -File ($GUI.Nodes.CueGen.Text) | Where-Object { [System.IO.Path]::GetExtension($_) -eq '.bin' -or [System.IO.Path]::GetExtension($_) -eq '.raw' }
                        if ($files) {
                            $cuecontent = New-CueFromFiles $files | ConvertTo-Cue
                            if ($cuecontent) {
                                [System.IO.File]::WriteAllLines((Join-Path $GUI.Nodes.CueGen.Text 'GeneratedCue.cue'), $cuecontent) #Cause we don't want BOM, wich can't be disabled in Powershell 5.1 native functions
                                Write-Host "Written $((Join-Path $GUI.Nodes.CueGen.Text 'GeneratedCue.cue'))"
                            }
                            else { Write-Error 'Resulting file was emtpy.' }
                        }
                        else { Write-Error 'No .bin or .raw files in soucre directory.' }
                        continue
                    }
                    '^ButtonBackupStart$' {
                        $datestring = Get-Date -Format 'yyyyMMdd-HHmmss'
                        $filename = "Backup_$datestring.7z"
                        $path = Join-Path $GUI.Nodes.Backup.Text $filename
                        Compress-7z -root $PSScriptRoot $path '*/VaultManifest.json' -Type Text
                    }
                    Default { Write-Host "Unhandled Button: $_" }
                }
            }
            #else { Write-Host "[Debug]`tClicked: $($object.OriginalSource.Name)" }
        }))
$GUI.WPF.AddHandler([System.Windows.Window]::LoadedEvent, [System.Windows.RoutedEventHandler]({
            [void]$GUI.WPF.Activate()
        }))

#endregion Code behind

#[void][WPIA.ConsoleUtils]::ShowWindow($hWnd, $ConsoleMode.MinimizeNoActivate) #will only minimize windows terminal with all its tabs -.-
[void]$GUI.WPF.ShowDialog() #show window - main thread is blocked until closed
Pop-Location
