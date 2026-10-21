# Atlas document arrow font

`atlas-document-arrows.ttf` contains only U+2190–U+21FF (112 arrows), subset from
[Noto Sans Math](https://github.com/google/fonts/tree/dbd1ab6e65dc59bcda3ca8de9fd372f58f98e0af/ofl/notosansmath).
It preserves arrow characters in PDF notes where the bundled Roboto has no glyph.
Normal document text and accepted body sizes still use Roboto. No runtime package
or network font request is added.

- Upstream font SHA-256: `3f495fe933c06786e4d5f6d86b8ee70b6753a68ee3b9d87528726de0f6e2c47d`.
- Subset SHA-256: `885b91ab4fd1f1799d06078a9a1cf2425a9b5fd5e8a05aaf4c6d43a2d9e9ed52`.
- FontTools 4.67.0; retain original timestamps, remove unused MATH layout table,
  subset U+2190–U+21FF, rename family/full/PostScript names to AtlasDocumentArrows.
- SIL Open Font License 1.1 and original copyright are retained in
  [atlas-document-arrows.OFL.txt](atlas-document-arrows.OFL.txt).

The actual PDF regression checks that U+2192 is embedded in its Unicode mapping;
native PDF and Excel review remain the layout checks.
