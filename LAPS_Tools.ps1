# Get-LapsGui-Reporting-V3.1.ps1
# GUI pour la r�cup�ration de mot de passe LAPS avec export, tra�abilit�, guide UAC et diagnostic avanc�.
# D�velopp� par PBSCo Informatique

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms  # N�cessaire pour DoEvents

# D�finition de l'interface graphique en XAML (WPF)
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="LAPS - Outil de r�cup�ration et tra�abilit� v3.1" Height="500" Width="520"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>
        
        <StackPanel Grid.Row="0">
            <Label Content="Nom de l'ordinateur (FQDN ou NetBIOS):" />
            <TextBox Name="ComputerNameTextBox" Padding="2" MaxLength="64" />
        </StackPanel>

        <StackPanel Grid.Row="1" Margin="0,10,0,0">
            <Label Content="Motif de la demande (8 caract�res minimum):"/>
            <TextBox Name="ReasonTextBox" Padding="2" MaxLength="64" />
        </StackPanel>

        <StackPanel Grid.Row="2" Margin="0,10,0,0">
            <Label Content="Dur�e de validit� du mot de passe:"/>
            <ComboBox Name="DurationComboBox" Padding="2" SelectedIndex="3" />
        </StackPanel>
        
        <Button Grid.Row="3" Name="GetPasswordButton" Content="G�n�rer le mot de passe" Margin="0,20,0,10" Padding="8" FontWeight="Bold" />
        
        <StackPanel Grid.Row="4" Name="ProgressPanel" Visibility="Collapsed" Margin="0,0,0,10">
            <Label Name="ProgressLabel" Content="Initialisation..." FontSize="12" Foreground="Blue" />
            <ProgressBar Name="ProgressBar" Height="20" Minimum="0" Maximum="100" />
        </StackPanel>
        
        <GroupBox Grid.Row="5" Header="R�sultat et Actions" Name="ResultGroupBox" IsEnabled="False">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="*" />
                    <RowDefinition Height="Auto" />
                </Grid.RowDefinitions>
                <ScrollViewer Grid.Row="0" VerticalScrollBarVisibility="Auto" MaxHeight="150">
                    <TextBlock Name="ResultTextBlock" TextWrapping="Wrap" Margin="5" FontSize="12" />
                </ScrollViewer>
                <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button Name="ExportButton" Content="Exporter les informations" Margin="5" Padding="8" Width="180" />
                    <Button Name="ResetButton" Content="Nouvelle demande" Margin="5" Padding="8" Width="180" />
                </StackPanel>
            </Grid>
        </GroupBox>
        
        <StatusBar Grid.Row="6" VerticalAlignment="Bottom" Margin="0,10,0,-10">
            <StatusBarItem><TextBlock Name="StatusTextBlock" Text="Pr�t"/></StatusBarItem>
            <StatusBarItem HorizontalAlignment="Right">
                <TextBlock Text="v3.1 - D�velopp� par PBSCo Informatique" Opacity="0.5" />
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [System.Windows.Markup.XamlReader]::Load($reader)

# R�cup�ration des contr�les
$ComputerNameTextBox = $window.FindName("ComputerNameTextBox")
$ReasonTextBox      = $window.FindName("ReasonTextBox")
$DurationComboBox   = $window.FindName("DurationComboBox")
$GetPasswordButton  = $window.FindName("GetPasswordButton")
$ProgressPanel      = $window.FindName("ProgressPanel")
$ProgressLabel      = $window.FindName("ProgressLabel")
$ProgressBar        = $window.FindName("ProgressBar")
$ResultGroupBox     = $window.FindName("ResultGroupBox")
$ResultTextBlock    = $window.FindName("ResultTextBlock")
$ExportButton       = $window.FindName("ExportButton")
$ResetButton        = $window.FindName("ResetButton")
$StatusTextBlock    = $window.FindName("StatusTextBlock")

# Variables globales
$global:retrievedPassword = $null
$global:newExpiration    = $null
$global:generationTime   = $null

# Options de dur�e
$durationOptions = [ordered]@{
    "4h"      = 4
    "8h"      = 8
    "12h"     = 12
    "24h"     = 24
    "1 mois"  = 720
}
$durationOptions.Keys | ForEach-Object { $DurationComboBox.Items.Add($_) }
$DurationComboBox.SelectedItem = "24h"

# Mettre � jour la barre de progression
function Update-Progress {
    param([int]$Value, [string]$Text)
    $ProgressBar.Value     = $Value
    $ProgressLabel.Content = $Text
    $StatusTextBlock.Text  = $Text
    [System.Windows.Forms.Application]::DoEvents()
}

# Diagnostic LAPS (module et lecture seulement)
function Test-LapsPermissions {
    param([string]$ComputerName)
    $diagnostics = @{
        ModuleAvailable = $false
        CanRead         = $false
        ComputerExists  = $false
        ErrorDetails    = @()
    }
    try {
        Update-Progress 10 "V�rification du module LAPS..."
        if (Get-Module -ListAvailable -Name LAPS) {
            $diagnostics.ModuleAvailable = $true
            Import-Module LAPS -ErrorAction Stop
        } else {
            $diagnostics.ErrorDetails += "Module LAPS non disponible"
            return $diagnostics
        }
        Update-Progress 30 "Test de lecture du mot de passe..."
        try {
            $testRead = Get-LapsADPassword -Identity $ComputerName -AsPlainText -ErrorAction Stop
            if ($testRead) {
                $diagnostics.CanRead        = $true
                $diagnostics.ComputerExists = $true
            }
        } catch {
            $diagnostics.ErrorDetails += "Lecture �chou�e: $($_.Exception.Message)"
        }
    } catch {
        $diagnostics.ErrorDetails += "Erreur g�n�rale: $($_.Exception.Message)"
    }
    return $diagnostics
}

# Clique sur G�n�rer le mot de passe
$GetPasswordButton.Add_Click({
    $computerName = $ComputerNameTextBox.Text.Trim()
    $reason       = $ReasonTextBox.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($computerName)) {
        [System.Windows.MessageBox]::Show("Veuillez entrer un nom d'ordinateur.","Erreur","OK","Warning")
        return
    }
    if ($reason.Length -lt 8) {
        [System.Windows.MessageBox]::Show("Le motif doit contenir au moins 8 caract�res.","Erreur","OK","Warning")
        return
    }
    # D�sactiver UI et afficher barre de progression
    $GetPasswordButton.IsEnabled   = $false
    $ComputerNameTextBox.IsEnabled = $false
    $ReasonTextBox.IsEnabled       = $false
    $DurationComboBox.IsEnabled    = $false
    $ProgressPanel.Visibility      = "Visible"
    $ResultGroupBox.IsEnabled      = $false
    $ResultTextBlock.Text          = ""
    Update-Progress 0 "D�marrage..."

    try {
        $diagnostics = Test-LapsPermissions -ComputerName $computerName
        if (-not $diagnostics.ModuleAvailable) {
            throw "Module LAPS introuvable."
        }
        if (-not $diagnostics.ComputerExists) {
            throw "Ordinateur '$computerName' introuvable dans l'AD."
        }
        if (-not $diagnostics.CanRead) {
            throw "Permission de lecture insuffisante pour '$computerName'."
        }
        Update-Progress 60 "R�cup�ration du mot de passe..."
        $lapsPassword     = Get-LapsADPassword -Identity $computerName -AsPlainText -ErrorAction Stop
        $global:retrievedPassword = $lapsPassword.Password
        $global:generationTime    = Get-Date

        Update-Progress 80 "Application de la nouvelle expiration..."
        $hours                  = $durationOptions[$DurationComboBox.SelectedItem]
        $global:newExpiration   = $global:generationTime.AddHours($hours)
        Set-LapsADPasswordExpirationTime -Identity $computerName -WhenEffective $global:newExpiration -ErrorAction Stop

        Update-Progress 100 "Termin�"
        $ResultTextBlock.Text = "[OK] Mot de passe g�n�r� et expiration mise � jour.`nPr�t pour export."
        $ResultGroupBox.IsEnabled = $true
        Start-Sleep -Milliseconds 1500
        $ProgressPanel.Visibility = "Collapsed"
    } catch {
        Update-Progress 0 "Erreur"
        $report = "[ERREUR] ECHEC DE LA GENERATION`n" + ("=" * 40) + "`n"
        $report += "Erreur: $($_.Exception.Message)`n`nDIAGNOSTIC:`n"
        if ($diagnostics.ModuleAvailable) {
            $report += "� Module LAPS: [OK] Disponible`n"
        } else {
            $report += "� Module LAPS: [ERREUR] Manquant`n"
        }
        if ($diagnostics.ComputerExists) {
            $report += "� Ordinateur trouv�: [OK] Oui`n"
        } else {
            $report += "� Ordinateur trouv�: [ERREUR] Non`n"
        }
        if ($diagnostics.CanRead) {
            $report += "� Permission lecture: [OK] Oui`n"
        } else {
            $report += "� Permission lecture: [ERREUR] Non`n"
        }
        if ($diagnostics.ErrorDetails.Count -gt 0) {
            $report += "`nDETAILS TECHNIQUES:`n"
            $diagnostics.ErrorDetails | ForEach-Object { $report += "� $_`n" }
        }
        $ResultTextBlock.Text = $report
        $ResultGroupBox.IsEnabled = $true
        $ExportButton.IsEnabled = $false
        $ProgressPanel.Visibility = "Collapsed"
    }
})

# Clique sur Exporter les informations
$ExportButton.Add_Click({
    $computerName = $ComputerNameTextBox.Text.Trim()
    $reason       = $ReasonTextBox.Text.Trim()
    $currentUser  = "$($env:USERDOMAIN)\$($env:USERNAME)"
    $guide = @"
--------------------------------------------------
Comment utiliser ce mot de passe ?
--------------------------------------------------
Ce mot de passe est celui de l'administrateur LOCAL du poste.
Il sert � valider les actions n�cessitant une �l�vation de privil�ges (fen�tre UAC).

Pour l'utiliser :
1. Lorsque Windows vous demande une autorisation pour installer un logiciel ou modifier un param�tre (fen�tre UAC), cliquez sur \"Plus de choix\".
2. S�lectionnez \"Utiliser un autre compte\".
3. Dans le champ du nom d'utilisateur, tapez : .\Administrateur
   (Pour un poste en fran�ais. Sinon essayez .\Administrator).
4. Dans le champ du mot de passe, entrez le mot fourni.
5. Validez pour lancer l'action.

ATTENTION : Ce mot de passe est temporaire et expirera automatiquement. Ne le partagez pas.
"@
    $fileContent = @"
--------------------------------------------------
Rapport de g�n�ration de mot de passe LAPS
--------------------------------------------------
Utilisateur : $currentUser
Machine    : $computerName
Motif      : $reason
--------------------------------------------------
G�n�r� le  : $($global:generationTime.ToString('dd/MM/yyyy HH:mm:ss'))
Expiration : $($global:newExpiration.ToString('dd/MM/yyyy HH:mm:ss'))
--------------------------------------------------
Mot de passe: $global:retrievedPassword
--------------------------------------------------

$guide
"@
    $dlg = New-Object Microsoft.Win32.SaveFileDialog
    $dlg.FileName = "LAPS_INFO_${computerName}_$($global:generationTime.ToString('yyyyMMddHHmm')).txt"
    $dlg.Filter   = "Fichiers texte (*.txt)|*.txt"
    if ($dlg.ShowDialog() -eq $true) {
        try {
            Set-Content -Path $dlg.FileName -Value $fileContent
            [System.Windows.MessageBox]::Show("Export� vers : $($dlg.FileName)","OK","OK","Information")
        } catch {
            [System.Windows.MessageBox]::Show("Erreur enregistrement : $($_.Exception.Message)","Erreur","OK","Error")
        }
    }
})

# Clique sur Nouvelle demande
$ResetButton.Add_Click({
    $GetPasswordButton.IsEnabled   = $true
    $ComputerNameTextBox.IsEnabled = $true
    $ReasonTextBox.IsEnabled       = $true
    $DurationComboBox.IsEnabled    = $true
    $ExportButton.IsEnabled        = $true
    $ComputerNameTextBox.Clear()
    $ReasonTextBox.Clear()
    $DurationComboBox.SelectedItem = "24h"
    $ResultTextBlock.Text          = ""
    $ProgressPanel.Visibility      = "Collapsed"
    $ProgressBar.Value             = 0
    $ResultGroupBox.IsEnabled      = $false
    $StatusTextBlock.Text          = "Pr�t"
    $global:retrievedPassword = $null
    $global:newExpiration    = $null
    $global:generationTime   = $null
    $ComputerNameTextBox.Focus()
})

$window.Add_SourceInitialized({ $GetPasswordButton.IsDefault = $true })
$window.ShowDialog() | Out-Null
