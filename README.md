# InventoryScanner

InventoryScanner is a PowerShell-based inventory scanning tool that replicates and extends the functionality of Microsoft's MAPScan. 
It collects detailed system information from multiple sources—including local machines, Active Directory (AD)-joined devices, and Entra (Azure AD)-joined devices—and exports the data into interactive HTML reports (with filtering and charts) as well as CSV spreadsheets for further analysis.

## Features

- **Multi-Source Inventory Collection:**
  - **Local Devices:** Always scans the local machine.
  - **AD-Joined Devices:** Optionally scans devices from Active Directory (when supplied with a domain controller via the `-ADServer` parameter).
  - **Entra (Azure AD)-Joined Devices:** Optionally scans devices registered in Azure AD using the `-Entra` switch.
- **Extended Data Collection:**
  - **System Information:** OS, hardware, CPU, memory, virtualization status.
  - **SQL Services:** Checks for SQL Database Engine, Integration Services (SSIS), and Reporting Services (SSRS).
  - **Additional Details:** BIOS info, disk inventory (free/total space), network adapter details, last boot time, and system uptime.
- **Reporting:**
  - **HTML Reports:** Colorful and interactive HTML reports with built-in JavaScript filtering and charts (powered by Chart.js).
  - **CSV Exports:** Spreadsheets for further reporting or integration into other systems.

## Requirements

- **PowerShell 5.1 or later** (or PowerShell Core if adapted).
- **Windows Management Instrumentation (WMI/CIM) access** for local and remote scanning.
- **RSAT (Remote Server Administration Tools)** with the **Active Directory module** (if scanning AD-joined devices).
- **AzureAD module** (if scanning Entra/Azure AD devices). Install it using:

  ```powershell
  Install-Module -Name AzureAD
  ```
- **Internet connectivity** (for Chart.js to load from the CDN when viewing HTML reports).

## Installation

1. Clone or download this repository:
   ```
   git clone https://github.com/tomblanchard312/InventoryScanner.git
   ```
2. Save the main script as InventoryScanner.ps1.
3. Adjust the file paths in the script as needed (for both HTML and CSV outputs).

## Usage

Run the script in PowerShell with the following options:

### Local Only:

```powershell
.\InventoryScanner.ps1
```

### Local and AD-Joined Devices:

```powershell
.\InventoryScanner.ps1 -ADServer "YourDC.yourdomain.com"
```

### Local, AD-Joined, and Entra-Joined Devices:

```powershell
.\InventoryScanner.ps1 -ADServer "YourDC.yourdomain.com" -Entra
```

## Parameters

- `-ADServer`: Provide the fully qualified domain name (FQDN) of a domain controller to query AD for computer objects.
- `-Entra`: Include this switch to scan for Entra (Azure AD)-joined devices. The script uses the AzureAD module for this purpose.

## Output

The script generates two types of outputs for each category (Local, AD, Entra):

### HTML Reports:
Interactive HTML reports (with filtering and charts) are generated. Open these in a modern web browser.

### CSV Files:
CSV exports of the inventory data for use in Excel or other reporting tools.

Output file paths are defined in the script and can be adjusted as needed.

## Customization

### Extended Data Collection:
Modify the `Get-InventoryForComputer` function to add or adjust CIM/WMI queries for additional data (e.g., software inventory, Windows roles, etc.).

### HTML Report Styling:
Customize the CSS and JavaScript within the `Generate-HTMLReport` function to adjust the look and interactive features of your reports.

### Service Checks:
The script checks for SQL-related services based on common service name patterns. Update these patterns if needed for your environment.

## Troubleshooting

- Ensure required modules (ActiveDirectory, AzureAD) are installed and available.
- Verify network connectivity and permissions for remote WMI/CIM queries.
- If charts do not load properly in HTML reports, check your internet connectivity for access to the Chart.js CDN.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Credits

This script is inspired by Microsoft MAPScan and was developed to provide an extended, multi-source inventory tool for Windows environments. Contributions, enhancements, and suggestions are welcome!