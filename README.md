# Comix

A native iPhone and iPad app for turning a sequence of images into a comic. iOS 17 or later. No accounts, servers, or package dependencies.

Comix uses a comic-print theme: heavy condensed lettering, hard inked panels, halftone texture, and saturated yellow, red, and cyan. The included **First Contact** issue is original sample artwork. The app intentionally keeps the original bundle identifier, `com.utkarsh.bindery`, and unchanged draft storage so an update retains existing drafts.

The Comix simulator build succeeded. Six unit tests and the final UI flow test passed across two runs, and the UI-exported **First Contact** EPUB passed EPUBCheck with no errors or warnings. The simulator library visibly retained a previously saved draft after the rebrand. Light mode, dark mode, and largest Dynamic Type were inspected. See [verification notes](Documentation/VALIDATION.md) for the exact test scope and remaining device/reader checks. Current sample exports are in `Documentation/Samples`.

## Use it

The current signed Release build is installed and launched on the connected iPhone 15 Pro Max. Real-library imports and Apple Books reading are ready for hands-on testing.

1. Create a comic and choose images from Photos or Files. Each image becomes one page. Photos preserves the order you select; Files uses natural filename order (page 2 before page 10).
2. Use **Arrange** to change page order. The first page becomes the cover. Tap a page to make it the cover, remove it, or add an image description.
3. Open **Details** to enter a title, creator, series, issue number, description, language, and reading direction.
4. Preview with page swipes, pinch zoom, and double-tap zoom.
5. Export PDF or fixed-layout EPUB, then use the share sheet to open in Books or save to Files.

Drafts save automatically. Imported pages are copied into the app; subsequent edits or removal of the original photo do not affect a draft. PNG and upright JPEG files retain their original bytes on import. Other images, including HEIC and rotated JPEG, are normalized to correctly oriented JPEG (PNG for PNG sources). For multi-frame image formats, the first frame becomes the page.

## Export behavior

- **PDF:** one image per page, with its own aspect ratio and no crop. Includes title, author, description, and series keywords. Compact and Balanced resize images; Original retains imported resolution.
- **EPUB:** EPUB 3, fixed layout, one image per XHTML page, cover image, table of contents, page list, and book metadata. Reading direction is written into the spine. A canvas matching the cover holds every page without cropping; different aspect ratios can have white borders. Series and numeric issue metadata are included, although display varies by reader.
- **Quality:** Compact caps the longest edge at 1,600 px; Balanced at 2,560 px. Both use JPEG for export. Original EPUB preserves imported image files when they fit Apple Books' documented 5.6-million-pixel limit; larger pages are proportionally resized. Original drafts are retained.
- EPUB is written as a streaming ZIP with already-compressed image assets. The mimetype entry is first, uncompressed, and has no ZIP extra fields. ZIP32 exports larger than 4 GB are rejected with a useful message.
- Each export is a separate revision under **Files → On My iPhone/iPad → Comix → Exports**. Draft manifests and their images are under **Drafts**. Old export revisions can be removed in Files.
- Comic lettering stays in the images. The app does not OCR, edit panels, or claim searchable or reflowable image text. Optional page descriptions become EPUB alternative text.

PDF is the broadest compatibility choice. Fixed-layout EPUB requires a reader that supports that feature. Apple Books import on a physical device should be verified before a release.

## Build

Open `Comix.xcodeproj`, select the Comix scheme, and run on an iPhone or iPad simulator. For a physical device, choose your Apple development team in Signing & Capabilities. The checked-in team reflects this workspace's other apps.

The project is generated from `project.yml` with XcodeGen:

```sh
xcodegen generate
xcodebuild -project Comix.xcodeproj -scheme Comix \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

The icon is reproducible with `swift Documentation/generate-icon.swift Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png`.

## Implementation

`Core` holds the Codable draft model, atomic local persistence, ImageIO import/normalization, Core Graphics PDF generation, and EPUB packaging. `Features` holds the SwiftUI library, editor, metadata form, zoomable reader, and export/share screens. Image import and export run off the main actor; thumbnail decoding is asynchronous and bounded. The system Photos picker grants access only to selected photos.

Export tests inspect ZIP entry order and checksums, parse all generated XML, check fixed-layout metadata and page order, inspect PDF page sizes and metadata, verify orientation normalization and lossless PNG import, confirm Apple image limits, and reload saved drafts after reorder/deletion. UI tests exercise sample preview, both exports, and PDF preview.

## Format references

- [W3C EPUB 3.3](https://www.w3.org/TR/epub-33/)
- [Apple Books Asset Guide: fixed layouts and image requirements](https://help.apple.com/itc/booksassetguide/en.lproj/static.html)
- [EPUBCheck](https://github.com/w3c/epubcheck)


## Public snapshot

See [PUBLICATION.md](PUBLICATION.md) for publication exclusions and setup requirements.
