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
 
#endregion GUI functions

#region WPF init



$myType = (Add-Type -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.cs') -ReferencedAssemblies (@('PresentationFramework', 'System.Windows.Forms')) -Passthru).Assembly | Sort-Object -Unique

$GUI = [hashtable]::Synchronized(@{}) #Syncronized in case we want parrallel (async) actions that don't lock up the window.
[string]$XAML = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRootEsc '.\VaultAssets\VaultManager.xml')) -replace 'mc:Ignorable="d"' -replace '^<Win.*', '<Window' -replace 'CyberOasis.VaultManager;assembly=', "CyberOasis.VaultManager;assembly=$($myType)"

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
$extensionList = @('.3ds', '.7z', '.apk', '.bin', '.bs', '.cdi', '.chd', '.cia', '.CONFIG', '.cue', '.gba', '.gcm', '.gdi', '.ini', '.iso', '.md', '.nsp', '.png', '.ps1', '.rar', '.raw', '.rvz', '.sav', '.sfc', '.smc', '.srm', '.txt', '.url', '.vpk', '.wad', '.wud', '.wux', '.wbf1', '.wbfs', '.webm', '.xci', '.z64', '.zip')
$GUI.WPF.Icon = (Join-Path $PSScriptRootEsc '.\VaultAssets\icon.ico')

$GUI.WPF.TaskbarItemInfo = [System.Windows.Shell.TaskbarItemInfo]@{overlay = (Join-Path $PSScriptRootEsc '.\VaultAssets\icon.ico') }
$GUI.Nodes.MainGrid.Background.ImageSource = (Join-Path $PSScriptRootEsc '.\VaultAssets\bg.png')
$GUI.Nodes.ListFolderizeExtWhite.ItemsSource = $extensionList
$GUI.Nodes.ListFolderizeExtBlack.ItemsSource = $extensionList
$GUI.Nodes.FolderizeInput.Text = $defaultinput
$GUI.Nodes.InputMerge.Text = join-path $defaultinput 'input.cue'
$GUI.Nodes.OutputMerge.Text = join-path $defaultoutput 'Merged.cue'
$GUI.Nodes.Outputsplit.Text = $defaultoutput
$GUI.Nodes.FolderizeOutput.Text = $defaultoutput
$GUI.Nodes.Cuegen.Text = $defaultinput


#dynamic Taools tab
try { $tools = Get-Folders -subs '.\Tools' -ErrorAction Stop }
catch {  }
if ($tools) {
    $tools | & { Process {
            $categoryPath = [System.IO.Path]::GetDirectoryName($_)
            $categoryFolder = split-path($categoryPath) -Leaf
            $readmepath = [System.IO.Path]::Combine($_, 'Readme.txt')
            $manifestpath = [System.IO.Path]::Combine($_, 'Manifest.json')

            $manifest = [PSCustomObject]@{
                Path = $_
            }
            
            if (Test-Path -PathType Leaf -LiteralPath $manifestpath) {
                $manifest = Get-Content -raw $manifestpath | ConvertFrom-Json
            }
            If (!$manifest.Name) {
                $manifest | Add-Member Name (split-path -leaf $_)
            }

            if ($manifest.Start) { 
                $manifest.Start = [System.IO.Path]::Combine($_, $manifest.Start)          
                If (!(Test-Path -PathType Leaf -LiteralPath $Manifest.Start)) {
                    $manifest | Add-Member Start $null -force
                }
            }
            else {
                $manifest | Add-Member Start $null
            }
            if ($manifest.Readme) {
                $manifest.Readme = [System.IO.Path]::Combine($_, $manifest.Readme)
                If (!(Test-Path -PathType Leaf -LiteralPath $Manifest.Readme)) {
                    $manifest | Add-Member Readme $null -force
                }
            }
            else {
                $manifest | Add-Member Readme $null
            }
            if (!($manifest.Readme) -and (Test-Path -PathType Leaf -LiteralPath $readmepath)) {
                $manifest.Readme = $readmepath
            }
            If (!$manifest.Category) {
                $manifest | Add-Member Category $categoryFolder
            }
            $manifest
        } } | Group-Object Category | & { Process {
            $CategoryBorder = [System.Windows.Controls.Border]@{
                BorderBrush     = '#99CC00CC'
                Margin          = '0,0,6,6'
                BorderThickness = '1'
                Background      = '#33000000'
            }
            $CategoryPanel = [System.Windows.Controls.StackPanel]@{
                Orientation = 'Vertical'
            }
            $CategoryLabel = [System.Windows.Controls.Label]@{
                Foreground               = 'Yellow'
                Content                  = $_.Name
                Background               = '#50FF00FF'
                FontSize                 = 16
                FontWeight               = 'Bold'
                VerticalContentAlignment = 'Center'            
            }
            $CategoryInnerBorder = [System.Windows.Controls.Border]@{
                Padding = '3,3,0,0'  
            }
            $CategoryInnerPanel = [System.Windows.Controls.WrapPanel]@{
                Orientation = 'Horizontal'
            }
            $CategoryBorder.AddChild($CategoryPanel)
            $CategoryPanel.AddChild($CategoryLabel)
            $CategoryPanel.AddChild($CategoryInnerBorder)
            $CategoryInnerBorder.AddChild($CategoryInnerPanel)

            $_.Group | & { Process {
                    # in CategoryInnerPanel
                    $AppOuterBorder = [System.Windows.Controls.Border]@{
                        BorderBrush     = '#66CC00CC'
                        Margin          = '0,0,3,4'
                        BorderThickness = '1'
                        Background      = '#33000000'
                    }
                    $AppPanel = [System.Windows.Controls.StackPanel]@{
                        Orientation = 'Vertical'
                    } 
                    $AppLabel = [System.Windows.Controls.Label]@{
                        Foreground = 'White'
                        Content    = $_.Name
                        Background = '#33FF00FF'
                    }
                    $AppInnerBorder = [System.Windows.Controls.Border]@{
                        Padding = '3,3,3,3'  
                    }
                    $AppButtonPanel = [System.Windows.Controls.Grid]@{
                        MinWidth = '156'
                    }
                    If ($_.Start) {
                        $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                        Content             = 'Start'
                                        Name                = 'OtherStart'
                                        Width               = '50'
                                        HorizontalAlignment = 'Left'
                                    } } | Add-Member -PassThru 'Path' $_.Start)) #feels like this shoudn't be possible. but it is!
                    }
                    $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                    Content             = 'Folder'
                                    Name                = 'OtherFolder'
                                    Width               = '50'
                                    HorizontalAlignment = 'Center'
                                } } | Add-Member -PassThru 'Path' $_.Path))
                    If ($_.Readme) {
                        $AppButtonPanel.AddChild((& { [System.Windows.Controls.Button]@{
                                        Content             = 'Readme'
                                        Name                = 'OtherReadme'
                                        Width               = '50'
                                        HorizontalAlignment = 'Right'
                                    } } | Add-Member -PassThru 'Path' $_.Readme))
                    }
                    $AppPanel.AddChild($AppLabel)
                    $AppPanel.AddChild($AppInnerBorder)
                    $AppInnerBorder.AddChild($AppButtonPanel)
                    $AppOuterBorder.AddChild($AppPanel)
                    $CategoryInnerPanel.AddChild($AppOuterBorder)
                       
                } }
            $GUI.Nodes.OtherStack.AddChild($CategoryBorder) 

        } }
}
else { Write-Warning "Empty `"Tools`" folder `"$(Resolve-Path '.\Tools')`". The `"MIsc Tools`"-Tab will be empty." }

#give anything clickable an event
$GUI.WPF.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, [System.Windows.RoutedEventHandler]({
            $object = $_
            if ($object.OriginalSource -is [System.Windows.Controls.Button]) {
                switch -CaseSensitive -regex ($object.OriginalSource.Name) {
                    '^OtherStart$' { 
                        Start-Process explorer.exe $object.OriginalSource.Path
                        continue
                    }
                    '^OtherFolder$' { 
                        Start-Process explorer.exe $object.OriginalSource.Path
                        continue
                    }
                    '^OtherReadme$' { 
                        Start-Process explorer.exe $object.OriginalSource.Path
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
                            Move        = $FolderizeMove
                        }
                        if ($GUI.Nodes.RadioFolderizeWhitelist.IsChecked) {
                            $Values.add('whitelist', $GUI.Nodes.ListFolderizeExtWhite.SelectedItems) 
                        }
                        elseif ($GUI.Nodes.RadioFolderizeBlacklist.IsChecked) {
                            $Values.add('blacklist', $GUI.Nodes.ListFolderizeExtBlack.SelectedItems)
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
                        if ($FolderizeMove -and $FolderizeEmptyFolders) {
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