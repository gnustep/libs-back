#!/usr/bin/env python3
"""Generate a fonts.conf for Android from /system/etc/fonts.xml.

Android ships the font files but not fontconfig, so nothing on the device maps
a family name to a file.  fonts.xml carries exactly the two things fontconfig
needs and cannot discover: which family is the default for a generic name
(sans-serif, serif, monospace), and the alias set that maps the names
applications actually ask for -- Helvetica, Arial, Times -- onto them.

The font files themselves are left to fontconfig's own scan of /system/fonts.
Writing them out here would freeze a list that changes with the platform.

Usage: mkfontsconf.py <fonts.xml> <output fonts.conf> [font dir] [cache dir]
"""
import sys
import xml.etree.ElementTree as ET

HEADER = """<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<!-- Generated from Android's /system/etc/fonts.xml.  Do not edit by hand. -->
<fontconfig>
  <dir>{fontdir}</dir>
  <cachedir>{cachedir}</cachedir>
"""

FOOTER = """  <config>
    <rescan><int>30</int></rescan>
  </config>
</fontconfig>
"""


def escape(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def alias_element(name, target, indent="  "):
    """A fontconfig alias: asking for `name` prefers `target`."""
    return (
        '{i}<alias binding="same">\n'
        '{i}  <family>{n}</family>\n'
        '{i}  <prefer><family>{t}</family></prefer>\n'
        '{i}</alias>\n'.format(i=indent, n=escape(name), t=escape(target))
    )


# fontconfig's weight and slant scales are not OpenType's, and a scan match can
# only name a const.  These are the values fontconfig's scanner assigns, so a
# match keyed on them selects exactly one named instance of a variable font.
FC_WEIGHT = {
    "100": "thin", "200": "extralight", "300": "light", "400": "regular",
    "500": "medium", "600": "demibold", "700": "bold", "800": "extrabold",
    "900": "black",
}
FC_SLANT = {"normal": "roman", "italic": "italic"}

# FC_WIDTH_NORMAL.  It is written as an integer rather than <const>normal</const>
# because fontconfig's constant table is keyed by NAME alone: "normal" is also
# the name of a weight, resolves to FC_WEIGHT_NORMAL (80), and a width test
# against it matches nothing at all.  Measured on fontconfig 2.15: the const
# form silently never fires, the integer form does.
FC_WIDTH_NORMAL = 100


def face_match(psname, families, filename, weight, style, width, indent="  "):
    """Name one FACE: its PostScript name, and the families it belongs to.

    The match cannot be keyed on the file alone.  Android's sans-serif keeps
    weight 400 in RobotoStatic-Regular.ttf and every other weight and slant in
    named instances of the ONE variable file Roboto-Regular.ttf, and a scan
    match that tests only the file fires for all 37 of them -- so every
    instance is given the same PostScript name, of which FCFontEnumerator keeps
    the first it meets, and the face called Helvetica-Bold ends up being the
    regular weight.  weight, slant and width are what tell the instances apart;
    width has to be tested too, or the Condensed instances are named as well.

    FCFontEnumerator names a FACE from FC_POSTSCRIPT_NAME (FCFontEnumerator.m:320)
    and takes its FAMILY from element 0 of FC_FAMILY (FCFontEnumerator.m:371),
    which is what a prepend supplies.  -availableFonts is built from the face
    names and NSFont looks its defaults up there by name, so the name has to
    reach the right face; the family has to be the AppKit family, or asking
    fontconfig for that family's bold face finds nothing and falls back to the
    regular one.
    """
    out = ['{i}<match target="scan">\n'
           '{i}  <test name="file" compare="eq"><string>{f}</string></test>\n'
           '{i}  <test name="weight" compare="eq"><const>{w}</const></test>\n'
           '{i}  <test name="slant" compare="eq"><const>{s}</const></test>\n'
           '{i}  <test name="width" compare="eq"><int>{d}</int></test>\n'
           .format(i=indent, f=escape(filename), d=width,
                   w=FC_WEIGHT[weight], s=FC_SLANT[style])]
    if psname is not None:
        out.append('{i}  <edit name="postscriptname" mode="assign">'
                   '<string>{n}</string></edit>\n'
                   .format(i=indent, n=escape(psname)))
    for fam in families:
        out.append('{i}  <edit name="family" mode="prepend">'
                   '<string>{n}</string></edit>\n'
                   .format(i=indent, n=escape(fam)))
    out.append('{i}</match>\n'.format(i=indent))
    return "".join(out)


def face_width(font):
    """The fontconfig width of a fonts.xml <font>, from its wdth axis.

    A named instance of a variable font carries the axis value as its width;
    everything else is normal.  Testing the wrong width means the match never
    fires and the face silently keeps its own name.
    """
    for a in font.findall("axis"):
        if a.get("tag") == "wdth":
            try:
                return int(float(a.get("stylevalue")))
            except (TypeError, ValueError):
                return FC_WIDTH_NORMAL
    return FC_WIDTH_NORMAL


# The PostScript names AppKit asks for by default, and the Android family and
# face each should resolve to.  GNUstep's font roles default to Helvetica,
# Helvetica-Bold and Courier (libs-gui Source/NSFont.m), and NSFont looks a
# family up BY NAME in the enumerator's list -- an alias is not enough, because
# no font file on the device carries any of these names.
#
# The AppKit family is carried as well as the PostScript name: the three roles
# of a family have to sit in ONE family, or -defaultBoldSystemFontName, which
# asks fontconfig for the bold face of the system font's family, finds only the
# regular face and answers the system name back.
#
# (postscript name, AppKit family, android family, weight, style)
APPKIT_NAMES = [
    ("Helvetica",          "Helvetica", "sans-serif", "400", "normal"),
    ("Helvetica-Bold",     "Helvetica", "sans-serif", "700", "normal"),
    ("Helvetica-Oblique",  "Helvetica", "sans-serif", "400", "italic"),
    ("Times-Roman",        "Times",     "serif",      "400", "normal"),
    ("Times-Bold",         "Times",     "serif",      "700", "normal"),
    ("Times-Italic",       "Times",     "serif",      "400", "italic"),
    ("Courier",            "Courier",   "monospace",  "400", "normal"),
    ("Courier-Bold",       "Courier",   "monospace",  "700", "normal"),
]


def faces_of(family, fontdir):
    """Every face fonts.xml declares for a family, as (path, weight, style,
    width) in declaration order.  Faces whose weight or style this script
    cannot express as a fontconfig constant are dropped and reported, never
    written out with a guessed value."""
    out = []
    skipped = []
    for f in family.findall("font"):
        name = (f.text or "").strip()
        if not name:
            continue
        fw = f.get("weight")
        fs = f.get("style", "normal")
        if fw not in FC_WEIGHT or fs not in FC_SLANT:
            skipped.append("%s %s/%s" % (name, fw, fs))
            continue
        out.append(("%s/%s" % (fontdir, name), fw, fs, face_width(f)))
    return out, skipped


def font_for(faces, weight, style):
    """The face for a (weight, style), falling back to the regular one.

    Returns (face, exact).  The face returned is the one that actually exists,
    which is what a scan match has to test: asking for the 700 face of a family
    that has none and then testing for weight 700 would match nothing at all.
    """
    fallback = None
    for face in faces:
        _, fw, fs, fd = face
        if fw == weight and fs == style and fd == FC_WIDTH_NORMAL:
            return face, True
        if fw == "400" and fs == "normal" and fd == FC_WIDTH_NORMAL \
                and fallback is None:
            fallback = face
    return fallback, False


def main():
    if len(sys.argv) < 3:
        sys.stderr.write(__doc__)
        return 2
    src, dst = sys.argv[1], sys.argv[2]
    fontdir = sys.argv[3] if len(sys.argv) > 3 else "/system/fonts"
    cachedir = sys.argv[4] if len(sys.argv) > 4 else "/data/local/tests/fontconfig/cache"

    root = ET.parse(src).getroot()

    named = [f for f in root.findall("family") if f.get("name")]
    if not named:
        sys.stderr.write("%s declares no named family; refusing to write a "
                         "configuration that would match nothing\n" % src)
        return 1

    aliases = []
    for a in root.findall("alias"):
        name, to = a.get("name"), a.get("to")
        if name and to:
            aliases.append((name, to))

    default = named[0].get("name")

    out = [HEADER.format(fontdir=escape(fontdir), cachedir=escape(cachedir))]

    # Everything is written per FACE -- (file, weight, style, width) -- not per
    # file.  Android's sans-serif keeps weight 400 in RobotoStatic-Regular.ttf
    # and every other weight and slant in named instances of the ONE variable
    # file Roboto-Regular.ttf, so a rule keyed on the file alone applies to all
    # 37 of them at once.
    faces = {}            # (path, weight, style, width) -> {ps, families}
    order = []
    inexact = []
    unnamed = []
    dropped = []

    def face_entry(key):
        if key not in faces:
            faces[key] = {"ps": None, "families": []}
            order.append(key)
        return faces[key]

    # A family name has to reach EVERY face fonts.xml declares for it, not just
    # the regular one.  fontconfig scores the family before the weight, so a
    # family carried by the regular face alone answers that face for a bold
    # request -- which is how -defaultBoldSystemFontName came back with the
    # system font's own name.
    out.append("  <!-- the families fonts.xml names, over all their faces -->\n")
    byfaces = {}
    bound = 0
    for fam in named:
        fl, skipped = faces_of(fam, fontdir)
        byfaces[fam.get("name")] = fl
        dropped.extend(skipped)
        for face in fl:
            e = face_entry(face)
            if fam.get("name") not in e["families"]:
                e["families"].append(fam.get("name"))
        if fl:
            bound += 1

    # The names AppKit asks for by default, bound onto real faces.  These are
    # appended last so that the AppKit family, not the Android one, ends up as
    # element 0 of the family list: prepends are emitted in order and the last
    # one wins, and FCFontEnumerator takes the family from element 0.
    appkit = 0
    for ps, appfam, fam, weight, style in APPKIT_NAMES:
        fl = byfaces.get(fam)
        if not fl:
            continue
        face, exact = font_for(fl, weight, style)
        if face is None:
            continue
        e = face_entry(face)
        appkit += 1

        # A face has exactly ONE PostScript name, so the first claimant keeps
        # it.  Letting a later one overwrite would silently take the name away
        # from the earlier, more important role.
        if e["ps"] is None:
            e["ps"] = ps
        else:
            unnamed.append("%s (%s %s/%s already carries the name %s)"
                           % (ps, face[0].rsplit("/", 1)[-1], face[1], face[2],
                              e["ps"]))

        # The family list is multi-valued, so every name can be prepended.
        if appfam not in e["families"]:
            e["families"].append(appfam)

        if not exact:
            inexact.append("%s (no %s/%s face in %s)" % (ps, weight, style, fam))

    for key in order:
        path, fw, fs, fd = key
        e = faces[key]
        out.append(face_match(e["ps"], e["families"], path, fw, fs, fd))

    out.append("  <!-- %d aliases from fonts.xml -->\n" % len(aliases))
    for name, to in aliases:
        out.append(alias_element(name, to))

    generics = ("sans-serif", "sans", "serif", "monospace", "system-ui")
    names = [f.get("name") for f in named]
    missing = [g for g in generics if g not in names]
    out.append("  <!-- generic families not named in fonts.xml, defaulting to "
               "%s -->\n" % default)
    for g in missing:
        out.append(alias_element(g, default))

    out.append(FOOTER)

    with open(dst, "w") as fh:
        fh.write("".join(out))

    sys.stderr.write("%s: %d named families (%d with faces, %d faces in all), "
                     "%d AppKit names, %d aliases, %d generic fallbacks -> %s\n"
                     % (src, len(named), bound, len(order), appkit,
                        len(aliases), len(missing), dst))
    # Substitutions are reported rather than hidden: a name bound to the
    # regular face when a bold one was asked for will render at the wrong
    # weight, and that is a real limitation of the device's font set.
    for line in inexact:
        sys.stderr.write("  substituted the regular face for %s\n" % line)
    for line in unnamed:
        sys.stderr.write("  no PostScript name for %s\n" % line)
    for line in dropped:
        sys.stderr.write("  no fontconfig constant for %s; face left alone\n"
                         % line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
