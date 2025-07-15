param (
    [string]$HtmlPath,
    [string]$SnippetPath
)

$html = Get-Content -Raw $HtmlPath
$snippet = Get-Content -Raw $SnippetPath

# Build the replacement string first
$injected = "<head>`n$snippet"

# Do the replacement
$html = $html -replace '<head>', $injected

Set-Content -Encoding UTF8 $HtmlPath $html