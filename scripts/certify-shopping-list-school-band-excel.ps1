param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
$atlasOutput = (Resolve-Path -LiteralPath $OutputDirectory).Path
$atlasName = 'ShoppingList-SchoolBand-APlus-2026-09-17'
$atlasCleanPath = Join-Path $atlasOutput "$atlasName.xlsx"
$atlasEditedPath = Join-Path $atlasOutput "$atlasName-QUANTITY-EDIT-TEST-ONLY.xlsx"
$atlasCleanHash = (Get-FileHash -LiteralPath $atlasCleanPath -Algorithm SHA256).Hash
$atlasExcel = New-Object -ComObject Excel.Application
$atlasExcel.Visible = $false
$atlasExcel.DisplayAlerts = $false
try {
  # Open the production export READ-ONLY. Never save or edit the deliverable.
  $atlasBook = $atlasExcel.Workbooks.Open($atlasCleanPath,0,$true)
  try {
    $atlasSheet = $atlasBook.Worksheets.Item(1)
    if ($atlasSheet.ListObjects.Count -ne 1) { throw 'TABLE_MISSING' }
    if ($atlasSheet.Cells.Item(5,4).Value2 -ne '228.01' -or $atlasSheet.Cells.Item(5,15).Value2 -ne '228.010000') { throw 'CLEAN_QUANTITY_MISMATCH' }
    $atlasSheet.ExportAsFixedFormat(0,(Join-Path $atlasOutput "$atlasName.pdf"))
    $atlasBreaks = @($atlasSheet.HPageBreaks | ForEach-Object { $_.Location.Row })
    if ($atlasSheet.VPageBreaks.Count -ne 0) { throw 'HORIZONTAL_PAGE_CROPPING' }
    $atlasWidths = @(1..5 | ForEach-Object { [double]$atlasSheet.Columns.Item($_).Width })
  } finally { $atlasBook.Close($false) }

  # Copy FIRST. Only this explicitly named QA artifact is edited/native-saved.
  Copy-Item -LiteralPath $atlasCleanPath -Destination $atlasEditedPath -Force
  if ((Get-FileHash -LiteralPath $atlasEditedPath -Algorithm SHA256).Hash -ne $atlasCleanHash) { throw 'QA_COPY_MISMATCH' }
  $atlasBook = $atlasExcel.Workbooks.Open($atlasEditedPath,0,$false)
  try {
    $atlasSheet = $atlasBook.Worksheets.Item(1)
    $atlasSheet.Unprotect('ATLAS_SHOPPING_LIST_V2')
    $atlasSheet.Range('F:Q').EntireColumn.Hidden = $false
    $atlasFlat = @()
    foreach ($atlasRow in 4..$atlasSheet.UsedRange.Rows.Count) {
      if ($atlasSheet.Cells.Item($atlasRow,16).Value2 -eq 'DATA_LINE') {
        $atlasFlat += [pscustomobject]@{
          row=$atlasRow; ingredient=$atlasSheet.Cells.Item($atlasRow,2).Value2
          unit=$atlasSheet.Cells.Item($atlasRow,3).Value2; quantity=$atlasSheet.Cells.Item($atlasRow,4).Value2
          school_id=$atlasSheet.Cells.Item($atlasRow,11).Value2; school_name=$atlasSheet.Cells.Item($atlasRow,17).Value2
          line_id=$atlasSheet.Cells.Item($atlasRow,7).Value2; revision_id=$atlasSheet.Cells.Item($atlasRow,8).Value2
          ingredient_id=$atlasSheet.Cells.Item($atlasRow,13).Value2; unit_id=$atlasSheet.Cells.Item($atlasRow,14).Value2
          exported_quantity=$atlasSheet.Cells.Item($atlasRow,15).Value2
        }
      }
    }
    if ($atlasFlat.Count -ne 248 -or @($atlasFlat | Where-Object { -not $_.school_id -or -not $_.school_name }).Count -ne 0) { throw 'FLAT_DATA_INCOMPLETE' }
    [void]$atlasSheet.Range('A5:Q5').Copy()
    $atlasSheet.Range('F:Q').EntireColumn.Hidden = $true
    $atlasSheet.Protect('ATLAS_SHOPPING_LIST_V2')
    $atlasSheet.Cells.Item(5,4).Value2 = '12,5'
    $atlasBook.Save()
  } finally { $atlasBook.Close($false) }
  $atlasReopened = $atlasExcel.Workbooks.Open($atlasEditedPath,0,$true)
  try {
    if ($atlasReopened.Worksheets.Item(1).Cells.Item(5,4).Value2 -ne '12,5') { throw 'NATIVE_QUANTITY_LOST' }
    if ($atlasReopened.Worksheets.Item(1).Cells.Item(5,15).Value2 -ne '228.010000') { throw 'NATIVE_BASELINE_CHANGED' }
    if ($atlasReopened.Worksheets.Item(1).ListObjects.Item(1).Range.Columns.Count -ne 17) { throw 'NATIVE_TABLE_LOST' }
  } finally { $atlasReopened.Close($false) }
  if ((Get-FileHash -LiteralPath $atlasCleanPath -Algorithm SHA256).Hash -ne $atlasCleanHash) { throw 'CLEAN_DELIVERABLE_CHANGED' }
  $atlasReport = @{
    'A+' = @{
      clean_xlsx=$atlasCleanPath; clean_sha256=$atlasCleanHash; clean_unchanged=$true
      edited_test_only_xlsx=$atlasEditedPath
      normal_open_without_repair=$true; native_save=$true; native_reopen=$true
      column_widths_pt=$atlasWidths; page_start_rows=$atlasBreaks; vertical_page_breaks=0
      flat_data_rows=$atlasFlat.Count; flat_school_names='PASS'
      unhide_workflow='QA copy only: unprotect, unhide F:Q, copy DATA_LINE, rehide and protect'
      flat_data=$atlasFlat
    }
  }
  $atlasReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $atlasOutput 'excel-report.json') -Encoding utf8
} finally {
  $atlasExcel.Quit()
  [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($atlasExcel)
}
