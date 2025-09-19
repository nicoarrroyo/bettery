# Initialize an empty array to store battery readings
$script:log = @()

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms

# Create the form (the window)
$form = New-Object System.Windows.Forms.Form
$form.Text = "Battery Estimator"
$form.Size = New-Object System.Drawing.Size(500,200)
$form.StartPosition = "CenterScreen"

# Create a label to show battery info
$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(30,40)
$label.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($label)

# Set how many readings we want to keep for our moving average
$max_entries = 20

# Start an infinite loop to keep checking battery status
function update_battery_estimate {
	
	# Get the current timestamp
    $timestamp = Get-Date
	
    # Get battery info using Windows Management Instrumentation (WMI)
    $battery = Get-WmiObject -Class Win32_Battery
	
    # Extract the current battery percentage
	$runtime = $battery.EstimatedRunTime
	$percent = $battery.EstimatedChargeRemaining
	
    # Create a custom object to store this reading
    $entry = [PSCustomObject]@{
        time = $timestamp
        runtime = $runtime
		percent = $percent
    }
	
    # Add the new entry to our log array
    $script:log += $entry
	
    # If we have more than $maxEntries, trim the oldest ones
    if ($script:log.Count -gt $max_entries) {
        # Keep only the last $max_entries readings
        $script:log = $script:log[-$max_entries..-1]
    }
	
    # If we have at least two readings, we can estimate remaining battery time
    if ($script:log.Count -ge 2) {
		$runtime_sum = 0
		for ($i=0; $i -lt $script:log.Count; $i++) {
			$this_entry = $script:log[$i]
			$runtime_sum = $runtime_sum + $this_entry.runtime
		}
		
		$average_runtime = [math]::Round(($runtime_sum / $script:log.Count))
		
		$label.Text = "Battery Charge: $percent %`nBattery Time Remaining: $average_runtime"
    } else {
        # Not enough data yet to estimate
        $label.Text = "Gathering data..."
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000 # in ms
$timer.Add_Tick({ update_battery_estimate })
$timer.Start()

$form.Add_Shown({ update_battery_estimate })
[System.Windows.Forms.Application]::Run($form)
