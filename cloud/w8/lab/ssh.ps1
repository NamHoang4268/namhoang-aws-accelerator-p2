# SSH helper for PowerShell — fixes Windows ACL permissions then connects to EC2

$PEM = ".\k8s-host.pem"
# Read IP directly from tfstate (no need for terraform in PowerShell PATH)
$STATE = Get-Content ".\terraform.tfstate" | ConvertFrom-Json
$IP = $STATE.outputs.ec2_public_ip.value

Write-Host "→ Fixing .pem permissions via icacls..."
icacls $PEM /inheritance:r /grant:r "$($env:USERNAME):F" | Out-Null

Write-Host "→ Connecting to ubuntu@$IP ..."
ssh -i $PEM ubuntu@$IP
