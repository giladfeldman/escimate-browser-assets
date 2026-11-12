# FindJPEG under emcmake leaves JPEG::JPEG without a location; link the static lib directly.
p = "/src/poppler-25.03.0/CMakeLists.txt"
s = open(p).read()
old = "set(poppler_LIBS ${poppler_LIBS} JPEG::JPEG)"
new = "set(poppler_LIBS ${poppler_LIBS} /src/prefix/lib/libjpeg.a)\n  include_directories(SYSTEM /src/prefix/include)"
if old in s:
    open(p, "w").write(s.replace(old, new))
