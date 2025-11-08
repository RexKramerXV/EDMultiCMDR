$username = "MainCMDR" #your windows account name
$password = ConvertTo-SecureString "yourpassword" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

Start-Process "C:\Program Files (x86)\Steam\steamapps\common\Elite Dangerous\MinEdLauncher.exe"  # Path to the MinEdLauncher executable
    -ArgumentList "/edo /frontier maincmdr /autorun /autoquit"  # Arguments to pass to the launcher, the launcher's github page covers these
    -Credential $cred
