param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Files
)

$uncrustifyPath = "uncrustify"
$configFile = "uncrustify.cfg"

if ($Files.Count -eq 0) {
    Write-Host "Usage: .\uncrustify-wrapper.ps1 <files>"
    exit 1
}

foreach ($file in $Files) {
    if (Test-Path $file) {
        & $uncrustifyPath -c $configFile --replace --no-backup $file
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Formatted: $file"
        } else {
            Write-Host "Error formatting: $file"
        }
    } else {
        Write-Host "File not found: $file"
    }
} 