# Initialize an empty array to store battery readings
$log = @()

# Set how many readings we want to keep for our moving average
$max_entries = 10

# Start an infinite loop to keep checking battery status
while ($true) {

    # Get battery info using Windows Management Instrumentation (WMI)
    $battery = Get-WmiObject -Class Win32_Battery

    # Extract the current battery percentage
    $percent = $battery.EstimatedChargeRemaining
	$run_time = $battery.EstimatedRunTime
	Write-Host $run_time

    # Get the current timestamp
    $timestamp = Get-Date
	# Write-Host "$timestamp$"

    # Create a custom object to store this reading
    $entry = [PSCustomObject]@{
        Time = $timestamp
        Percent = $percent
    }

    # Add the new entry to our log array
    $log += $entry

    # If we have more than $maxEntries, trim the oldest ones
    if ($log.Count -gt $maxEntries) {
        # Keep only the last $maxEntries readings
        $log = $log[-$maxEntries..-1]
    }

    # If we have at least two readings, we can estimate battery drain rate
    if ($log.Count -ge 2) {
        # Get the first and last readings in the log
        $start = $log[0]
        $end = $log[-1]

        # Calculate how much battery was used
        $deltaPercent = $start.Percent - $end.Percent

        # Calculate how much time passed (in minutes)
        $deltaTime = ($end.Time - $start.Time).TotalMinutes

        # If battery was actually used (i.e., not charging or idle)
        if ($deltaPercent -gt 0) {
            # Calculate the average drain rate: percent per minute
            $rate = $deltaPercent / $deltaTime

            # Estimate how many minutes are left at this rate
            $estimatedMinutesLeft = $end.Percent / $rate

            # Print the result
            Write-Host "Battery: $percent% | Estimated time left: $([math]::Round($estimatedMinutesLeft)) minutes"
        } else {
            # If battery didn't drain, we can't estimate yet
            Write-Host "Battery: $percent% | Estimating..."
        }
    } else {
        # Not enough data yet to estimate
        Write-Host "Battery: $percent% | Gathering data..."
    }

    # Wait 2 seconds before checking again
    Start-Sleep -Seconds 2
}