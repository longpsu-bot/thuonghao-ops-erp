param([Parameter(Mandatory=$true)][string]$OutputDirectory)
$ErrorActionPreference='Stop'
$atlasOutput=(Resolve-Path -LiteralPath $OutputDirectory).Path
$atlasManifest=Get-Content -LiteralPath (Join-Path $atlasOutput 'manifest.json') -Raw -Encoding utf8 | ConvertFrom-Json
$atlasNative=Join-Path $atlasOutput 'native-qa'
[void](New-Item -ItemType Directory -Path $atlasNative -Force)
$atlasExcel=New-Object -ComObject Excel.Application
$atlasExcel.Visible=$false
$atlasExcel.DisplayAlerts=$false
$atlasExcel.AutomationSecurity=3
$atlasReport=@()
try {
  foreach($atlasFile in ($atlasManifest.files | Where-Object { $_.name.EndsWith('.xlsx') })) {
    $atlasClean=Join-Path $atlasOutput $atlasFile.name
    $atlasHash=(Get-FileHash -LiteralPath $atlasClean -Algorithm SHA256).Hash
    $atlasBook=$atlasExcel.Workbooks.Open($atlasClean,0,$true)
    $atlasSheets=@()
    try {
      $atlasIndex=0
      foreach($atlasSheetRecord in $atlasFile.sheets) {
        $atlasIndex++
        $atlasSheet=$atlasBook.Worksheets.Item($atlasSheetRecord.name)
        $atlasPdf=Join-Path $atlasNative ($atlasFile.name.Replace('.xlsx',"-sheet-$atlasIndex.pdf"))
        $atlasSheet.ExportAsFixedFormat(0,$atlasPdf)
        if($atlasSheet.VPageBreaks.Count -ne 0) { throw "HORIZONTAL_CROPPING: $($atlasFile.name) $($atlasSheet.Name)" }
        $atlasSheets+=@{name=$atlasSheet.Name;pdf=[IO.Path]::GetFileName($atlasPdf);horizontal_page_breaks=@($atlasSheet.HPageBreaks | ForEach-Object {$_.Location.Row});vertical_page_breaks=$atlasSheet.VPageBreaks.Count;print_titles=$atlasSheet.PageSetup.PrintTitleRows}
      }
      $atlasSaved=Join-Path $atlasNative $atlasFile.name.Replace('.xlsx','-NATIVE-SAVE-TEST-ONLY.xlsx')
      $atlasBook.SaveAs($atlasSaved,51)
    } finally {$atlasBook.Close($false)}
    $atlasReopened=$atlasExcel.Workbooks.Open($atlasSaved,0,$true)
    $atlasQuantityCount=0
    try {
      foreach($atlasSheetRecord in $atlasFile.sheets) {
        $atlasSheet=$atlasReopened.Worksheets.Item($atlasSheetRecord.name)
        foreach($atlasCell in $atlasSheetRecord.cells) {
          if($atlasCell.quantity -or ($atlasCell.value -is [string] -and $atlasCell.value -match '^\d+\.\d{1,6}$')) {
            $atlasValue=$atlasSheet.Range($atlasCell.address).Value2
            if($atlasValue -isnot [string] -or $atlasValue -cne $atlasCell.value) {throw "EXACT_TEXT_LOST: $($atlasFile.name) $($atlasCell.address)"}
            if($atlasCell.quantity -and ($atlasSheet.Range($atlasCell.address).NumberFormat -cne '@' -or $atlasSheet.Range($atlasCell.address).HorizontalAlignment -ne -4152)) {throw "QUANTITY_STYLE_LOST: $($atlasFile.name) $($atlasCell.address)"}
            $atlasQuantityCount++
          }
        }
      }
    } finally {$atlasReopened.Close($false)}
    if((Get-FileHash -LiteralPath $atlasClean -Algorithm SHA256).Hash -ne $atlasHash) {throw 'CLEAN_SPECIMEN_CHANGED'}
    $atlasReport+=@{file=$atlasFile.name;normal_open=$true;native_save_reopen=$true;clean_unchanged=$true;exact_text_checks=$atlasQuantityCount;sheets=$atlasSheets}
  }
  @{excel_version=$atlasExcel.Version;workbooks=$atlasReport} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $atlasOutput 'excel-report.json') -Encoding utf8
  Write-Output "Native Excel open/save/reopen and pagination checked for $($atlasReport.Count) clean workbooks."
} finally {$atlasExcel.Quit();[void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($atlasExcel)}
