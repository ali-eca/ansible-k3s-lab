# PowerShell script to set up Kubernetes contexts for dev and prod environments on Windows 11
# Run this script after copying k3s-dev-kubeconfig.yaml and k3s-prod-kubeconfig.yaml to your Windows machine

param(
    [Parameter(Mandatory=$true)]
    [string]$DevKubeconfigPath,

    [Parameter(Mandatory=$true)]
    [string]$ProdKubeconfigPath
)

# Function to check if kubectl is installed
function Test-Kubectl {
    try {
        $kubectlVersion = kubectl version --client --short 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ kubectl is installed: $kubectlVersion" -ForegroundColor Green
            return $true
        }
    }
    catch {
        Write-Host "✗ kubectl is not installed or not in PATH" -ForegroundColor Red
        Write-Host "Please install kubectl from: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/" -ForegroundColor Yellow
        return $false
    }
}

# Function to merge kubeconfigs
function Merge-Kubeconfigs {
    param(
        [string]$DevPath,
        [string]$ProdPath
    )

    $kubeDir = "$env:USERPROFILE\.kube"
    $configPath = "$kubeDir\config"

    # Create .kube directory if it doesn't exist
    if (!(Test-Path $kubeDir)) {
        New-Item -ItemType Directory -Path $kubeDir -Force | Out-Null
        Write-Host "✓ Created .kube directory" -ForegroundColor Green
    }

    # Check if source files exist
    if (!(Test-Path $DevPath)) {
        Write-Host "✗ Dev kubeconfig not found: $DevPath" -ForegroundColor Red
        return $false
    }

    if (!(Test-Path $ProdPath)) {
        Write-Host "✗ Prod kubeconfig not found: $ProdPath" -ForegroundColor Red
        return $false
    }

    # Merge kubeconfigs
    try {
        kubectl config view --merge --flatten $DevPath $ProdPath | Out-File -FilePath $configPath -Encoding UTF8
        Write-Host "✓ Merged kubeconfigs into $configPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Failed to merge kubeconfigs: $_" -ForegroundColor Red
        return $false
    }
}

# Function to verify contexts
function Test-Contexts {
    try {
        $contexts = kubectl config get-contexts --no-headers 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ Available contexts:" -ForegroundColor Green
            $contexts | ForEach-Object {
                $parts = $_ -split '\s+'
                $current = if ($parts[0] -eq '*') { ' (current)' } else { '' }
                $name = $parts[-1]
                Write-Host "  - $name$current" -ForegroundColor Cyan
            }
            return $true
        }
    }
    catch {
        Write-Host "✗ Failed to get contexts: $_" -ForegroundColor Red
        return $false
    }
}

# Function to create context switching functions
function New-ContextSwitcher {
    $profilePath = $PROFILE

    $switcherScript = @"

# Kubernetes context switching functions
function Switch-ToDev {
    kubectl config use-context dev
    Write-Host "Switched to dev context" -ForegroundColor Green
}

function Switch-ToProd {
    kubectl config use-context prod
    Write-Host "Switched to prod context" -ForegroundColor Yellow
}

function Get-CurrentContext {
    kubectl config current-context
}

# Aliases for quick switching
Set-Alias kdev Switch-ToDev
Set-Alias kprod Switch-ToProd
Set-Alias kctx Get-CurrentContext

"@

    try {
        # Check if profile exists, create if not
        if (!(Test-Path $profilePath)) {
            New-Item -ItemType File -Path $profilePath -Force | Out-Null
        }

        # Check if functions already exist
        $existingContent = Get-Content $profilePath -Raw
        if ($existingContent -notmatch "Switch-ToDev") {
            Add-Content -Path $profilePath -Value $switcherScript
            Write-Host "✓ Added context switching functions to PowerShell profile" -ForegroundColor Green
            Write-Host "  Restart PowerShell or run '. `$PROFILE' to load functions" -ForegroundColor Cyan
        } else {
            Write-Host "✓ Context switching functions already exist in profile" -ForegroundColor Green
        }

        Write-Host "`nUsage:" -ForegroundColor White
        Write-Host "  Switch-ToDev    # Switch to dev context" -ForegroundColor Cyan
        Write-Host "  Switch-ToProd   # Switch to prod context" -ForegroundColor Cyan
        Write-Host "  Get-CurrentContext  # Show current context" -ForegroundColor Cyan
        Write-Host "  kdev            # Alias for Switch-ToDev" -ForegroundColor Cyan
        Write-Host "  kprod           # Alias for Switch-ToProd" -ForegroundColor Cyan
        Write-Host "  kctx            # Alias for Get-CurrentContext" -ForegroundColor Cyan

    }
    catch {
        Write-Host "✗ Failed to update PowerShell profile: $_" -ForegroundColor Red
    }
}

# Main script execution
Write-Host "Setting up Kubernetes contexts for dev and prod environments..." -ForegroundColor White
Write-Host "=" * 60 -ForegroundColor White

# Check prerequisites
if (!(Test-Kubectl)) {
    exit 1
}

# Merge kubeconfigs
if (!(Merge-Kubeconfigs -DevPath $DevKubeconfigPath -ProdPath $ProdKubeconfigPath)) {
    exit 1
}

# Verify setup
Test-Contexts

# Add convenience functions
New-ContextSwitcher

Write-Host "`nSetup complete! You can now use:" -ForegroundColor Green
Write-Host "  kubectl config use-context dev" -ForegroundColor Cyan
Write-Host "  kubectl config use-context prod" -ForegroundColor Cyan
Write-Host "  Or use the PowerShell functions: Switch-ToDev, Switch-ToProd" -ForegroundColor Cyan