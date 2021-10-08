Param(
[Parameter(Mandatory=$True)]
[string]$VCenterIP,
[Parameter(Mandatory=$False)]
[string]$StartingIP,
[string]$DesinationIP,
[Parameter(Mandatory=$True)]
[string]$UandP= "True"
)
function update-VMHost{

Begin{
Write-Host "Start Stage 1 of Upgrade Process"
If ($UandP -eq "True"){
Connect-VIServer -Server $VCenterIP -Protocol https -Credential (Get-Credential)
}
else {Write-host "You need to set UandP to True"}
$host1=get-vm -Location $StartingIP
Get-vm -Location $StartingIP | Move-vm -desination $DesinationIP -VMotionPriority High
Do {
$host1.count
sleep -Seconds 10
} until ($host1.count -eq 0)
Write-Host "Stage 1 Complete (1/3)"
}
    Process{
    Write-host "Start of Stage 2"
    $vmlist=get-vm -Location $StartingIP | select name
    $vmlist | Out-File .\vm-list.txt
    get-vmhost -Location $StartingIP | Set-VMHost -State Maintenance
    $baseline1=get-baseline -name 'Critical Host Patches (Predefined)','Host Security Patches (Predefined)'
    Add-EntityBaseline -Entity $StartingIP -Baseline $baseline1
    Test-Compliance -Entity $StartingIP
    do{
    $compliance=Get-Compliance -Entity $StartingIP
    if($compliance.status[0] -ne "Compliant" -and $compliance.status[1] -ne "Compliant"){
    copy-patch -Entity $StartingIP
    Update-Entity -Baseline $baseline1 -Entity $StartingIP -RunAsync -Confirm:$False
    sleep -Seconds 60
    }
    elseif($compliance.status[0] -eq "Compliant" -and $compliance.status[1] -eq "Compliant" ){
    get-vmhost -location $StartingIP | Set-VMHost -State Connected
    }
    }until ($compliance.status[0] -eq "Compliant" -and $compliance.status[1] -eq "Compliant" )
    Write-Host "Stage 2 Complete (2/3)"
    }
End{
Write-Host "Start of Stage 3"
$vmhostlist=Get-Content -Path .\vm-list.txt
for($i=3;$i -le $vmhostlist.count;++$i){
get-vm -Name $vmhostlist[$i] | Move-VM -desination $StartingIP -VMotionPriority High
sleep -Seconds 5
}
$vmlist2=Get-VM -Location $StartingIP | select name
 $vmlist2 | out-file .\vm-list2.txt
    $first=Get-Content .\vm-list.txt
    $second=Get-Content .\vm-list2.txt
    if(Compare-Object $first $second){Compare-Object $first $second -IncludeEqual
    Write-Host "If you see this page double check what servers are missing"}
    else{echo "Everything worked"; rm .\vm-list.txt ; rm .\vm-list2.txt}
    Write-Host "Stage 3 is Complete (3/3)"
}
}
update-VMHost
