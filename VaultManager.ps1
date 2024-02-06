[CmdletBinding()]
param (
    [Parameter()][switch]$NoGUI,
    [Parameter(Position = 0)][string]$WorkingDir
)

$PSScriptRootEsc = $PSScriptRoot -replace '(\?|\*|\[)', '`$1'
if ($WorkingDir) { Set-Location $WorkingDir }

$host.ui.RawUI.WindowTitle = 'VaultManager Console'
Import-Module (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.psm1') -force

if ($NoGUI) {
    Write-Host 'Loaded additional functions:'
    Write-Host
    (Get-Command -Module 'VaultManager').Name
    Write-Host
    Write-Host 'Type "Get-Help <function> -ShowWindow" to display help for <function> in an additional window.'
    return
}
Clear-Host
Write-Warning 'Closing this console kills the GUI!'



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
Add-Type -Name ConsoleUtils -Namespace WPIA -MemberDefinition @'
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'@
$ConsoleMode = @{
    Hide               = 0
    Normal             = 1
    Minimize           = 2
    Maximize           = 3
    NormalNoActivate   = 4
    Show               = 5
    MinimizeShowNext   = 6
    MinimizeNoActivate = 7
    ShowNoActivate     = 8
    Restore            = 9
    Default            = 10
    ForceMinimize      = 11
}
$hWnd = [WPIA.ConsoleUtils]::GetConsoleWindow()

function New-WPFTab {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]      [string]    $Folder,
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]      [string]    $Name,
        [Parameter(ValueFromPipelineByPropertyName)]               [PSCustomObject[]]    $Buttons = @([PSCustomObject]@{
                Name = "Start"
                Path = "./Start.bat"
            },
            [PSCustomObject]@{
                Name = "Folder"
                Path = "./"
            },
            [PSCustomObject]@{
                Name = "Readme"
                Path = "./Readme.txt"
            }),
        [Parameter(ValueFromPipelineByPropertyName)] [switch] $EmulationStation
    ) 

    if ($EmulationStation) {
        $tools = Get-Folders $Folder
    }
    else {
        if ($Folder) {
            $tools = Get-FolderSubs $Folder
        }
    }

    if ($tools) {
        $Tab = [System.Windows.Controls.TabItem]@{
            Header = $Name
        }
        $TabScroll = [System.Windows.Controls.ScrollViewer]@{
            VerticalScrollBarVisibility = "Auto"
        }
        $TabGrid = [System.Windows.Controls.Grid]@{
        }
        $TabWrap = [System.Windows.Controls.WrapPanel]@{
        }
        $tools | & { Process {
                $categoryPath = [System.IO.Path]::GetDirectoryName($_)
                $categoryFolder = split-path($categoryPath) -Leaf
                #$readmepath = [System.IO.Path]::Combine($_, 'Readme.txt')
                $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')

                $Data = [PSCustomObject]@{
                    Name     = Split-Path $_ -Leaf 
                    Category = $categoryFolder
                    Buttons  = $Buttons | ConvertTo-Json -depth 1 | ConvertFrom-Json
                }
                $Folder = $_
                $Data.Buttons.ForEach( { $_.Path = Join-Path $Folder ($_.Path -replace '^\./|^\.\\', '') })
                Clear-Variable Folder
            
                $manifest = $null
                if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                    $manifest = Get-Content -raw $manifestpath | ConvertFrom-Json
                }
                if ($manifest) {
                    if ($manifest.Name) {
                        $Data.Name = $manifest.Name
                    }
                    if ($manifest.Category) {
                        $Data.Category = $manifest.Category
                    }
                    if ($manifest.Buttons) {
                        If ($manifest.Buttons[0]) {
                            if ($manifest.Buttons[0].Name) {
                                $Data.Buttons[0].Name = $manifest.Buttons[0].Name
                            }
                            if ($manifest.Buttons[0].Path) {
                                $Data.Buttons[0].Path = Join-Path $_ ($manifest.Buttons[0].Path -replace '^\./|^\.\\', '')
                            }
                        }
                        If ($manifest.Buttons[1]) {
                            if ($manifest.Buttons[1].Name) {
                                $Data.Buttons[1].Name = $manifest.Buttons[1].Name
                            }
                            if ($manifest.Buttons[1].Path) {
                                $Data.Buttons[1].Path = Join-Path $_ ($manifest.Buttons[1].Path -replace '^\./|^\.\\', '')
                            }
                        }
                        If ($manifest.Buttons[2]) {
                            if ($manifest.Buttons[2].Name) {
                                $Data.Buttons[2].Name = $manifest.Buttons[2].Name
                            }
                            if ($manifest.Buttons[2].Path) {
                                $Data.Buttons[2].Path = Join-Path $_ ($manifest.Buttons[2].Path -replace '^\./|^\.\\', '')
                            }
                        }
                    }
                }
                $Data
            } } | Group-Object Category | & { Process {
                $CategoryBorder = [System.Windows.Controls.Border]@{
                    Style = $GUI.WPF.FindResource("UtilitiesCategoryBorder")
                }
                $CategoryPanel = [System.Windows.Controls.StackPanel]@{
                    Orientation = 'Vertical'
                }
                $CategoryLabel = [System.Windows.Controls.Label]@{
                    Style   = $GUI.WPF.FindResource("UtilitiesCategoryLabel")
                    Content = $_.Name          
                }
                $CategoryInnerBorder = [System.Windows.Controls.Border]@{
                    Style = $GUI.WPF.FindResource("CategoryInnerBorder") 
                }
                $CategoryInnerPanel = [System.Windows.Controls.WrapPanel]@{
                    Orientation = 'Horizontal'
                }
                $CategoryBorder.AddChild($CategoryPanel)
                $CategoryPanel.AddChild($CategoryLabel)
                $CategoryPanel.AddChild($CategoryInnerBorder)
                $CategoryInnerBorder.AddChild($CategoryInnerPanel)

                $_.Group | Sort-Object Name | & { Process {
                        # in CategoryInnerPanel
                        $AppOuterBorder = [System.Windows.Controls.Border]@{
                            Style = $GUI.WPF.FindResource("UtilitiesCardOuterBorder")
                        }
                        $AppPanel = [System.Windows.Controls.StackPanel]@{
                            Orientation = 'Vertical'
                        } 
                        $AppLabel = [System.Windows.Controls.Label]@{
                            Style   = $GUI.WPF.FindResource("UtilitiesAppLabel")
                            Content = $_.Name
                        }
                        $AppInnerBorder = [System.Windows.Controls.Border]@{
                            Style = $GUI.WPF.FindResource("CardInnerBorder")  
                        }
                        $AppButtonPanel = [System.Windows.Controls.Grid]@{
                            Style = $GUI.WPF.FindResource("CardButtonPanel")
                        }

                        if ($_.Buttons[0] -and (Test-Path $_.Buttons[0].path)) {
                            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                            Style               = $GUI.WPF.FindResource("MiscOpenButton")
                                            Name                = 'MiscOpenButton'  
                                            Content             = ($_.Buttons[0]).Name
                                            HorizontalAlignment = 'Left'
                                            Tooltip             = ($_.Buttons[0]).Path.tostring()
                                        } } | Add-Member -PassThru 'Path' ($_.Buttons[0]).Path)) #feels like this shoudn't be possible. but it is!
                        }
                        if ($_.Buttons[1] -and (Test-Path $_.Buttons[1].path)) {
                            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                            Style               = $GUI.WPF.FindResource("MiscOpenButton")
                                            Content             = ($_.Buttons[1]).Name
                                            Name                = 'MiscOpenButton'
                                            HorizontalAlignment = 'Center'
                                            Tooltip             = ($_.Buttons[1]).Path.tostring()
                                        } } | Add-Member -PassThru 'Path' ($_.Buttons[1]).Path))
                        }
                        if ($_.Buttons[2] -and (Test-Path $_.Buttons[2].path)) {
                            $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                            Style               = $GUI.WPF.FindResource("MiscOpenButton")
                                            Content             = ($_.Buttons[2]).Name
                                            Name                = 'MiscOpenButton'
                                            HorizontalAlignment = 'Right'
                                            Tooltip             = ($_.Buttons[2]).Path.tostring()
                                        } } | Add-Member -PassThru 'Path' ($_.Buttons[2]).Path))
                        }
                        $AppPanel.AddChild($AppLabel)
                        $AppPanel.AddChild($AppInnerBorder)
                        $AppInnerBorder.AddChild($AppButtonPanel)
                        $AppOuterBorder.AddChild($AppPanel)
                        $CategoryInnerPanel.AddChild($AppOuterBorder)
                       
                    } }
                $TabWrap.AddChild($CategoryBorder)
            } }

        $TabGrid.AddChild($TabWrap)
        $TabScroll.AddChild($TabGrid)
        $Tab.AddChild($TabScroll)
        $GUI.Nodes.Tabs.AddChild($Tab)
    }
        
    else { Write-Warning "Empty or non-existent folder or wrong structure: `"$Folder`". No $Name-Tab will be generated." }
}

#endregion GUI functions

#region WPF init



$myType = (Add-Type -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.cs') -ReferencedAssemblies (@('PresentationFramework', 'System.Windows.Forms')) -Passthru).Assembly | Sort-Object -Unique

$GUI = [hashtable]::Synchronized(@{}) #Syncronized in case we want parrallel (async) actions that don't lock up the window.
[string]$XAML = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.xaml')) -replace 'mc:Ignorable="d"' -replace '^<Win.*', '<Window' # Tis is needed for WPF in PS
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
    $XAML = $XAML -replace 'Property="CornerRadius" Value="0"', 'Property="CornerRadius" Value="3"'
}
[xml]$XAML = $XAML




$GUI.NsMgr = (New-XMLNamespaceManager $XAML)
$GUI.WPF = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $XAML) )
#Getting Named GUI elements for easier editing
$GUI.Nodes = $XAML.SelectNodes("//*[@x:Name]", $GUI.NsMgr) | ForEach-Object {
    @{ $_.Name = $GUI.WPF.FindName($_.Name) }
}
#endregion WPF init	

#region Code behind
$defaultinput = join-path (get-location) 'input'
$defaultoutput = join-path (get-location) 'output'
$extensionListPath = (Join-Path $PSScriptRootEsc '.\VaultAssets\FileExtensions.json')

$GUI.Nodes.FolderizeInput.Text = $defaultinput
$GUI.Nodes.InputMerge.Text = join-path $defaultinput 'input.cue'
$GUI.Nodes.OutputMerge.Text = join-path $defaultoutput 'Merged.cue'
$GUI.Nodes.Outputsplit.Text = $defaultoutput
$GUI.Nodes.FolderizeOutput.Text = $defaultoutput
$GUI.Nodes.Cuegen.Text = $defaultinput

$extensionListW = @()
if (Test-Path -PathType Leaf -LiteralPath $extensionListPath) {
    $extensionListW = Get-Content -raw $extensionListPath | ConvertFrom-Json
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

$Buttons = @([PSCustomObject]@{
        Name = "Start"
        Path = "./Start.bat"
    },
    [PSCustomObject]@{
        Name = "Folder"
        Path = "./"
    },
    [PSCustomObject]@{
        Name = "Readme"
        Path = "./Readme.txt"
    })


#EmuStation Tab
$EmulatorsFolder = join-path $PSScriptRootEsc 'Emulators'
if (Test-Path $EmulatorsFolder -PathType Container) {
    $EmulatorsFolder | & { Process {
            $Data = [PSCustomObject]@{
                Folder  = $_
                Name    = Split-Path $_ -Leaf 
                Header  = Split-Path $_ -Leaf
                Buttons = $Buttons | ConvertTo-Json -depth 1 | ConvertFrom-Json
            }

            $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')

            if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                $manifest = Get-Content -raw $manifestpath | ConvertFrom-Json
            }
            if ($manifest) {
                if ($manifest.Name) {
                    $Data.Name = $manifest.Name
                }
                if ($manifest.Header) {
                    $Data.Header = $manifest.Header
                }
                if ($manifest.Buttons) {
                    If ($manifest.Buttons[0]) {
                        if ($manifest.Buttons[0].Name) {
                            $Data.Buttons[0].Name = $manifest.Buttons[0].Name
                        }
                        if ($manifest.Buttons[0].Path) {
                            $Data.Buttons[0].Path = $manifest.Buttons[0].Path
                        }
                    }
                    If ($manifest.Buttons[1]) {
                        if ($manifest.Buttons[1].Name) {
                            $Data.Buttons[1].Name = $manifest.Buttons[1].Name
                        }
                        if ($manifest.Buttons[1].Path) {
                            $Data.Buttons[1].Path = $manifest.Buttons[1].Path
                        }
                    }
                    If ($manifest.Buttons[2]) {
                        if ($manifest.Buttons[2].Name) {
                            $Data.Buttons[2].Name = $manifest.Buttons[2].Name
                        }
                        if ($manifest.Buttons[2].Path) {
                            $Data.Buttons[2].Path = $manifest.Buttons[2].Path
                        }
                    }
                }
            }
            $Data
        } } | New-WPFTab -EmulationStation
}

$AddOnsFolder = join-path $PSScriptRootEsc 'AddOns'
if (Test-Path $AddOnsFolder -PathType Container) {
    #dynamic Tools tab
    $AddOns = Get-Folders $AddOnsFolder
    if ($AddOns) {
        $AddOns | & { Process {
                $Data = [PSCustomObject]@{
                    Folder  = $_
                    Name    = Split-Path $_ -Leaf 
                    Header  = Split-Path $_ -Leaf
                    Buttons = $Buttons | ConvertTo-Json -depth 1 | ConvertFrom-Json
                }

                $manifestpath = [System.IO.Path]::Combine($_, 'VaultManifest.json')

                if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                    $manifest = Get-Content -raw $manifestpath | ConvertFrom-Json
                }
                if ($manifest) {
                    if ($manifest.Name) {
                        $Data.Name = $manifest.Name
                    }
                    if ($manifest.Header) {
                        $Data.Header = $manifest.Header
                    }
                    if ($manifest.Buttons) {
                        If ($manifest.Buttons[0]) {
                            if ($manifest.Buttons[0].Name) {
                                $Data.Buttons[0].Name = $manifest.Buttons[0].Name
                            }
                            if ($manifest.Buttons[0].Path) {
                                $Data.Buttons[0].Path = $manifest.Buttons[0].Path
                            }
                        }
                        If ($manifest.Buttons[1]) {
                            if ($manifest.Buttons[1].Name) {
                                $Data.Buttons[1].Name = $manifest.Buttons[1].Name
                            }
                            if ($manifest.Buttons[1].Path) {
                                $Data.Buttons[1].Path = $manifest.Buttons[1].Path
                            }
                        }
                        If ($manifest.Buttons[2]) {
                            if ($manifest.Buttons[2].Name) {
                                $Data.Buttons[2].Name = $manifest.Buttons[2].Name
                            }
                            if ($manifest.Buttons[2].Path) {
                                $Data.Buttons[2].Path = $manifest.Buttons[2].Path
                            }
                        }
                    }
                }
                $Data
            } } | New-WPFTab
    }
    else { Write-Warning "Empty folder or wrong structure: `"$AddOnsFolder`". No additional Tabs will be generated." }
}
else { Write-Warning "Non-existent folder: `"$AddOnsFolder`". No additional Tabs will be generated." }

#New-WPFTab -Folder './AddOns/Auto' -Name 'Emulators'
#New-WPFTab -Folder './AddOns/Manifest' -Name 'Portable'
#New-WPFTab -Folder './AddOns/Installer' -Name 'Installer'

#give anything clickable an event
$GUI.WPF.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]({
            $object = $_
            if ($object.OriginalSource -is [System.Windows.Controls.Button]) {
                switch -CaseSensitive -regex ($object.OriginalSource.Name) {
                    '^MiscOpenButton$' {
                        $path = Resolve-Path $object.OriginalSource.Path
                        if (Test-Path -PathType Leaf $object.OriginalSource.Path) {
                            $AppStart = $path
                            $AppWorkingDir = Split-Path $path
                        }
                        else {
                            $AppStart = join-path $path '\' #Safeguard against executing "Folder.cmd" instead of opening "Folder"
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
                            $objForm.InitialDirectory = $GUI.Nodes.($textbox).Text
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
                            $objForm.InitialDirectory = $GUI.Nodes.($textbox).Text
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
                            RegEx       = $GUI.Nodes.FolderizeRegex.IsChecked
                        }
                        if ($GUI.Nodes.RadioFolderizeWhitelist.IsChecked) {
                            if ($GUI.Nodes.FolderizeRegex.IsChecked) {
                                $Values.add('whitelist', $GUI.Nodes.FolderizeRegexWhite)
                            }
                            else {
                                $Values.add('whitelist', $GUI.Nodes.ListFolderizeExtWhite.ItemsSource.where({ $_[1] }).ForEach({ $_[0] }))
                            }
                        }
                        elseif ($GUI.Nodes.RadioFolderizeBlacklist.IsChecked) {
                            if ($GUI.Nodes.FolderizeRegex.IsChecked) {
                                $Values.add('whitelist', $GUI.Nodes.FolderizeRegexBlack)
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
                        $files = Get-Files ($GUI.Nodes.CueGen.Text) | Where-Object { [System.IO.Path]::GetExtension($_) -eq '.bin' -or [System.IO.Path]::GetExtension($_) -eq '.raw' }
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