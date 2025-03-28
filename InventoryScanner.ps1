param(
    # Optional parameter: supply a domain controller FQDN for AD scanning.
    [string]$ADServer = "",
    # Optional switch: include Entra (Azure AD)–joined devices.
    [switch]$Entra
)

# ---------------------------
# Function: Get-InventoryForComputer
# ---------------------------
function Get-InventoryForComputer {
    param(
        [string]$ComputerName,
        [switch]$IsLocal
    )
    try {
        if ($IsLocal) {
            $os  = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop
            $cs  = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $cpu = Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop
        } else {
            $os  = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_OperatingSystem -ErrorAction Stop
            $cs  = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_ComputerSystem -ErrorAction Stop
            $cpu = Get-CimInstance -ComputerName $ComputerName -ClassName Win32_Processor -ErrorAction Stop
        }
        
        # Virtualization check (by model name)
        $vmIndicators = @("Virtual", "VMware", "Hyper-V", "KVM", "VirtualBox", "Xen")
        $isVirtual = $false
        foreach ($indicator in $vmIndicators) {
            if ($cs.Model -match $indicator) {
                $isVirtual = $true
                break
            }
        }
        
        # SQL Database Engine services check
        try {
            if ($IsLocal) {
                $sqlDBServices = Get-Service -Name "MSSQL*" -ErrorAction Stop
            } else {
                $sqlDBServices = Get-Service -ComputerName $ComputerName -Name "MSSQL*" -ErrorAction Stop
            }
            $sqlDB = $sqlDBServices | Where-Object { $_.Status -eq "Running" } | ForEach-Object { $_.Name } -join ", "
            if ([string]::IsNullOrEmpty($sqlDB)) { $sqlDB = "Installed but Not Running" }
        }
        catch {
            $sqlDB = "Not Found"
        }
        
        # SQL Integration Services (SSIS)
        try {
            if ($IsLocal) {
                $ssisServices = Get-Service -Name "MsDtsServer*" -ErrorAction Stop
            } else {
                $ssisServices = Get-Service -ComputerName $ComputerName -Name "MsDtsServer*" -ErrorAction Stop
            }
            $ssis = $ssisServices | Where-Object { $_.Status -eq "Running" } | ForEach-Object { $_.Name } -join ", "
            if ([string]::IsNullOrEmpty($ssis)) { $ssis = "Installed but Not Running" }
        }
        catch {
            $ssis = "Not Found"
        }
        
        # SQL Reporting Services (SSRS)
        try {
            if ($IsLocal) {
                $ssrsServices = Get-Service -Name "ReportServer*" -ErrorAction Stop
            } else {
                $ssrsServices = Get-Service -ComputerName $ComputerName -Name "ReportServer*" -ErrorAction Stop
            }
            $ssrs = $ssrsServices | Where-Object { $_.Status -eq "Running" } | ForEach-Object { $_.Name } -join ", "
            if ([string]::IsNullOrEmpty($ssrs)) { $ssrs = "Installed but Not Running" }
        }
        catch {
            $ssrs = "Not Found"
        }
        
        # BIOS Details
        $bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $biosInfo = if ($bios) { "Manufacturer: $($bios.Manufacturer), Version: $($bios.SMBIOSBIOSVersion)" } else { "N/A" }
        
        # Network Info (get first enabled adapter)
        $netAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE" -ErrorAction SilentlyContinue
        $networkInfo = if ($netAdapters) {
            $primaryAdapter = $netAdapters | Select-Object -First 1
            "IP: $($primaryAdapter.IPAddress[0]), MAC: $($primaryAdapter.MACAddress)"
        } else { "N/A" }
        
        # Disk Inventory: get local fixed disks (DriveType 3)
        $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
        $diskSummary = if ($disks) {
            ($disks | ForEach-Object { "$($_.DeviceID): $([math]::Round($_.FreeSpace/1GB,1))GB free of $([math]::Round($_.Size/1GB,1))GB" }) -join "; "
        } else { "N/A" }
        
        # Uptime / Last Boot
        $lastBoot = ([Management.ManagementDateTimeConverter]::ToDateTime($os.LastBootUpTime))
        $uptime = (Get-Date) - $lastBoot
        
        return [PSCustomObject]@{
            ComputerName             = $ComputerName
            OS                       = $os.Caption
            OSVersion                = $os.Version
            Manufacturer             = $cs.Manufacturer
            Model                    = $cs.Model
            IsVirtual                = $isVirtual
            TotalPhysicalMemoryBytes = $cs.TotalPhysicalMemory
            CPU                      = $cpu.Name
            CPU_Cores                = $cpu.NumberOfCores
            CPU_LogicalProcessors    = $cpu.NumberOfLogicalProcessors
            SQLDatabaseEngine        = $sqlDB
            SQLIntegrationServices   = $ssis
            SQLReportingServices     = $ssrs
            BIOS                     = $biosInfo
            NetworkInfo              = $networkInfo
            DiskSummary              = $diskSummary
            LastBoot                 = $lastBoot
            Uptime                   = "$([math]::Round($uptime.TotalDays,1)) days"
        }
    }
    catch {
        Write-Warning "Failed to query $ComputerName"
        return $null
    }
}

# ---------------------------
# Function: Generate-HTMLReport
# ---------------------------
function Generate-HTMLReport {
    param(
       [array]$Results,
       [string]$Title,
       [string]$OutputPath
    )
    $style = @"
<style>
    body {
        font-family: Arial, sans-serif;
        background-color: #f4f4f4;
        margin: 20px;
    }
    h1, h2 {
        color: #333;
        text-align: center;
    }
    p {
        text-align: center;
        font-size: 1.1em;
    }
    input[type="text"] {
        padding: 8px;
        width: 60%;
        font-size: 1em;
        margin-bottom: 20px;
        border: 1px solid #ccc;
        border-radius: 4px;
    }
    table {
        border-collapse: collapse;
        width: 100%;
        background-color: #fff;
        box-shadow: 0 2px 5px rgba(0,0,0,0.1);
    }
    th, td {
        border: 1px solid #ddd;
        padding: 10px;
        text-align: left;
    }
    th {
        background-color: #4CAF50;
        color: white;
    }
    tr:nth-child(even) {
        background-color: #f2f2f2;
    }
    .chart-container {
        display: flex;
        justify-content: space-around;
        flex-wrap: wrap;
        margin-top: 30px;
    }
    canvas {
        margin: 20px;
    }
</style>
"@
    if ($Results.Count -gt 0) {
        # Build an HTML table with an id for filtering
        $htmlBody = $Results | ConvertTo-Html -Fragment -PreContent "<h1>$Title</h1><p>Report generated on $(Get-Date)</p>" `
            -Property ComputerName, OS, OSVersion, Manufacturer, Model, IsVirtual, TotalPhysicalMemoryBytes, CPU, CPU_Cores, CPU_LogicalProcessors, SQLDatabaseEngine, SQLIntegrationServices, SQLReportingServices, BIOS, NetworkInfo, DiskSummary, LastBoot, Uptime
        $htmlBody = $htmlBody -replace "<table>", "<table id='inventoryTable'>"
        
        # Convert the inventory data to JSON for use in charts.
        $jsonData = $Results | ConvertTo-Json -Depth 5

        # Additional HTML for filtering and charts.
        $extraHtml = @"
<div style='text-align:center;'>
   <input type='text' id='filterInput' placeholder='Filter by server type (e.g., SQL, Virtual)...' onkeyup='filterTable()'>
</div>
<div class='chart-container'>
   <canvas id='sqlChart' width='400' height='400'></canvas>
   <canvas id='virtualChart' width='400' height='400'></canvas>
</div>
<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>
<script>
    // Filtering function for the inventory table
    function filterTable() {
        var input = document.getElementById('filterInput');
        var filter = input.value.toUpperCase();
        var table = document.getElementById('inventoryTable');
        var tr = table.getElementsByTagName('tr');
        for (var i = 1; i < tr.length; i++) {
            var tds = tr[i].getElementsByTagName('td');
            var shouldShow = false;
            for (var j = 0; j < tds.length; j++) {
                if (tds[j]) {
                    var txtValue = tds[j].textContent || tds[j].innerText;
                    if (txtValue.toUpperCase().indexOf(filter) > -1) {
                        shouldShow = true;
                        break;
                    }
                }
            }
            tr[i].style.display = shouldShow ? '' : 'none';
        }
    }
    
    // Use the embedded JSON data for chart calculations
    var inventoryData = $jsonData;
    
    var sqlCount = 0, nonSqlCount = 0;
    var virtualCount = 0, physicalCount = 0;
    inventoryData.forEach(function(item) {
         // If SQLDatabaseEngine is not "Not Found", assume SQL is installed
         if (item.SQLDatabaseEngine && item.SQLDatabaseEngine !== 'Not Found') {
             sqlCount++;
         } else {
             nonSqlCount++;
         }
         // Evaluate IsVirtual (it may be boolean or string)
         if (item.IsVirtual === true || item.IsVirtual.toString().toLowerCase() === 'true') {
             virtualCount++;
         } else {
             physicalCount++;
         }
    });
    
    // Create pie chart for SQL installation
    var ctx1 = document.getElementById('sqlChart').getContext('2d');
    var sqlChart = new Chart(ctx1, {
        type: 'pie',
        data: {
            labels: ['SQL Installed', 'SQL Not Installed'],
            datasets: [{
                data: [sqlCount, nonSqlCount],
                backgroundColor: ['#4CAF50', '#FF6384']
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'SQL Installation Distribution'
                }
            }
        }
    });
    
    // Create pie chart for Virtual vs. Physical
    var ctx2 = document.getElementById('virtualChart').getContext('2d');
    var virtualChart = new Chart(ctx2, {
        type: 'pie',
        data: {
            labels: ['Virtual', 'Physical'],
            datasets: [{
                data: [virtualCount, physicalCount],
                backgroundColor: ['#36A2EB', '#FFCE56']
            }]
        },
        options: {
            responsive: true,
            plugins: {
                title: {
                    display: true,
                    text: 'Virtual vs Physical Distribution'
                }
            }
        }
    });
</script>
"@
        $htmlBody += $extraHtml
    } else {
        $htmlBody = "<h1>$Title</h1><p>Report generated on $(Get-Date)</p><p style='text-align:center;font-size:1.2em;color:#555;'>No inventory data was found.</p>"
    }
    
    $htmlReport = "<html><head>$style<title>$Title</title></head><body>$htmlBody</body></html>"
    $htmlReport | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "HTML report generated at $OutputPath"
}

# ---------------------------
# Main Inventory Scanning and Reporting
# ---------------------------
# Arrays to hold results for each category.
$localResults = @()
$adResults    = @()
$entraResults = @()

# --- Local Device Inventory ---
$localComputers = @($env:COMPUTERNAME)
foreach ($computer in $localComputers) {
    Write-Host "Scanning local device: $computer..."
    $result = Get-InventoryForComputer -ComputerName $computer -IsLocal
    if ($result) { $localResults += $result }
}

# --- AD Joined Devices Inventory (if ADServer provided) ---
if ($ADServer -ne "") {
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
        Write-Host "Querying Active Directory at $ADServer..."
        $adComputers = Get-ADComputer -Filter * -Server $ADServer | Select-Object -ExpandProperty Name
        foreach ($computer in $adComputers) {
            Write-Host "Scanning AD device: $computer..."
            $result = Get-InventoryForComputer -ComputerName $computer
            if ($result) { $adResults += $result }
        }
    }
    catch {
        Write-Warning "Failed to query AD using server '$ADServer'. Error: $_"
    }
}

# --- Entra (Azure AD) Joined Devices Inventory (if –Entra switch is used) ---
if ($Entra) {
    try {
        Import-Module AzureAD -ErrorAction Stop
        Write-Host "Connecting to Azure AD..."
        Connect-AzureAD -ErrorAction Stop
        Write-Host "Querying Entra (Azure AD) for devices..."
        $entraDevices = Get-AzureADDevice | Select-Object -ExpandProperty DisplayName
        foreach ($computer in $entraDevices) {
            Write-Host "Scanning Entra device: $computer..."
            $result = Get-InventoryForComputer -ComputerName $computer
            if ($result) { $entraResults += $result }
        }
    }
    catch {
        Write-Warning "Failed to query Entra devices: $_"
    }
}

# ---------------------------
# Define output file paths (adjust these paths as needed)
# ---------------------------
$localHTML   = "C:\Path\To\NetworkInventoryReport_Local.html"
$adHTML      = "C:\Path\To\NetworkInventoryReport_AD.html"
$entraHTML   = "C:\Path\To\NetworkInventoryReport_Entra.html"

$localCSV    = "C:\Path\To\NetworkInventoryReport_Local.csv"
$adCSV       = "C:\Path\To\NetworkInventoryReport_AD.csv"
$entraCSV    = "C:\Path\To\NetworkInventoryReport_Entra.csv"

# ---------------------------
# Generate HTML Reports for each category.
# ---------------------------
Generate-HTMLReport -Results $localResults -Title "Local Device Inventory Report" -OutputPath $localHTML
if ($ADServer -ne "") {
    Generate-HTMLReport -Results $adResults -Title "AD Joined Device Inventory Report" -OutputPath $adHTML
}
if ($Entra) {
    Generate-HTMLReport -Results $entraResults -Title "Entra Joined Device Inventory Report" -OutputPath $entraHTML
}

# ---------------------------
# Export Data to CSV Spreadsheets for further reporting.
# ---------------------------
if ($localResults.Count -gt 0) {
    $localResults | Export-Csv -Path $localCSV -NoTypeInformation
    Write-Host "CSV export for local devices generated at $localCSV"
}
if ($adResults.Count -gt 0) {
    $adResults | Export-Csv -Path $adCSV -NoTypeInformation
    Write-Host "CSV export for AD devices generated at $adCSV"
}
if ($entraResults.Count -gt 0) {
    $entraResults | Export-Csv -Path $entraCSV -NoTypeInformation
    Write-Host "CSV export for Entra devices generated at $entraCSV"
}
