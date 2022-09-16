cls
#region Load Variables
$vmLocalAdminUserName = "<Username to use for creating Local Administrator account in Windows>"
$vmLocalAdminPass = ConvertTo-SecureString "<PasswordToUseForLocalAdminAccount>" -AsPlainText -Force
$domainToJoin = "VMDemo.local"
$domainJoinKeyvaultSubscription = "<Subscription Name of Keyvault with password for Domain Join>"
$domainJoinKeyvault = "<KeyVault Name of Keyvault with password for Domain Join>"
$domainJoinKeyvaultSecretName = "<Secret Name to use as username and the secret of it for the password for domain joining"
$storageAccountSubscriptionName = "<Template Storage account subscription>"
$storageaccountRGName = "<Resource Group name of template storage account>"
$storageaccountName = "<Storage Account Name with Templates in it>"
$storageAccountContainerName = "<Container Name where Templates are located>"
$buildVMs = import-csv -path "C:\temp\DemoSQLDeploymentTemplate.csv"  # <---  Change this file name to your filename and path to it to read
#endregion Load Variables

#region Get Domain Join Password
## enter subscription for domain password for joining
Select-AzSubscription -subscriptionname $domainJoinKeyvaultSubscription

##retrieve the password for domain join
$domainJoinPassword = (Get-AzKeyVaultSecret -VaultName $domainJoinKeyvault -Name $domainJoinKeyvaultSecretName).SecretValue
#endregion

#region get SAS Tokens for Template for deployment

Select-AzSubscription -SubscriptionName $storageAccountSubscriptionName

$sa = Get-AzStorageAccount -StorageAccountName $storageaccountName -ResourceGroupName $storageaccountRGName
$storageAccountKey = ($sa | Get-AzStorageAccountKey).Value[0]
$storageContext = New-AzStorageContext –StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey

$StartTime = Get-Date
$EndTime = $startTime.AddHours(4.0)

#DomainJoin Template Token
$DomainJoininstalltemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "samplesqlvminstallwithdiskcountwDomainJoin.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri

#DomainJoinSQLFeature Template Token
$DomainJoinSQLFeatureinstalltemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "samplesqlvminstallwithdiskcountwDomainJoinFeatureCleanup.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri

#Windows Install with Data Disk Template token
$WindowsDataDisksinstalltemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "Samplevmdeploymentwithdatadisks.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri
            
#Data Science Install with Data Disk Template token
$DataScienceDataDisksinstalltemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "SampleDSVMdeploymentwithdatadisks.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri
            
#Windows Install with Data Disk Template token
$WindowsDataDisksNoAccelNetinstalltemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "SamplevmdeploymentwithdatadisksNoAcceleratedNetworking.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri

#SQL VM No Domain Join
$SQLVMNoDomaintemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "samplesqlvminstallwithdiskcount.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri

#SQL VM No Domain Join
$SQLVMNoDomainNoAccelNettemplateURI = New-AzStorageBlobSASToken -Context $storagecontext -Container $storageAccountContainerName -Blob "samplesqlvminstallwithdiskcountNOAccelNet.json" -Permission r -StartTime $StartTime -ExpiryTime $EndTime -FullUri
#endregion



cls
foreach ($buildVM in $buildVMs)
{
    #Load and set variables to process
    $templateType = $buildVM.templatetype
    $vmName = $buildVM.Name
    $vmSubscriptionName = $buildVM.subscriptionname
    $resourceGroupName = $buildVM.ResourceGroup
    $OUPath = $buildVM.OUPath
    $storageWorkloadType = $buildVM.StorageWorkloadType
    $imageOffer = $buildVM.ImageOffer
    $imageSku = $buildVM.ImageSku
    $SQLLicense = $buildVM.sqlLicense

    #if dbengine feature is yes the switch to true
    If ($buildVM.DBEngine.ToUpper() -eq "YES")
        {
            $DBEngine = $true
        }
    Else
        {
            $DBEngine = $false
        }

    #if ssrs feature is yes the switch to true
    If ($buildVM.SSRS.ToUpper() -eq "YES")
        {
            $SSRS = $true
        }
    Else
        {
            $SSRS = $false
        }

    #if SSAS feature is yes the switch to true
    If ($buildVM.SSAS.ToUpper() -eq "YES")
        {
            $SSAS = $true
        }
    Else
        {
            $SSAS = $false
        }
        
    #if SSIS feature is yes the switch to true
    If ($buildVM.SSIS.ToUpper() -eq "YES")
        {
            $SSIS = $true
        }
    Else
        {
            $SSIS = $false
        }

    #if rServices feature is yes the switch to true
    If ($buildVM.rServicesEnabled.ToUpper() -eq "YES")
        {
            $rServices = $true
        }
    Else
        {
            $rServices = $false
        }

    #if DQS Client feature is yes the switch to true
    If ($buildVM.DQSClient.ToUpper() -eq "YES")
        {
            $DQSClient = $true
        }
    Else
        {
            $DQSClient = $false
        }
        
    #if SQL Client Connectivity Tools feature is yes the switch to true
    If ($buildVM.SQLClientConnectivity.ToUpper() -eq "YES")
        {
            $SQLClientConn = $true
        }
    Else
        {
            $SQLClientConn = $false
        }
        
    #if Master Data Services feature is yes the switch to true
    If ($buildVM.MasterDataServices.ToUpper() -eq "YES")
        {
            $MasterDataServ = $true
        }
    Else
        {
            $MasterDataServ = $false
        }

    $VMSize = $buildVM.Size
    $dataDiskSize = $buildVM.DataDiskSize
    $dataDiskCount = $buildVM.DataDiskCount
    $dataDiskPath = $buildVM.DataDriveAndPath
    $tLogDiskSize = $buildVM.TLogDiskSize
    $tLogDiskCount = $buildVM.TLogDiskCount
    $tLogDiskPath = $buildVM.TLogDriveAndPath
    $tempDBDiskSize = $buildVM.TempDBDiskSize
    $tempDBDiskCount = $buildVM.TempDBDiskCount
    $tempDBDiskPath = $buildVM.TempDBDriveAndPath
    $Location = $buildVM.AzureRegion
    $SQLConnectivity = $buildVM.SQLConnectivity.ToUpper()
    $SQLConnectivityPort = $buildVM.SQLConnectivityPort
    $availabilitySetName = $buildVM.AvailabilitySet
    $networkRGName = $buildVM.NetworkResourceGroupName
    $networkName = $buildVM.NetworkName
    $subnetName = $buildVM.SubnetName

    If ($availabilitySetName -eq $null)
        {
            $availabilitySetName = "Unknown"
        }
    If ($availabilitySetName -eq "")
        {
            $availabilitySetName = "Unknown"
        }
    If($buildVM.AvailabilitySetEnabled.ToUpper() -eq "YES")
        {
            $Availabilitysetenabled = $true
        }
    Else
        {
            $Availabilitysetenabled = $false
        }
    ""
    "Starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName)"

    if($templateType.ToUpper() -eq "DOMAINJOIN")
        {
            
           
            Select-AzSubscription -SubscriptionName $vmSubscriptionName
            $date = get-date -Format yyyyMMddHHmm
            $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
            New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
            -TemplateUri $DomainJoininstalltemplateURI `
            -virtualMachineName $vmName `
            -virtualMachineSize $VMSize `
            -availabilitySetName $availabilitySetName `
            -availabilitySetEnabled $Availabilitysetenabled `
            -existingVirtualNetworkName $networkName `
            -existingVnetResourceGroup $networkRGName `
            -existingSubnetName $subnetName `
            -imageOffer $imageOffer `
            -sqlSku $imageSku `
            -sqlLicense $SQLLicense `
            -vmAdminUsername $vmLocalAdminUserName `
            -vmAdminPassword $vmLocalAdminPass `
            -DomainPassword $domainJoinPassword `
            -keyvaultSubscriptionId "notused" `
            -keyVaultResourceGroupName "Notused" `
            -keyVaultName "Notused" `
            -keyVaultSecretName $domainJoinKeyvaultSecretName `
            -domainToJoin $domainToJoin `
            -ouPath $OUPath `
            -storageWorkloadType $storageWorkloadType `
            -sqlDataDisksCount $dataDiskCount `
            -sqlDataDiskSizeInGB $dataDiskSize `
            -dataPath $dataDiskPath `
            -sqlTempDBDisksCount $tempDBDiskCount `
            -sqlTempDBDiskSizeInGB $tempDBDiskSize `
            -TempDBPath $tempDBDiskPath `
            -sqlLogDisksCount $tLogDiskCount `
            -sqlLogDiskSizeInGB $tLogDiskSize `
            -logPath $tLogDiskPath `
            -SQLConnectivity $SQLConnectivity `
            -SQLConnectivityPort $SQLConnectivityPort `
            -rServicesEnabled $rServices `
            -location $Location `
            -AsJob
  
            ""
            "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template DOMAINJOIN"
            ""

        }
    if($templateType.ToUpper() -eq "NODOMAIN")
        {
            
           
            Select-AzSubscription -SubscriptionName $vmSubscriptionName
            $date = get-date -Format yyyyMMddHHmm
            $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
            New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
            -TemplateUri $SQLVMNoDomaintemplateURI `
            -virtualMachineName $vmName `
            -virtualMachineSize $VMSize `
            -availabilitySetName $availabilitySetName `
            -availabilitySetEnabled $Availabilitysetenabled `
            -existingVirtualNetworkName $networkName `
            -existingVnetResourceGroup $networkRGName `
            -existingSubnetName $subnetName `
            -adminUsername $vmLocalAdminUserName `
            -adminPassword $vmLocalAdminPass `
            -imageOffer $imageOffer `
            -sqlSku $imageSku `
            -sqlLicense $SQLLicense `
            -storageWorkloadType $storageWorkloadType `
            -sqlDataDisksCount $dataDiskCount `
            -sqlDataDiskSizeInGB $dataDiskSize `
            -dataPath $dataDiskPath `
            -sqlTempDBDisksCount $tempDBDiskCount `
            -sqlTempDBDiskSizeInGB $tempDBDiskSize `
            -TempDBPath $tempDBDiskPath `
            -sqlLogDisksCount $tLogDiskCount `
            -sqlLogDiskSizeInGB $tLogDiskSize `
            -logPath $tLogDiskPath `
            -SQLConnectivity $SQLConnectivity `
            -SQLConnectivityPort $SQLConnectivityPort `
            -location $Location `
            -AsJob
  
            ""
            "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template DOMAINJOIN"
            ""

        }
    if($templateType.ToUpper() -eq "NODOMAINNOACCELNET")
        {
            
           
            Select-AzSubscription -SubscriptionName $vmSubscriptionName
            $date = get-date -Format yyyyMMddHHmm
            $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
            New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
            -TemplateUri $SQLVMNoDomainNoAccelNettemplateURI `
            -virtualMachineName $vmName `
            -virtualMachineSize $VMSize `
            -availabilitySetName $availabilitySetName `
            -availabilitySetEnabled $Availabilitysetenabled `
            -existingVirtualNetworkName $networkName `
            -existingVnetResourceGroup $networkRGName `
            -existingSubnetName $subnetName `
            -adminUsername $vmLocalAdminUserName `
            -adminPassword $vmLocalAdminPass `
            -imageOffer $imageOffer `
            -sqlSku $imageSku `
            -sqlLicense $SQLLicense `
            -storageWorkloadType $storageWorkloadType `
            -sqlDataDisksCount $dataDiskCount `
            -sqlDataDiskSizeInGB $dataDiskSize `
            -dataPath $dataDiskPath `
            -sqlTempDBDisksCount $tempDBDiskCount `
            -sqlTempDBDiskSizeInGB $tempDBDiskSize `
            -TempDBPath $tempDBDiskPath `
            -sqlLogDisksCount $tLogDiskCount `
            -sqlLogDiskSizeInGB $tLogDiskSize `
            -logPath $tLogDiskPath `
            -SQLConnectivity $SQLConnectivity `
            -SQLConnectivityPort $SQLConnectivityPort `
            -location $Location `
            -AsJob
  
            ""
            "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template DOMAINJOIN"
            ""

        }
    If($templateType.ToUpper() -eq "DOMAINJOINSQLFEATUREUNINSTALL")
        {
            
            
            Select-AzSubscription -SubscriptionName $vmSubscriptionName
            $date = get-date -Format yyyyMMddHHmm
            $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"

            New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
            -TemplateUri $DomainJoinSQLFeatureinstalltemplateURI `
            -virtualMachineName $vmName `
            -virtualMachineSize $VMSize `
            -availabilitySetName $availabilitySetName `
            -availabilitySetEnabled $Availabilitysetenabled `
            -existingVirtualNetworkName $networkName `
            -existingVnetResourceGroup $networkRGName `
            -existingSubnetName $subnetName `
            -imageOffer $imageOffer `
            -sqlSku $imageSku `
            -sqlLicense $SQLLicense `
            -vmAdminUsername $vmLocalAdminUserName `
            -vmAdminPassword $vmLocalAdminPass `
            -domainUserName $domainJoinKeyvaultSecretName `
            -DomainPassword $domainJoinPassword `
            -domainToJoin $domainToJoin `
            -ouPath $OUPath `
            -storageWorkloadType $storageWorkloadType `
            -sqlDataDisksCount $dataDiskCount `
            -sqlDataDiskSizeInGB $dataDiskSize `
            -dataPath $dataDiskPath `
            -sqlTempDBDisksCount $tempDBDiskCount `
            -sqlTempDBDiskSizeInGB $tempDBDiskSize `
            -TempDBPath $tempDBDiskPath `
            -sqlLogDisksCount $tLogDiskCount `
            -sqlLogDiskSizeInGB $tLogDiskSize `
            -logPath $tLogDiskPath `
            -SQLConnectivity $SQLConnectivity `
            -SQLConnectivityPort $SQLConnectivityPort `
            -SQLEngineEnabled $DBEngine `
            -SQLRSEnabled $SSRS `
            -SQLASEnabled $SSAS `
            -SQLDQClientEnabled $DQSClient `
            -SQLClientConnectivityToolsEnabled $SQLClientConn `
            -SQLMasterDataServicesEnabled $MasterDataServ `
            -SQLISEnabled $SSIS `
            -rServicesEnabled $rServices `
            -location $Location `
            -AsJob
  
            ""
            "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template DOMAINJOINSQLFEATUREUNINSTALL"
            ""

        }
        
    If($templateType.ToUpper() -eq "WINDOWSINSTALLWITHDATADISKS")
    {
            
            
        Select-AzSubscription -SubscriptionName $vmSubscriptionName
        $date = get-date -Format yyyyMMddHHmm
        $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
        New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
        -TemplateUri $WindowsDataDisksinstalltemplateURI `
        -virtualMachineName $vmName `
        -virtualMachineSize $VMSize `
        -availabilitySetName $availabilitySetName `
        -availabilitySetEnabled $Availabilitysetenabled `
        -existingVirtualNetworkName $networkName `
        -existingVnetResourceGroup $networkRGName `
        -existingSubnetName $subnetName `
        -vmAdminUsername $vmLocalAdminUserName `
        -vmAdminPassword $vmLocalAdminPass `
        -DomainPassword $domainJoinPassword `
        -keyVaultSecretName $domainJoinKeyvaultSecretName `
        -domainToJoin $domainToJoin `
        -ouPath $OUPath `
        -sqlDataDisksCount $dataDiskCount `
        -sqlDataDiskSizeInGB $dataDiskSize `
        -location $Location `
        -AsJob
  
        ""
        "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template WINDOWSINSTALLWITHDATADISKS"
        ""
    }
    If($templateType.ToUpper() -eq "DATASCIENCEVMWITHDATADISKS")
    {
            
            
        Select-AzSubscription -SubscriptionName $vmSubscriptionName
        $date = get-date -Format yyyyMMddHHmm
        $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
        New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
        -TemplateUri $DataScienceDataDisksinstalltemplateURI `
        -virtualMachineName $vmName `
        -virtualMachineSize $VMSize `
        -availabilitySetName $availabilitySetName `
        -availabilitySetEnabled $Availabilitysetenabled `
        -existingVirtualNetworkName $networkName `
        -existingVnetResourceGroup $networkRGName `
        -existingSubnetName $subnetName `
        -vmAdminUsername $vmLocalAdminUserName `
        -vmAdminPassword $vmLocalAdminPass `
        -DomainPassword $domainJoinPassword `
        -keyVaultSecretName $domainJoinKeyvaultSecretName `
        -domainToJoin $domainToJoin `
        -ouPath $OUPath `
        -sqlDataDisksCount $dataDiskCount `
        -sqlDataDiskSizeInGB $dataDiskSize `
        -location $Location `
        -AsJob
  
        ""
        "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template WINDOWSINSTALLWITHDATADISKS"
        ""
    }
    
    If($templateType.ToUpper() -eq "WINDOWSINSTALLWITHDATADISKSNOACCELNET")
    {
            
            
        Select-AzSubscription -SubscriptionName $vmSubscriptionName
        $date = get-date -Format yyyyMMddHHmm
        $jobname = "New-SQLVMDeployment-$($vmName)-$($date.ToString())"
            
        New-AzResourceGroupDeployment -Name $jobname -ResourceGroupName $resourceGroupName `
        -TemplateUri $WindowsDataDisksNoAccelNetinstalltemplateURI `
        -virtualMachineName $vmName `
        -virtualMachineSize $VMSize `
        -availabilitySetName $availabilitySetName `
        -availabilitySetEnabled $Availabilitysetenabled `
        -existingVirtualNetworkName $networkName `
        -existingVnetResourceGroup $networkRGName `
        -existingSubnetName $subnetName `
        -vmAdminUsername $vmLocalAdminUserName `
        -vmAdminPassword $vmLocalAdminPass `
        -DomainPassword $domainJoinPassword `
        -keyVaultSecretName $domainJoinKeyvaultSecretName `
        -domainToJoin $domainToJoin `
        -ouPath $OUPath `
        -sqlDataDisksCount $dataDiskCount `
        -sqlDataDiskSizeInGB $dataDiskSize `
        -location $Location `
        -AsJob
  
        ""
        "Finished starting VM Deployment for : $($vmName) in resourcegroup: $($resourceGroupName) in subscription: $($vmSubscriptionName) with template WINDOWSINSTALLWITHDATADISKS"
        ""
    }

}

