package javax.lang.model;

import java.util.Collections;
import java.util.HashSet;
import java.util.Set;

/**
 * Android compatibility shim for javax.lang.model.SourceVersion,
 * which is omitted from Android ART runtime but required by GraphHopper EncodedValues.
 */
public enum SourceVersion {
    RELEASE_0,
    RELEASE_1,
    RELEASE_2,
    RELEASE_3,
    RELEASE_4,
    RELEASE_5,
    RELEASE_6,
    RELEASE_7,
    RELEASE_8,
    RELEASE_9,
    RELEASE_10,
    RELEASE_11,
    RELEASE_12,
    RELEASE_13,
    RELEASE_14,
    RELEASE_15,
    RELEASE_16,
    RELEASE_17,
    RELEASE_18,
    RELEASE_19,
    RELEASE_20,
    RELEASE_21;

    private static final Set<String> KEYWORDS;

    static {
        Set<String> s = new HashSet<>();
        String[] kws = {
            "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char", "class", "const",
            "continue", "default", "do", "double", "else", "enum", "extends", "final", "finally", "float",
            "for", "goto", "if", "implements", "import", "instanceof", "int", "interface", "long", "native",
            "new", "package", "private", "protected", "public", "return", "short", "static", "strictfp",
            "super", "switch", "synchronized", "this", "throw", "throws", "transient", "try", "void",
            "volatile", "while", "true", "false", "null", "_"
        };
        Collections.addAll(s, kws);
        KEYWORDS = Collections.unmodifiableSet(s);
    }

    public static boolean isKeyword(CharSequence s) {
        return KEYWORDS.contains(s.toString());
    }

    public static boolean isIdentifier(CharSequence name) {
        String id = name.toString();
        if (id.isEmpty()) return false;
        int cp = id.codePointAt(0);
        if (!Character.isJavaIdentifierStart(cp)) return false;
        for (int i = Character.charCount(cp); i < id.length(); i += Character.charCount(cp)) {
            cp = id.codePointAt(i);
            if (!Character.isJavaIdentifierPart(cp)) return false;
        }
        return true;
    }

    public static boolean isName(CharSequence name) {
        String id = name.toString();
        for (String part : id.split("\\.", -1)) {
            if (!isIdentifier(part) || isKeyword(part)) return false;
        }
        return true;
    }

    public static SourceVersion latest() {
        return RELEASE_17;
    }

    public static SourceVersion latestSupported() {
        return RELEASE_17;
    }
}
