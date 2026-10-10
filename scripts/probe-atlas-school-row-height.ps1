param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$atlasHeightOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
$atlasHeightManifest = Get-Content -LiteralPath (Join-Path $atlasHeightOutput 'manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
$atlasHeightFile = $atlasHeightManifest.files | Where-Object { $_.sheets.schoolRows.Count -gt 0 } | Select-Object -First 1
if (-not $atlasHeightFile) { throw 'SCHOOL_ROW_FIXTURE_REQUIRED' }
$atlasHeightPath = Join-Path $atlasHeightOutput $atlasHeightFile.name
$atlasHeightHash = (Get-FileHash -LiteralPath $atlasHeightPath -Algorithm SHA256).Hash
$atlasHeightExcel = New-Object -ComObject Excel.Application
$atlasHeightExcel.Visible = $false
$atlasHeightExcel.DisplayAlerts = $false
$atlasHeightExcel.AutomationSecurity = 3
$atlasHeightBook = $null
$atlasHeightScratch = $null
try {
  $atlasHeightBook = $atlasHeightExcel.Workbooks.Open($atlasHeightPath,0,$true)
  $atlasHeightScratch = $atlasHeightExcel.Workbooks.Add()
  $atlasHeightScratch.Styles.Item('Normal').Font.Name = $atlasHeightBook.Styles.Item('Normal').Font.Name
  $atlasHeightScratch.Styles.Item('Normal').Font.Size = $atlasHeightBook.Styles.Item('Normal').Font.Size
  $atlasHeightProbe = $atlasHeightScratch.Worksheets.Item(1)
  $atlasHeightRecord = $atlasHeightFile.sheets | Where-Object { $_.schoolRows | Where-Object { $_.firstColumn -eq $_.lastColumn } } | Select-Object -First 1
  $atlasHeightSingle = $atlasHeightRecord.schoolRows | Where-Object { $_.firstColumn -eq $_.lastColumn } | Select-Object -First 1
  if (-not $atlasHeightSingle) { throw 'SINGLE_SCHOOL_COLUMN_FIXTURE_REQUIRED' }
  $atlasHeightSheet = $atlasHeightBook.Worksheets.Item($atlasHeightRecord.name)
  # Copy UI ColumnWidth exactly. OOXML width is not the same UI property.
  $atlasHeightProbe.Columns.Item(1).ColumnWidth = $atlasHeightSheet.Columns.Item($atlasHeightSingle.firstColumn).ColumnWidth
  $atlasHeightChecks = @()
  foreach ($atlasHeightBold in @($false,$true)) {
    foreach ($atlasHeightCount in 1..15) {
      [void]$atlasHeightProbe.Cells.Clear()
      $atlasHeightCell = $atlasHeightProbe.Range('A1')
      $atlasHeightCell.Value2 = (@('DÒNG') * $atlasHeightCount) -join "`n"
      $atlasHeightCell.Font.Name = 'Times New Roman'
      $atlasHeightCell.Font.Size = 14
      $atlasHeightCell.Font.Bold = $atlasHeightBold
      $atlasHeightCell.WrapText = $true
      [void]$atlasHeightCell.EntireRow.AutoFit()
      $atlasHeightChecks += [ordered]@{
        bold=$atlasHeightBold; explicitLines=$atlasHeightCount
        autoFitHeight=[double]$atlasHeightCell.RowHeight
        ownerHeight=(28+16*($atlasHeightCount-1))
        widthPoints=[double]$atlasHeightCell.Width
      }
    }
  }
  foreach ($atlasHeightRow in $atlasHeightRecord.schoolRows) {
    if ($atlasHeightRow.firstColumn -ne $atlasHeightRow.lastColumn) { continue }
    [void]$atlasHeightProbe.Cells.Clear()
    $atlasHeightCell = $atlasHeightProbe.Range('A1')
    $atlasHeightCell.Value2 = $atlasHeightRow.text
    $atlasHeightCell.Font.Name = 'Times New Roman'
    $atlasHeightCell.Font.Size = 14
    $atlasHeightCell.Font.Bold = $atlasHeightRow.bold
    $atlasHeightCell.WrapText = $true
    [void]$atlasHeightCell.EntireRow.AutoFit()
    $atlasHeightChecks += [ordered]@{
      actualAddress=$atlasHeightRow.address
      nativeAutoFitHeight=[double]$atlasHeightCell.RowHeight
      allocated=[double]$atlasHeightSheet.Range($atlasHeightRow.address).RowHeight
      widthPoints=[double]$atlasHeightCell.Width
      actualWidthPoints=[double]$atlasHeightSheet.Range($atlasHeightRow.address).Width
    }
  }
  if ((Get-FileHash -LiteralPath $atlasHeightPath -Algorithm SHA256).Hash -cne $atlasHeightHash) { throw 'READ_ONLY_FIXTURE_CHANGED' }
  [ordered]@{
    excelVersion=[string]$atlasHeightExcel.Version
    excelBuild=[string]$atlasHeightExcel.Build
    normalFont=[string]$atlasHeightBook.Styles.Item('Normal').Font.Name
    font='Times New Roman'; fontSizePoints=14
    interpretation='AutoFit observations only; native rendered PDF text and visual bounds are required to establish clipping.'
    checks=$atlasHeightChecks
  } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $atlasHeightOutput 'school-row-height-investigation.json') -Encoding utf8
  Write-Output "Recorded $($atlasHeightChecks.Count) native AutoFit observations without changing the fixture."
} finally {
  if ($atlasHeightScratch) { $atlasHeightScratch.Close($false) }
  if ($atlasHeightBook) { $atlasHeightBook.Close($false) }
  $atlasHeightExcel.Quit()
  [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($atlasHeightExcel)
}
