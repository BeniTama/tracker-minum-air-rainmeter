# Menampilkan notifikasi Windows (toast) untuk pengingat minum.
# Dipanggil oleh MeasureToast (plugin RunCommand) di WaterTracker.ini.
param(
    [string]$Title = 'Waktunya minum air',
    [string]$Message = ''
)

[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null

$t = [Security.SecurityElement]::Escape($Title)
$m = [Security.SecurityElement]::Escape($Message)

$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml(@"
<toast scenario="reminder">
  <visual>
    <binding template="ToastGeneric">
      <text>$t</text>
      <text>$m</text>
    </binding>
  </visual>
  <actions>
    <action content="Tutup" arguments="dismiss" activationType="system"/>
  </actions>
  <audio src="ms-winsoundevent:Notification.Reminder"/>
</toast>
"@)

# Daftarkan identitas aplikasi sendiri (HKCU, tanpa admin) supaya notifikasi berjudul
# "Water Tracker" dengan ikon tetes air, bukan "Windows PowerShell".
# Ditulis ulang setiap kali supaya path ikon tetap benar kalau folder skin dipindah.
$appId = 'WaterTracker.Reminder'
$key = "HKCU:\Software\Classes\AppUserModelId\$appId"
$icon = Join-Path $PSScriptRoot 'Images\icon.png'
New-Item -Path $key -Force | Out-Null
New-ItemProperty -Path $key -Name DisplayName -Value 'Water Tracker' -PropertyType String -Force | Out-Null
if (Test-Path $icon) {
    New-ItemProperty -Path $key -Name IconUri -Value $icon -PropertyType ExpandString -Force | Out-Null
}

$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
