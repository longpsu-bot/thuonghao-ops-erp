param(
  [string]$OutputPath = 'src/modules/atlas/documents/timesNewRoman14Metrics.json',
  [Parameter(Mandatory=$true)][string]$CalibrationWorkbookPath
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Numeric advances only: this script never copies or distributes font binaries.
$atlasRoot = Split-Path -Parent $PSScriptRoot
$atlasOutput = if ([IO.Path]::IsPathRooted($OutputPath)) { [IO.Path]::GetFullPath($OutputPath) } else { [IO.Path]::GetFullPath((Join-Path $atlasRoot $OutputPath)) }
$atlasCalibrationPath = (Resolve-Path -LiteralPath $CalibrationWorkbookPath).Path
$atlasCalibrationHash = (Get-FileHash -LiteralPath $atlasCalibrationPath -Algorithm SHA256).Hash.ToLowerInvariant()
$atlasProbe = Join-Path ([IO.Path]::GetTempPath()) ('atlas-font-width-' + [guid]::NewGuid() + '.xlsx')
$atlasWidths = @(0.25, 0.5, 1, 6, 8.43, 9, 12, 16, 18, 25, 28, 30, 36, 42, 110)
$atlasNode = @'
const ExcelJS = require('exceljs');
const workbook = new ExcelJS.Workbook();
const sheet = workbook.addWorksheet('Widths');
const widths = [0.25,0.5,1,6,8.43,9,12,16,18,25,28,30,36,42,110];
widths.forEach((width,index) => {
  sheet.getColumn(index+1).width = width;
  sheet.getCell(1,index+1).value = width;
  // A styled cell emits the same default Normal style as production exports.
  // An unstyled workbook omits styles and Excel substitutes its own template.
  sheet.getCell(1,index+1).font = { name: 'Times New Roman', size: 14 };
});
workbook.xlsx.writeFile(process.argv[1]).catch(error => { console.error(error); process.exitCode=1; });
'@
Push-Location $atlasRoot
try { & node -e $atlasNode $atlasProbe; if ($LASTEXITCODE -ne 0) { throw 'WIDTH_PROBE_CREATION_FAILED' } }
finally { Pop-Location }

$atlasExcel = $null
$atlasBook = $null
$atlasCalibrationBook = $null
$atlasBitmap = New-Object Drawing.Bitmap 1,1
$atlasBitmap.SetResolution(720,720)
$atlasGraphics = [Drawing.Graphics]::FromImage($atlasBitmap)
$atlasGraphics.PageUnit = [Drawing.GraphicsUnit]::Pixel
$atlasGraphics.TextRenderingHint = [Drawing.Text.TextRenderingHint]::AntiAlias
$atlasFormat = [Drawing.StringFormat]::GenericTypographic.Clone()
$atlasFormat.FormatFlags = $atlasFormat.FormatFlags -bor [Drawing.StringFormatFlags]::MeasureTrailingSpaces -bor [Drawing.StringFormatFlags]::NoClip
try {
  $atlasExcel = New-Object -ComObject Excel.Application
  $atlasExcel.Visible = $false
  $atlasExcel.DisplayAlerts = $false
  $atlasExcel.AutomationSecurity = 3
  $atlasCalibrationBook = $atlasExcel.Workbooks.Open($atlasCalibrationPath,0,$true)
  $atlasCalibrationNormal = $atlasCalibrationBook.Styles.Item('Normal').Font
  $atlasCalibrationNormalName = [string]$atlasCalibrationNormal.Name
  $atlasCalibrationNormalSize = [double]$atlasCalibrationNormal.Size
  $atlasBook = $atlasExcel.Workbooks.Open($atlasProbe,0,$true)
  $atlasNormal = $atlasBook.Styles.Item('Normal').Font
  $atlasNormalName = [string]$atlasNormal.Name
  $atlasNormalSize = [double]$atlasNormal.Size
  if ($atlasNormalName -cne $atlasCalibrationNormalName -or $atlasNormalSize -ne $atlasCalibrationNormalSize) { throw 'PRODUCTION_NORMAL_STYLE_MISMATCH' }
  $atlasNormalFont = New-Object Drawing.Font $atlasNormalName,$atlasNormalSize,([Drawing.FontStyle]::Regular),([Drawing.GraphicsUnit]::Point)
  try {
    $atlasDigits = @(0..9 | ForEach-Object {
      [Math]::Round($atlasGraphics.MeasureString([string]$_,$atlasNormalFont,[int]::MaxValue,$atlasFormat).Width / 720 * 96,6)
    })
  } finally { $atlasNormalFont.Dispose() }
  $atlasDigitWidth = [Math]::Round(($atlasDigits | Measure-Object -Maximum).Maximum)
  $atlasSheet = $atlasBook.Worksheets.Item(1)
  $atlasSamples = @()
  $atlasMaxWidthError = 0.0
  foreach ($atlasIndex in 0..($atlasWidths.Count-1)) {
    $atlasWidth = $atlasWidths[$atlasIndex]
    $atlasPoints = [double]$atlasSheet.Columns.Item($atlasIndex+1).Width
    $atlasPredicted = [Math]::Floor(((256*$atlasWidth + [Math]::Floor(128/$atlasDigitWidth))/256)*$atlasDigitWidth)*72/96
    $atlasMaxWidthError = [Math]::Max($atlasMaxWidthError, [Math]::Abs($atlasPoints-$atlasPredicted))
    # Excel's native column rounding may differ by one screen pixel (0.75pt).
    # Match the existing production-width QA tolerance; printed glyph clearance
    # remains an independent, unchanged 0.5pt requirement.
    if ([Math]::Abs($atlasPoints-$atlasPredicted) -gt 0.76) { throw "NATIVE_WIDTH_MISMATCH: $atlasWidth measured=$atlasPoints predicted=$atlasPredicted" }
    $atlasSamples += [ordered]@{ width=$atlasWidth; points=$atlasPoints; predictedPoints=$atlasPredicted }
  }
  $atlasCodepoints = @(32..126) + @(160..383) + @(768..879) + @(7680..7935) + @(8192..8303) + @(9633,65533)
  $atlasMetrics = [ordered]@{}
  $atlasFontFiles = [ordered]@{}
  foreach ($atlasStyle in @('regular','bold')) {
    $atlasFontStyle = if ($atlasStyle -eq 'bold') { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    $atlasFont = New-Object Drawing.Font 'Times New Roman',14,$atlasFontStyle,([Drawing.GraphicsUnit]::Point)
    if ($atlasFont.Name -cne 'Times New Roman') { throw 'TIMES_NEW_ROMAN_NOT_INSTALLED' }
    $atlasAdvances = [ordered]@{}
    try {
      foreach ($atlasCodepoint in $atlasCodepoints) {
        $atlasText = [char]::ConvertFromUtf32($atlasCodepoint)
        $atlasAdvances[[string]$atlasCodepoint] = [Math]::Round($atlasGraphics.MeasureString($atlasText,$atlasFont,[int]::MaxValue,$atlasFormat).Width / 10,6)
      }
    } finally { $atlasFont.Dispose() }
    $atlasMetrics[$atlasStyle] = $atlasAdvances
    $atlasFile = if ($atlasStyle -eq 'bold') { 'timesbd.ttf' } else { 'times.ttf' }
    $atlasInstalledFile = Join-Path $env:WINDIR ('Fonts/' + $atlasFile)
    $atlasFontFiles[$atlasStyle] = [ordered]@{ file=$atlasFile; sha256=(Get-FileHash -LiteralPath $atlasInstalledFile -Algorithm SHA256).Hash.ToLowerInvariant() }
  }
  $atlasReport = [ordered]@{
    provenance=[ordered]@{
      font='Times New Roman'; fontSizePoints=14; measurementApi='System.Drawing.Graphics.MeasureString, GenericTypographic, MeasureTrailingSpaces, NoClip, AntiAlias'; measurementDpi=720; advanceUnit='points'; generatedDate=[DateTime]::UtcNow.ToString('yyyy-MM-dd'); fontFiles=$atlasFontFiles
      excelVersion=[string]$atlasExcel.Version; excelBuild=[string]$atlasExcel.Build; normalFont=$atlasNormalName; normalFontSizePoints=$atlasNormalSize; normalDigitWidthsPixels96Dpi=$atlasDigits; maximumDigitWidthPixels=$atlasDigitWidth; columnDpi=96; columnWidthSamples=$atlasSamples
      columnCalibration='Styled ExcelJS width probe; Normal font verified against read-only production export'; calibrationWorkbookSha256=$atlasCalibrationHash; nativeWidthTolerancePoints=0.76; nativeWidthMaxErrorPoints=$atlasMaxWidthError
      widthSpecification='https://learn.microsoft.com/en-us/dotnet/api/documentformat.openxml.spreadsheet.column?view=openxml-3.0.1'
    }
    regular=$atlasMetrics.regular
    bold=$atlasMetrics.bold
  }
  if ((Get-FileHash -LiteralPath $atlasCalibrationPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne $atlasCalibrationHash) { throw 'PRODUCTION_CALIBRATION_WORKBOOK_CHANGED' }
  $atlasReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $atlasOutput -Encoding utf8
  Push-Location $atlasRoot
  try { & pnpm exec prettier --write $atlasOutput; if ($LASTEXITCODE -ne 0) { throw 'METRIC_FORMATTING_FAILED' } }
  finally { Pop-Location }
  Write-Output "Measured Times New Roman 14pt regular/bold; Normal $atlasNormalName $atlasNormalSize pt MDW=$atlasDigitWidth px; $($atlasSamples.Count) native width checks."
  Write-Output "Numeric metrics SHA256: $((Get-FileHash -LiteralPath $atlasOutput -Algorithm SHA256).Hash)"
} finally {
  if ($atlasBook) { $atlasBook.Close($false) }
  if ($atlasCalibrationBook) { $atlasCalibrationBook.Close($false) }
  if ($atlasExcel) { $atlasExcel.Quit(); [void][Runtime.InteropServices.Marshal]::FinalReleaseComObject($atlasExcel) }
  $atlasFormat.Dispose()
  $atlasGraphics.Dispose()
  $atlasBitmap.Dispose()
  if (Test-Path -LiteralPath $atlasProbe) { Remove-Item -LiteralPath $atlasProbe }
}
