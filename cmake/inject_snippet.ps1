param (
    [string]$HtmlPath,
    [string]$SnippetPath
)

# read entire files
$html    = Get-Content -Raw $HtmlPath
$snippet = Get-Content -Raw $SnippetPath

# the exact loader tag you want to anchor on
$scriptTag = '<script async type="text/javascript" src="raylib-cpp-cmake-template.js"></script>'

# build the replacement: snippet, newline, then the script tag (and a newline after, if you like)
$injected = "$snippet`n$scriptTag"

# perform the replace (escape the pattern so any regex‑chars in it are literal)
$pattern = [Regex]::Escape($scriptTag)
$html    = $html -replace $pattern, $injected

# write back out
Set-Content -Encoding UTF8 -Path $HtmlPath -Value $html
