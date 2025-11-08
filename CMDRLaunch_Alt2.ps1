# Second Alt commander - a Frontier account in this example

$username = "alt2" #your windows account name
$password = ConvertTo-SecureString "yourpassword" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($username, $password)

Start-Process "C:\Program Files (x86)\Frontier\Products\elite-dangerous-64\MinEdLauncher.exe"  # Path to the MinEdLauncher executable
    -ArgumentList "/edo /frontier alt2cmdr /autorun /autoquit"  # Arguments to pass to the launcher, the launcher's github page covers these
    -Credential $cred
