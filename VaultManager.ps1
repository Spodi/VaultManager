[CmdletBinding()]
param (
    [Parameter()][switch]$NoGUI,
    [Parameter()][string]$WorkingDir
)

Import-Module '.\VaultManager.psm1'

if (!$NoGUI) {
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

    $LightTheme = (Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme').AppsUseLightTheme

    $GUI = [hashtable]::Synchronized(@{})

    [string]$XAML = (Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'VaultManager.xml')) -replace 'mc:Ignorable="d"' -replace '^<Win.*', '<Window'


    if ($LightTheme) {
        $XAML = $XAML -replace 'BasedOn="{StaticResource DarkTheme}"', 'BasedOn="{StaticResource LightTheme}"'
        $XAML = $XAML -replace 'Style="{StaticResource DarkThemeButton}"', 'Style="{StaticResource LightThemeButton}"'
        $XAML = $XAML -replace '§VersionForeground§', 'Black'
    }
    else {
        $XAML = $XAML -replace '§VersionForeground§', 'White'
    }

    #Round corners in win11
    if ((Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name CurrentBuild).CurrentBuild -ge 22000) {
        $XAML = $XAML -replace 'Property="CornerRadius" Value="0"', 'Property="CornerRadius" Value="4"'
    }
    [xml]$XAML = $XAML


    Add-Type -AssemblyName 'PresentationFramework'
    $GUI.NsMgr = (New-XMLNamespaceManager $XAML)
    $GUI.WPF = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $XAML) )
    $GUI.Nodes = $XAML.SelectNodes("//*[@x:Name]", $GUI.NsMgr) | ForEach-Object {
        @{ $_.Name = $GUI.WPF.FindName($_.Name) }
    }
    $Events = @{}
    [System.Windows.RoutedEventHandler]$Events.ButtonClickHandler = {
        switch ($_.OriginalSource.Name) {
            Default { Write-Host $_ }
        }
	
    }
    $GUI.WPF.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $Events.ButtonClickHandler)

    $GUI.WPF.Add_Loaded({
            $GUI.WPF.Icon = '.\icon.ico'
            $GUI.Nodes.MainGrid.Background.ImageSource = "./bg.png"
            $GUI.Nodes.ListFolderizeExtensions.ItemsSource = @('.3ds', '.7z', '.apk', '.bin', '.bs', '.cdi', '.chd', '.cia', '.CONFIG', '.cue', '.gba', '.gcm', '.gdi', '.ini', '.iso', '.md', '.nsp', '.png', '.ps1', '.rar', '.raw', '.rvz', '.sav', '.sfc', '.smc', '.srm', '.txt', '.url', '.wad', '.wud', '.wux', '.wbf1', '.wbfs', '.webm', '.xci', '.z64', '.zip')
        })

    [void]$GUI.WPF.ShowDialog() #show window

} else {
    Write-Host 'Loaded additional functions:'
    Write-Host
    (Get-Command -Module 'VaultManager').Name
    Write-Host
    Write-Host 'Use "Get-Help <function> -showwindow" to display help for <function> in an additional window.'
}