$root = Get-Location
$address = [System.Net.IPAddress]::Parse('10.185.167.47')
$port = 8090
$listener = [System.Net.Sockets.TcpListener]::new($address, $port)
$listener.Start()
Write-Output "Serving $root at http://10.185.167.47:8090/"
while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $requestLine = $reader.ReadLine()
        if (-not $requestLine) {
            $stream.Close()
            $client.Close()
            continue
        }
        while ($reader.Peek() -ge 0) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { break }
        }
        $parts = $requestLine.Split(' ')
        $requestPath = $parts[1].Split('?')[0].TrimStart('/')
        $requestPath = [System.Uri]::UnescapeDataString($requestPath)
        if ([string]::IsNullOrEmpty($requestPath)) { $requestPath = 'index.html' }
        $filePath = Join-Path $root $requestPath
        if (-not (Test-Path $filePath)) {
            $responseBody = '404 Not Found'
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes($responseBody)
            $header = "HTTP/1.1 404 Not Found`r`nContent-Type: text/plain; charset=utf-8`r`nContent-Length: $($responseBytes.Length)`r`nConnection: close`r`n`r`n"
            $stream.Write([System.Text.Encoding]::ASCII.GetBytes($header), 0, $header.Length)
            $stream.Write($responseBytes, 0, $responseBytes.Length)
            $stream.Close()
            $client.Close()
            continue
        }
        $contentType = 'application/octet-stream'
        switch -Regex ($filePath) {
            '\.html?$' { $contentType = 'text/html; charset=utf-8'; break }
            '\.css$' { $contentType = 'text/css'; break }
            '\.js$' { $contentType = 'application/javascript'; break }
            '\.png$' { $contentType = 'image/png'; break }
            '\.jpe?g$' { $contentType = 'image/jpeg'; break }
            '\.svg$' { $contentType = 'image/svg+xml'; break }
            '\.json$' { $contentType = 'application/json'; break }
            '\.txt$' { $contentType = 'text/plain'; break }
        }
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        $header = "HTTP/1.1 200 OK`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $stream.Write([System.Text.Encoding]::ASCII.GetBytes($header), 0, $header.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
        $client.Close()
    } catch {
        Write-Warning "Server error: $_"
    }
}
$listener.Stop()
