# Initialize an empty array to store battery readings
$script:log = @()

# Load Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# Create the form (the window)
$form = New-Object System.Windows.Forms.Form
$form.Text = "Battery Estimator"
$form.Size = New-Object System.Drawing.Size(450,350)
$form.StartPosition = "CenterScreen"

# Create a label to show battery info
$label = New-Object System.Windows.Forms.Label
$label.AutoSize = $true
$label.Location = New-Object System.Drawing.Point(10,10)
$label.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($label)

# Create the chart
$chart = New-Object System.Windows.Forms.DataVisualization.Charting.Chart
$chart.Size = New-Object System.Drawing.Size(400, 250)
$chart.Location = New-Object System.Drawing.Point(10, 60)

# Create chart area
$chartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
$chartArea.AxisX.Title = "Entry #"
$chartArea.AxisY.Title = "Runtime (min)"
$chart.ChartAreas.Add($chartArea)

# Create series
$series = New-Object System.Windows.Forms.DataVisualization.Charting.Series
$series.Name = "battery_run_time"
$series.ChartType = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]::Line
$chart.Series.Add($series)

# Add chart to form
$form.Controls.Add($chart)

# Set how many readings we want to keep for our moving average
$max_entries = 200

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
	
	$chart.Series["battery_run_time"].Points.Clear()
	
    # If we have at least two readings, we can estimate remaining battery time
    if ($script:log.Count -ge 2) {
		$runtime_sum = 0
		for ($i=0; $i -lt $script:log.Count; $i++) {
			$this_entry = $script:log[$i]
			$runtime_sum = $runtime_sum + $this_entry.runtime
			
			$chart.Series["battery_run_time"].Points.AddXY($i + 1, $script:log[$i].runtime)
		}
		
		$average_runtime = [math]::Round(($runtime_sum / $script:log.Count))
		$hours = [math]::Floor($average_runtime / 60)
		$minutes = $average_runtime % 60
		
		$label.Text = "Battery Charge: $percent %`nBattery Time Remaining: $hours h $minutes m"
    } else {
        # Not enough data yet to estimate
        $label.Text = "Gathering data..."
    }
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 300 # in ms
$timer.Add_Tick({ update_battery_estimate })
$timer.Start()

$form.Add_Shown({ update_battery_estimate })
[System.Windows.Forms.Application]::Run($form)
