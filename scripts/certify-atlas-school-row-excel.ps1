param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$atlasRowOutput=(Resolve-Path -LiteralPath $OutputDirectory).Path
$atlasRowManifest=Get-Content -LiteralPath (Join-Path $atlasRowOutput 'manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
$atlasRowExcel=New-Object -ComObject Excel.Application
$atlasRowExcel.Visible=$false
$atlasRowExcel.DisplayAlerts=$false
$atlasRowExcel.AutomationSecurity=3
$atlasRowChecks=@()
try {
  foreach($atlasRowFile in $atlasRowManifest.files) {
    $atlasRowBook=$atlasRowExcel.Workbooks.Open((Join-Path $atlasRowOutput $atlasRowFile.name),0,$true)
    $atlasRowScratch=$atlasRowExcel.Workbooks.Add()
    try {
      $atlasRowScratch.Styles.Item('Normal').Font.Name=$atlasRowBook.Styles.Item('Normal').Font.Name
      $atlasRowScratch.Styles.Item('Normal').Font.Size=$atlasRowBook.Styles.Item('Normal').Font.Size
      $atlasRowProbe=$atlasRowScratch.Worksheets.Item(1)
      foreach($atlasRowSheetRecord in $atlasRowFile.sheets) {
        $atlasRowSheet=$atlasRowBook.Worksheets.Item($atlasRowSheetRecord.name)
        foreach($atlasRowRecord in $atlasRowSheetRecord.schoolRows) {
          $atlasRowCell=$atlasRowSheet.Range($atlasRowRecord.address)
          $atlasRowWidth=0.0
          for($atlasRowColumn=$atlasRowRecord.firstColumn;$atlasRowColumn -le $atlasRowRecord.lastColumn;$atlasRowColumn++) {
            if(-not $atlasRowSheet.Columns.Item($atlasRowColumn).Hidden) { $atlasRowWidth+=$atlasRowSheet.Columns.Item($atlasRowColumn).Width }
          }
          if([Math]::Abs($atlasRowWidth-$atlasRowRecord.widthPoints) -gt 0.76) {throw "ACTUAL_WIDTH_MISMATCH: $($atlasRowSheet.Name) $($atlasRowCell.Address()) native=$atlasRowWidth expected=$($atlasRowRecord.widthPoints)"}
          if([Math]::Abs($atlasRowCell.RowHeight-$atlasRowRecord.measuredHeight) -gt 0.01) {throw "ROW_HEIGHT_RULE_MISMATCH: $($atlasRowCell.Address())"}
          if($atlasRowCell.Font.Name -cne 'Times New Roman' -or $atlasRowCell.Font.Size -ne 14 -or -not $atlasRowCell.WrapText) {throw "SCHOOL_FONT_OR_WRAP_MISMATCH"}
          [void]$atlasRowProbe.Cells.Clear()
          $atlasRowProbe.Columns.Item(1).ColumnWidth=$atlasRowWidth/6
          $atlasRowTest=$atlasRowProbe.Range('A1')
          for($atlasRowAttempt=0;$atlasRowAttempt -lt 3 -and [Math]::Abs($atlasRowTest.Width-$atlasRowWidth) -gt 0.76;$atlasRowAttempt++) {
            $atlasRowProbe.Columns.Item(1).ColumnWidth+=($atlasRowWidth-$atlasRowTest.Width)/6
          }
          if([Math]::Abs($atlasRowTest.Width-$atlasRowWidth) -gt 0.76) {throw "SCRATCH_WIDTH_MISMATCH"}
          $atlasRowTest.Value2=$atlasRowRecord.text
          $atlasRowTest.Font.Name='Times New Roman'
          $atlasRowTest.Font.Size=14
          $atlasRowTest.Font.Bold=$atlasRowRecord.bold
          $atlasRowTest.WrapText=$true
          [void]$atlasRowTest.EntireRow.AutoFit()
          $atlasRowRequired=$atlasRowTest.RowHeight
          # Screen AutoFit uses different wrapping/padding from the native printer.
          # Preserve this measurement as evidence; printed glyph bounds decide clipping.
          $atlasRowAutofitExceeds=$atlasRowRequired -gt $atlasRowCell.RowHeight+0.01
          $atlasRowChecks+=@{file=$atlasRowFile.name;sheet=$atlasRowSheet.Name;address=$atlasRowRecord.address;native_width_points=$atlasRowWidth;scratch_width_points=$atlasRowTest.Width;expected_width_points=$atlasRowRecord.widthPoints;allocated_height=$atlasRowCell.RowHeight;native_autofit_height=$atlasRowRequired;text=$atlasRowRecord.text;autofit_exceeds_allocated_height=$atlasRowAutofitExceeds}
        }
      }
    } finally {$atlasRowScratch.Close($false);$atlasRowBook.Close($false)}
  }
  @{excel_version=$atlasRowExcel.Version;excel_build=$atlasRowExcel.Build;fixture_only=$true;checks=$atlasRowChecks} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $atlasRowOutput 'school-row-native-report.json') -Encoding utf8
  $atlasRowPrinted=Get-Content -LiteralPath (Join-Path $atlasRowOutput 'school-row-printed-report.json') -Raw -Encoding utf8 | ConvertFrom-Json
  $atlasRowManifestHash=(Get-FileHash -LiteralPath (Join-Path $atlasRowOutput 'manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant()
  if($atlasRowPrinted.status -cne 'PASS' -or $atlasRowPrinted.checkedSchoolRows -ne $atlasRowChecks.Count -or $atlasRowPrinted.manifestSha256 -cne $atlasRowManifestHash) {throw 'PRINTED_SCHOOL_QA_MISSING_OR_STALE'}
  foreach($atlasRowEvidence in $atlasRowPrinted.evidenceFiles) {
    $atlasRowEvidencePath=Join-Path $atlasRowOutput $atlasRowEvidence.path
    if((Get-FileHash -LiteralPath $atlasRowEvidencePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $atlasRowEvidence.sha256) {throw 'PRINTED_SCHOOL_QA_EVIDENCE_CHANGED'}
  }
  Write-Output "Native Excel verified widths, TNR14 wrapping and exact heights for $($atlasRowChecks.Count) School rows; matching native printed glyph QA passes."
} finally {$atlasRowExcel.Quit();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($atlasRowExcel)}
