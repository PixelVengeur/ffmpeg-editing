<# 
.NAME
    ffmpeg
#>

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = New-Object System.Drawing.Point(516,363)
$Form.text                       = "Form"
$Form.TopMost                    = $false

$TextBox1                        = New-Object system.Windows.Forms.TextBox
$TextBox1.multiline              = $false
$TextBox1.width                  = 240
$TextBox1.height                 = 40
$TextBox1.location               = New-Object System.Drawing.Point(30,49)
$TextBox1.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$Panel1                          = New-Object system.Windows.Forms.Panel
$Panel1.height                   = 292
$Panel1.width                    = 300
$Panel1.location                 = New-Object System.Drawing.Point(205,12)

$Label1                          = New-Object system.Windows.Forms.Label
$Label1.text                     = "Music blurbs"
$Label1.AutoSize                 = $true
$Label1.width                    = 30
$Label1.height                   = 10
$Label1.location                 = New-Object System.Drawing.Point(110,20)
$Label1.Font                     = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$Button1                         = New-Object system.Windows.Forms.Button
$Button1.text                    = "Compile"
$Button1.width                   = 75
$Button1.height                  = 30
$Button1.location                = New-Object System.Drawing.Point(424,316)
$Button1.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',10)

$ProgressBar1                    = New-Object system.Windows.Forms.ProgressBar
$ProgressBar1.width              = 392
$ProgressBar1.height             = 30
$ProgressBar1.location           = New-Object System.Drawing.Point(17,316)

$ListView1                       = New-Object system.Windows.Forms.ListView
$ListView1.text                  = "listView"
$ListView1.width                 = 89
$ListView1.height                = 224
$ListView1.location              = New-Object System.Drawing.Point(48,49)

$Panel1.controls.AddRange(@($TextBox1,$Label1))
$Form.controls.AddRange(@($Panel1,$Button1,$ProgressBar1))


#region Logic 

#endregion

[void]$Form.ShowDialog()