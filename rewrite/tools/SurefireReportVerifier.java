import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.regex.Pattern;
import javax.xml.XMLConstants;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;

public final class SurefireReportVerifier {
    private static final Pattern NON_NEGATIVE_INTEGER = Pattern.compile("[0-9]+");

    private SurefireReportVerifier() {
    }

    public static void main(String[] args) throws Exception {
        if (args.length < 2) {
            throw new IllegalArgumentException("Usage: SurefireReportVerifier <report-dir> <test-class>...");
        }

        Path reportDirectory = Path.of(args[0]);
        for (int index = 1; index < args.length; index++) {
            verifyReport(reportDirectory, args[index]);
        }
    }

    private static void verifyReport(Path reportDirectory, String expectedClassName) throws Exception {
        Path report = reportDirectory.resolve("TEST-" + expectedClassName + ".xml");
        if (!Files.isRegularFile(report)) {
            throw new IllegalStateException("Missing Surefire report: " + report);
        }

        DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_DTD, "");
        factory.setAttribute(XMLConstants.ACCESS_EXTERNAL_SCHEMA, "");
        factory.setExpandEntityReferences(false);
        factory.setXIncludeAware(false);

        Document document;
        try (InputStream input = Files.newInputStream(report)) {
            document = factory.newDocumentBuilder().parse(input);
        }

        Element suite = document.getDocumentElement();
        if (!"testsuite".equals(suite.getTagName())) {
            throw new IllegalStateException("Unexpected Surefire report root in " + report);
        }
        if (!expectedClassName.equals(suite.getAttribute("name"))) {
            throw new IllegalStateException(
                    "Surefire suite name mismatch in " + report + ": " + suite.getAttribute("name"));
        }

        int tests = integerAttribute(suite, "tests", report);
        int failures = integerAttribute(suite, "failures", report);
        int errors = integerAttribute(suite, "errors", report);
        int skipped = integerAttribute(suite, "skipped", report);
        if (tests == 0) {
            throw new IllegalStateException("No tests executed for " + expectedClassName);
        }
        if (failures != 0 || errors != 0 || skipped != 0) {
            throw new IllegalStateException(
                    "Surefire report is not clean for " + expectedClassName
                            + ": failures=" + failures + ", errors=" + errors + ", skipped=" + skipped);
        }
    }

    private static int integerAttribute(Element suite, String name, Path report) {
        String value = suite.getAttribute(name);
        if (!NON_NEGATIVE_INTEGER.matcher(value).matches()) {
            throw new IllegalStateException("Invalid " + name + " count in " + report + ": " + value);
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException exception) {
            throw new IllegalStateException("Out-of-range " + name + " count in " + report, exception);
        }
    }
}
