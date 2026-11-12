# escimate-browser-assets

Built files that let [ESCImate](https://escimate.app) check a paper entirely inside the
visitor's browser, without uploading it. They are served to browsers through
[jsDelivr](https://www.jsdelivr.com/) and always loaded by **commit**, never by branch or
tag; the page checks each file's SHA-256 before using it and stops if it differs.

| Folder | What it is | Licence |
|---|---|---|
| `poppler/` | `pdftotext` and `pdftoppm` from Poppler 25.03.0 with Debian's patches (package version `25.03.0-5+deb13u4`), compiled to WebAssembly with Emscripten 4.0.9 by `poppler/build.sh` (plus `poppler/patch_jpeg.py`, a one-line build fix to Poppler's CMakeLists.txt). Statically linked: FreeType 2.13.3, zlib 1.3.1, libjpeg-turbo 2.1.5, Little CMS 2.16, OpenJPEG 2.5.3. | GPL-2 or GPL-3 (Poppler); see `LICENSES/` for each library |
| `effectcheck/` | The [effectcheck](https://cran.r-project.org/package=effectcheck) R package built for [webR](https://docs.r-wasm.org/webr/) (R in WebAssembly). The R source is inside the archive. | MIT |
| `sources/` | The complete source archives the Poppler build was compiled from, exactly as downloaded from Debian and the upstream projects. The Debian archives match the SHA-256 in Debian's `poppler_25.03.0-5+deb13u4.dsc`. | as above |
| `LICENSES/` | Licence texts of Poppler (including Debian's `copyright` file), each statically linked library, and effectcheck. | |

`manifest.json` names each built file's version and SHA-256; `SHA256SUMS` lists every
file in the repository.

## Rebuilding Poppler

```sh
mkdir work && cp poppler/build.sh poppler/patch_jpeg.py work/
docker run --rm -v "$PWD/work:/src" emscripten/emsdk:4.0.9 bash /src/build.sh
# output: work/out2/{pdftotext,pdftoppm}.{js,wasm}
```

`build.sh` downloads the same archives that are in `sources/`.
