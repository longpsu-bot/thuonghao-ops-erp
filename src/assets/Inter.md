# Atlas UI font

`InterVariable.woff2` is the unmodified upright variable face from
[Inter v4.1](https://github.com/rsms/inter/releases/tag/v4.1), commit
`e3a3d4c57d5ecc01453a575621882a384c1995a3`.

- Source: `docs/font-files/InterVariable.woff2`
- Git blob: `5a8d3e72ad7ffb62af3b146e1b1f54ab5813a212`
- License: [SIL Open Font License 1.1](../../public/fonts/Inter.LICENSE.txt), copied
  from that release and shipped at `fonts/Inter.LICENSE.txt` in the generated site.

The complete face retains Vietnamese glyphs and the original weight/optical-size
axes. Atlas registers it as `Atlas Inter` to avoid picking an unrelated locally
installed Inter version. The existing Chakra provider imports its CSS; Vite
bundles the font with the application. No runtime font CDN is required. Fallbacks
remain available while `font-display: swap` loads the local asset.
