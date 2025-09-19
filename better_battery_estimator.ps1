# Initialize an empty array to store battery readings
$log = @()

# Set how many readings we want to keep for our moving average
$max_entries = 10

# Start an infinite loop to keep checking battery status
while ($true) {
	
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
    $log += $entry
	
    # If we have more than $maxEntries, trim the oldest ones
    if ($log.Count -gt $max_entries) {
        # Keep only the last $max_entries readings
        $log = $log[-$max_entries..-1]
    }
	
    # If we have at least two readings, we can estimate remaining battery time
    if ($log.Count -ge 2) {
		$runtime_sum = 0
		for ($i=0; $i -lt $log.Count; $i++) {
			$this_entry = $log[$i]
			$runtime_sum = $runtime_sum + $this_entry.runtime
		}
		
		$average_runtime = [math]::Round(($runtime_sum / $log.Count), 2)
		
		Write-Host "Battery Charge Remaining: " $log[-1].percent
		Write-Host "Battery Time Remaining: " $average_runtime
    } else {
        # Not enough data yet to estimate
        Write-Host "Battery: $percent% | Gathering data..."
    }
	
    # Wait 2 seconds before checking again
    Start-Sleep -Seconds 2
}
