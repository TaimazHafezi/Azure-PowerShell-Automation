<#
.SYNOPSIS
 Script to start or stop Azure VMs with Azure Automation.
.DESCRIPTION
 This script is intended to start or stop Azure Virtual Machines in a simple way in Azure Automation.
 The script uses Azure Automation Managed Identity and the modern ("Az") Azure PowerShell Module.
 
 
param(
    [Parameter(Mandatory = $true)]
    # Specify the name of the Virtual Machine, or use the asterisk symbol "*" to affect all VMs in the resource group
    $VMName,
    [Parameter(Mandatory = $true)]
    $ResourceGroupName,
    [Parameter(Mandatory = $false)]
    # Optionally specify Azure Subscription ID
    $AzureSubscriptionID,
    [Parameter(Mandatory = $true)]
    [ValidateSet("Start", "Stop")]
    # Specify desired Action, allowed values "Start" or "Stop"
    $Action
)

Write-Output "Script started at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# connect to Azure, suppress output
try {
    $null = Connect-AzAccount -Identity
}
catch {
    $ErrorMessage = $_.Exception.message
    Write-Error ("Error connecting to Azure: " + $ErrorMessage)
    exit 1
}

# select Azure subscription by ID if specified, suppress output
if ($AzureSubscriptionID) {
    try {
        $null = Select-AzSubscription -SubscriptionID $AzureSubscriptionID    
    }
    catch {
        $ErrorMessage = $_.Exception.message
        Write-Error ("Error selecting Azure Subscription ($AzureSubscriptionID): " + $ErrorMessage)
        exit 1
    }
}

# check if we are in an Azure Context
try {
    $AzContext = Get-AzContext
}
catch {
    Write-Error ("Error while trying to retrieve the Azure Context: " + $ErrorMessage)
    exit 1
}
if ([string]::IsNullOrEmpty($AzContext.Subscription)) {
    Write-Error "Error. Didn't find any Azure Context. Have you assigned the permissions according to 'CustomRoleDefinition.json' to the Managed Identity? 🤓"
    exit 1
}

if ($VMName -eq "*") {
    try {
        # if "*" was given as the VMName, get all VMs in the resource group
        $VMs = Get-AzVM -ResourceGroupName $ResourceGroupName
    }
    catch {
        $ErrorMessage = $_.Exception.message
        Write-Error ("Error getting VMs from resource group ($ResourceGroupName): " + $ErrorMessage)
        exit 1
    }
    
}
else {
    try {
        # get only the specified VM
        $VMs = Get-AzVM -ResourceGroupName $ResourceGroupName -VMName $VMName
    }
    catch {
        $ErrorMessage = $_.Exception.message
        Write-Error ("Error getting VM ($VMName) from resource group ($ResourceGroupName): " + $ErrorMessage)
        exit 1
    }
    
}

# Loop through all specified VMs (if more than one). The loop only executes once if only one VM is specified.
foreach ($VM in $VMs) {
    switch ($Action) {
        "Start" {
            # Start the VM
            try {
                Write-Output "Starting VM $($VM.Name)..."
                $null = $VM | Start-AzVM -ErrorAction Stop -NoWait
            }
            catch {
                $ErrorMessage = $_.Exception.message
                Write-Error ("Error starting the VM $($VM.Name): " + $ErrorMessage)
                Break
            }
        }
        "Stop" {
            # Stop the VM
            try {
                Write-Output "Stopping VM $($VM.Name)..."
                $null = $VM | Stop-AzVM -ErrorAction Stop -Force -NoWait
            }
            catch {
                $ErrorMessage = $_.Exception.message
                Write-Error ("Error stopping the VM $($VM.Name): " + $ErrorMessage)
                Break
            }
        }    
    }
}

Write-Output "Script ended at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
