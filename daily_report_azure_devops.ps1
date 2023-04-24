# Parameters
$devOpsUrl = "https://dev.azure.com/Organization_name" #Replace Organize_name with your own organization name when you login Azure DevOps.
$apiToken = "<Access Token>" #Replace this <Access Token> with your own access token ( must have administrator privileges )

# Set the headers for API requests
$headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":$($apiToken)"))
}

# Get the current date
$today = (Get-Date).ToString("yyyy-MM-dd")

# Function to fetch all pages of a given API request
function GetAllPages($url) {
    $page = 1
    $allResults = @()

    do {
        $pagedUrl = "${url}&`$top=100&`$skip=$($allResults.Count)"
        $results = Invoke-RestMethod -Uri $pagedUrl -Headers $headers -Method Get
        $allResults += $results.value
    } while ($results.value.Count -gt 0)

    return $allResults
}

# Get all projects
$projectsUrl = "$devOpsUrl/_apis/projects?api-version=6.0"

$projects = GetAllPages $projectsUrl
Write-Host "Number of projects found: $($projects.Count)"

# Initialize the daily report
$report = @{}


# Iterate through the projects
foreach ($project in $projects) {
    Write-Host "Processing project $($project.name)"
    
    # Get the project repositories
    $reposUrl = "$devOpsUrl/$($project.id)/_apis/git/repositories?api-version=6.0"
    Write-Host "Repos URL: $reposUrl" # Add this line to print the reposUrl
    $repos = (Invoke-RestMethod -Uri $reposUrl -Headers $headers).value
    Write-Host "Number of repositories found for $($project.name): $($repos.Count)"

    # Iterate through the repositories
    foreach ($repo in $repos) {
        Write-Host "Processing repository $($repo.name)"
        
        # Get the repository branches
        $branchesUrl = "$devOpsUrl/$($project.id)/_apis/git/repositories/$($repo.id)/refs?filter=heads&api-version=6.0"
        $branches = (Invoke-RestMethod -Uri $branchesUrl -Headers $headers).value
        Write-Host "Number of branches found for $($repo.name): $($branches.Count)"
        
        # Iterate through the branches
        # Iterate through the branches
            foreach ($branch in $branches) {
                $branchName = $branch.name.Replace("refs/heads/", "")
                Write-Host "Processing branch $($branch.name)"
                Write-Host "After Replace: $($branchName)"

                # Check if the branch name is not empty
                if (![string]::IsNullOrEmpty($branchName)) {
                    # Get the branch commits
                    $commitsUrl = "$devOpsUrl/$($project.id)/_apis/git/repositories/$($repo.id)/commits?searchCriteria.itemVersion.version=$($branchName)&searchCriteria.fromDate=$todayT00&searchCriteria.toDate=$todayT23&api-version=6.0"

                    Write-Host "Commits URL: $commitsUrl"
                    try {
                        $commits = (Invoke-RestMethod -Uri $commitsUrl -Headers $headers).value
                    } catch {
                        Write-Host "Error fetching commits for branch $($branchName): $($_.Exception.Message)"
                        continue
                    }

                    # Filter commits by date, and populate the report
                    foreach ($commit in $commits) {
                        $commitDate = (Get-Date -Date $commit.author.date).ToString("yyyy-MM-dd")

                        if ($commitDate -eq $today) {
                            $userName = $commit.author.name
                            $commitMessage = $commit.comment

                            if (![string]::IsNullOrEmpty($userName)) {
                                if (-not $report.ContainsKey($userName)) {
                                    $report[$userName] = @()
                                }
                                $report[$userName] += @{
                                    ProjectName = $project.name
                                    RepoName = $repo.name
                                    BranchName = $branchName
                                    CommitMessage = $commitMessage
                                }
                            } else {
                                Write-Host "Skipping commit with missing user name"
                            }
                        }
                    }
                } else {
                    Write-Host "Skipping branch with missing name"
                }
            }

        }
    }



# Create a report string
$reportString = "Azure DevOps Daily Push Report - $today`n`n"

foreach ($user in $report.Keys) {
    $reportString += "User: $user`n"
    $reportString += "Projects, Repositories, and Commit Messages:`n"
    foreach ($item in $report[$user]) {
        $reportString += "  - Project: $($item.ProjectName), Repo: $($item.RepoName), Branch: $($item.BranchName), Commit Message: $($item.CommitMessage)`n"
    }
    $reportString += "`n"
}

# Display the daily report
Write-Host $reportString

# Save the daily report to a file
$filePath = "D:\daily_push\AzureDevOps-Daily-Push-Report-$today.txt"
Set-Content -Path $filePath -Value $reportString
