using namespace System.Collections.Generic
using namespace System.Windows.Controls
using module '.\VaultAssets\VaultTypes.psm1'

[CmdletBinding()]
param (
    [Parameter()][switch]$NoGUI,
    [Parameter(Position = 0)][string]$WorkingDir,
    [Parameter()][switch]$Dev
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

class WPFTab {
    $Object
    $InnerObject
}
Update-TypeData -Force -TypeName 'WPFTab' -MemberType ScriptProperty -MemberName 'InnerObject' -Value {
    $this.Object.Content.Content.Children
}
class WPFCategory {
    $Object
    $InnerObject
}
Update-TypeData  -Force -TypeName 'WPFCategory' -MemberType ScriptProperty -MemberName 'InnerObject' -Value {
    $this.Object.Child.Children[1].Child
}


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


# Formats JSON in a nicer format than the built-in ConvertTo-Json does.
function Format-Json([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -split '\r?\n' | & { process {
            if ($_ -match '[\}\]]\s*,?\s*$') {
                # This line ends with ] or }, decrement the indentation level
                $indent--
            }
            $line = ('    ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
            if ($_ -match '[\{\[]\s*$') {
                # This line ends with [ or {, increment the indentation level
                $indent++
            }
            $line
        } }) -join [Environment]::NewLine
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
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]  [string]    $Name,
        [Parameter(ValueFromPipelineByPropertyName)]                                [string]    $color,
        [Parameter(ValueFromPipelineByPropertyName)]                                [string]    $Icon
    ) 
    process {
        $HeaderStack = [StackPanel]@{
            Orientation = 'Horizontal'
        }

        if ($Icon) {
            if (Test-Path -PathType Leaf $Icon) {
                $TabIcon = [Image]@{
                    Height = '16'
                    Source = [System.Windows.Media.Imaging.BitmapFrame]::Create($Icon)
                    Margin = '-6,0,6,0'
                }
                $HeaderStack.AddChild($TabIcon)
            }
        }
        $TabHeader = [TextBlock]@{
            Text = $Name
        }
        $HeaderStack.AddChild($TabHeader)

        if (!$color) {
            $color = 'Orange'
        }
        $Tab = [TabItem]@{
            Header     = $HeaderStack
            Foreground = $color
        }

        $TabScroll = [ScrollViewer]@{
            VerticalScrollBarVisibility = 'Auto'
        }
        $TabGrid = [Grid]@{
        }
        $TabWrap = [WrapPanel]@{
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
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]  [string]    $Name,
        [Parameter(ValueFromPipelineByPropertyName)]                                [string]    $Icon
    )  
    process {
        $CategoryBorder = [Border]@{
            Style = $GUI.WPF.FindResource('UtilitiesCategoryBorder')
        }
        $CategoryPanel = [StackPanel]@{
            Orientation = 'Vertical'
        }
        $CategoryLabelPanel = [StackPanel]@{
            Style       = $GUI.WPF.FindResource('UtilitiesCategoryLabelPanel')
            Orientation = 'Horizontal'
        }
        if ($Icon) {
            if (Test-Path -PathType Leaf $Icon) {
                $CategoryIcon = [Image]@{
                    Height = '32'
                    Source = [System.Windows.Media.Imaging.BitmapFrame]::Create($Icon)
                }
            }
        }
        $CategoryLabel = [Label]@{
            Style   = $GUI.WPF.FindResource('UtilitiesCategoryLabel')
            Content = $Name 
        }
        $CategoryInnerBorder = [Border]@{
            Style = $GUI.WPF.FindResource('CategoryInnerBorder') 
        }
        $CategoryInnerPanel = [WrapPanel]@{
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
        [Parameter(ValueFromPipelineByPropertyName)]            [List[VaultAppButton]]  $Buttons,
        [Parameter(ValueFromPipelineByPropertyName)]            [string]                $Icon,
        [Parameter(ValueFromPipelineByPropertyName)]            [string]                $BasePath
    )
    process {
        # in CategoryInnerPanel
        $AppOuterBorder = [Border]@{
            Style = $GUI.WPF.FindResource('UtilitiesCardOuterBorder')
        }
        $AppPanel = [StackPanel]@{
            Orientation = 'Vertical'
        } 
        $AppLabelPanel = [StackPanel]@{
            Style       = $GUI.WPF.FindResource('UtilitiesAppLabelPanel')
            Orientation = 'Horizontal'
        }
        $IconPath = Join-Path $BasePath ($Icon -replace '^\.\\', '')
        if (Test-Path -PathType Leaf $IconPath) {
            $AppIcon = [Image]@{
                Height = '16'
                Source = [System.Windows.Media.Imaging.BitmapFrame]::Create($IconPath)
            }
        }

        $AppLabel = [Label]@{
            Style   = $GUI.WPF.FindResource('UtilitiesAppLabel')
            Content = $Name
        }
        $AppInnerBorder = [Border]@{
            Style = $GUI.WPF.FindResource('CardInnerBorder')  
        }
        $AppButtonPanel = [WrapPanel]@{
            Style       = $GUI.WPF.FindResource('CardButtonPanel')
            Orientation = 'Horizontal'
        }
        foreach ($button in $Buttons) {
            $ButtonPath = Join-Path $BasePath ($Button.path -replace '^\.\\', '')
            $AppButtonPanel.AddChild((& { [Button]@{
                            Style   = $GUI.WPF.FindResource('MiscOpenButton')
                            Name    = 'MiscOpenButton'  
                            Content = $Button.Name
                            Tooltip = $ButtonPath.tostring()
                        } } | Add-Member -PassThru 'Path' $ButtonPath )) #feels like this shoudn't be possible. but it is!
            
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

function Add-VaultAppTab_Old {
    [CmdletBinding()]
    param(
        [Parameter()] [string] $TabName,
        [Parameter(Mandatory)] [string] $Directory,
        [Parameter()] [string] $Icon
    )
    process {
        if ($TabName) {
            $TabData = Get-VaultTabData_Old $Directory $TabName | Sort-Object SortIndex, Name
        }
        else {
            $TabData = Get-VaultTabData_Old $Directory | Sort-Object SortIndex, Name
        }

        foreach ($Data in $TabData) { 
            if ($TabName) {
                $VaultAppData = $Data | Get-VaultAppData_Old $TabName | Sort-Object CategoryIndex, Category, SortIndex, Name
            }
            else {
                $VaultAppData = $Data | Get-VaultAppData_Old | Sort-Object CategoryIndex, Category, SortIndex, Name
            }
            if (!$VaultAppData) {
                return
            }

            $Command = @{
                Name = $Data.Name
            }
            if ($Data.Icon) {
                $Command.add('Icon', $Data.Icon)
            }
            if ($Data.Color) {
                $Command.add('Color', $Data.Color)
            }
            
            $VaultAppData | Add-Member -MemberType NoteProperty -Name 'Color' -Value $Data.Color
            $VaultAppData | Add-Member -MemberType NoteProperty -Name 'TabName' -Value $Data.Name
            $VaultAppData | Add-Member -MemberType NoteProperty -Name 'TabIndex' -Value $Data.SortIndex
            $VaultAppData | Add-Member -MemberType NoteProperty -Name 'TabIcon' -Value $Data.Icon

            Write-Output $VaultAppData
        }
    }
}
function Add-VaultAppTab {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]  [VaultData]$Data
    )
    $Data.Cleanup()
    foreach ($TabData in $Data.Tabs) {
        $WPFTab = $TabData | New-WPFTab
        #$TabData | out-Host
        foreach ($CategoryData in $TabData.Categories) {
            #$CategoryData | out-Host
            $WPFCategory = $CategoryData | New-WPFCategory
            foreach ($AppData in $CategoryData.Apps) {
                $WPFCategory.InnerObject.AddChild(($AppData | New-WPFCard))  
            }
            $WPFTab.InnerObject.AddChild($WPFCategory.Object)
        }
        Write-Output $WPFTab.Object
    }
}


#endregion VaultApp GUI func



#region Code behind
if (!$dev) {
    $GUI.Nodes.DevTab.Visibility = 'Collapsed'
    $GUI.Nodes.Tabs.SelectedIndex = 1
}
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

$LoadedData = [VaultData]::FromManifest('.\VaultAssets\DefaultManifest.json')
#load Add-Ons
Get-ChildItem '.\AddOns' -Filter '*.json' | & { process {   
        $LoadedData.Merge([VaultData]::FromManifest($_.FullName))
    } }

if ($null -ne $LoadedData) {
    $LoadedData.Sort()
    Add-VaultAppTab $LoadedData | & { process { $GUI.Nodes.Tabs.AddChild($_) } }
}


#give anything clickable an event
$GUI.WPF.AddHandler([Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]({
            $object = $_
            if ($object.OriginalSource -is [Button]) {
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
                        $files = [FileSystemEntries]::Get(($GUI.Nodes.CueGen.Text), 'File', 'TopDirectoryOnly') | Where-Object { [System.IO.Path]::GetExtension($_) -eq '.bin' -or [System.IO.Path]::GetExtension($_) -eq '.raw' }
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
                    '^Button.File$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'File$', ''
                        $objForm = New-Object System.Windows.Forms.OpenFileDialog
                        $objForm.Filter = 'JSON-Manifest|*.json'
                        $objForm.InitialDirectory = $PSScriptRootEsc
                        if ($objForm.ShowDialog() -eq 'OK') {
                            $GUI.Nodes."Data$Side".Text = [VaultData]::FromManifest($objForm.FileName) | ConvertTo-Json -Depth 8 | Format-Json
                        }
                        continue
                    }
                    '^Button.Folder$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'Folder$', ''
                        $objForm = New-Object CyberOasis.VaultManager.FolderSelectDialog
                        $objForm.InitialDirectory = $PSScriptRootEsc
                        if ($objForm.Show() -eq 'OK') {
                            $GUI.Nodes."Data$Side".Text = [VaultData]::FromDirectory($objForm.FileName) | ConvertTo-Json -Depth 8 | Format-Json
                        }
                        continue
                    }
                    '^Button.Old$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'Old$', ''
                        [VaultData_Old[]]$ConverterData = ((& {
                                    Add-VaultAppTab_Old -TabName 'Emulators' -Directory (Join-Path $PSScriptRootEsc 'Emulators')
                                    Add-VaultAppTab_Old -Directory (Join-Path $PSScriptRootEsc 'AddOns') 
                                } | ConvertTo-Json -Depth 10 | Out-String) -replace ($PSScriptRootEsc -replace '(\\|\^|\$|\.|\||\?|\*|\+|\(|\)|\[\{)', '\$1'), '.' | ConvertFrom-Json)
                        $GUI.Nodes."Data$Side".Text = [VaultData]$ConverterData | ConvertTo-Json -Depth 8 | Format-Json
                        continue
                    }
                    '^Button.Merge$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'Merge$', ''
                        $MergeDataL = [VaultData]($GUI.Nodes.DataL.Text | ConvertFrom-Json -ErrorAction 'SilentlyContinue')
                        $MergeDataR = [VaultData]($GUI.Nodes.DataR.Text | ConvertFrom-Json -ErrorAction 'SilentlyContinue')
                        if ($null -ne $MergeDataL -or $null -ne $MergeDataR) {
                            if ($Side -eq 'L') {
                                try {
                                    $MergeDataL.Merge($MergeDataR)
                                    $GUI.Nodes."Data$Side".Text = $MergeDataL | ConvertTo-Json -Depth 8 | Format-Json
                                }
                                catch {
                                    Write-Error $_
                                }
                            }
                            else {
                                try {
                                    $MergeDataR.Merge($MergeDataL)
                                    $GUI.Nodes."Data$Side".Text = $MergeDataR | ConvertTo-Json -Depth 8 | Format-Json
                                }
                                catch {
                                    Write-Error $_
                                }

                            }
                        }
                    }
                    '^Button.Verify$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'Verify$', ''
                        $VerifyData = [VaultData]($GUI.Nodes."Data$Side".Text | ConvertFrom-Json -ErrorAction 'SilentlyContinue') 
                        if ($null -eq $VerifyData) {
                            $GUI.Nodes."$_".Content = 'Verify (Data Invalid)'
                        }
                        else {
                            $GUI.Nodes."$_".Content = 'Verify (Data OK)'
                        }
                        continue
                    }
                    '^Button.Save$' {
                        $Side = $_ -creplace '^Button', '' -creplace 'Save$', ''
                        if ($Side -eq 'L') {
                            $name = 'left.json'
                        }
                        else {
                            $name = 'right.json'
                        }
                        $VerifyData = [VaultData]($GUI.Nodes."Data$Side".Text | ConvertFrom-Json -ErrorAction 'SilentlyContinue') 
                        if ($null -ne $VerifyData) {
                            $GUI.Nodes."Data$Side".Text | Out-File $name -Encoding utf8
                        }
                        continue
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
#[System.GC]::Collect()
[void]$GUI.WPF.ShowDialog() #show window - main thread is blocked until closed
Pop-Location
