# Parameters
$gitLabUrl = "http://gitlab.com"  #Gitlab instance.
$apiToken = "<Access Token>" #Admin access token inorder to get all users ( Administrator request )

# Set the headers for API requests
$headers = @{
    "Private-Token" = $apiToken
}

# Get the current date
$today = (Get-Date).ToString("yyyy-MM-dd")


# Function to fetch all pages of a given API request
function GetAllPages($url) {
    $page = 1
    $allResults = @()

    do {
        $pagedUrl = "${url}&page=${page}"
        $results = Invoke-RestMethod -Uri $pagedUrl -Headers $headers
        $allResults += $results
        $page++
    } while ($results.Count -gt 0)

    return $allResults
}

# Get all projects
$projectsUrl = "$gitLabUrl/api/v4/projects?simple=true&per_page=100"

$projects = GetAllPages $projectsUrl
Write-Host "Number of projects found: $($projects.Count)"

# Initialize the daily report
$report = @{}

# Iterate through the projects
foreach ($project in $projects) {
    # Get the project branches
    $branchesUrl = "$gitLabUrl/api/v4/projects/$($project.id)/repository/branches?per_page=100"
    $branches = GetAllPages $branchesUrl

    # Debug: Print the commits for each project
    Write-Host "Commits for project $($project.name):"
    $filteredCommits = $commits | Where-Object { (Get-Date -Date $_.created_at -UFormat "%Y-%m-%d") -ge $today -and (Get-Date -Date $_.created_at -UFormat "%Y-%m-%d") -le $nextDay }
    Write-Host ($filteredCommits | Format-List | Out-String)


    # Iterate through the branches
    foreach ($branch in $branches) {
        # Get the branch commits
        $commitsUrl = "$gitLabUrl/api/v4/projects/$($project.id)/repository/commits?ref_name=$($branch.name)&since=$today&until=$nextDay&per_page=100"
        Write-Host "Commits URL: $commitsUrl"
        $commits = GetAllPages $commitsUrl

        # Debug: Print the commits for each branch
        Write-Host "Commits for branch $($branch.name):"
        Write-Host ($commits | Format-List | Out-String)

        # Filter commits by date, and populate the report
        foreach ($commit in $commits) {
            $commitDate = (Get-Date -Date $commit.created_at).ToString("yyyy-MM-dd")

            if ($commitDate -eq $today) {
                $userName = $commit.author_name
                $commitMessage = $commit.title

                if (-not $report.ContainsKey($userName)) {
                    $report[$userName] = @()
                }
                $report[$userName] += @{
                ProjectName = $project.name
                BranchName = $branch.name
                CommitMessage = $commitMessage
                }
            }
        }
    }
}

# Create a report string
$reportString = "GitLab Daily Push Report - $today`n`n"

foreach ($user in $report.Keys) {
    $reportString += "User: $user`n"
    $reportString += "Projects and Commit Messages:`n"
    foreach ($item in $report[$user]) {
        $reportString += "  - Project: $($item.ProjectName), Branch: $($item.BranchName), Commit Message: $($item.CommitMessage)`n"
    }

    $reportString += "`n"
}

# Display the daily report
Write-Host $reportString


# Save the daily report to a file
$filePath = "D:\daily_push\GitLab-Daily-Push-Report-$today.txt"
Set-Content -Path $filePath -Value $reportString
