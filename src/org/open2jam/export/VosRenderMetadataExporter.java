package org.open2jam.export;

import java.io.File;
import java.io.InputStream;
import java.net.URL;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import javax.xml.parsers.DocumentBuilderFactory;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;

public final class VosRenderMetadataExporter {
    private static final String RESOURCES_XML = "/resources/resources.xml";
    private static final String DEFAULT_SKIN = "o2jam";
    private static final double DEFAULT_BASE_WIDTH = 800.0;
    private static final double DEFAULT_BASE_HEIGHT = 600.0;
    private static final double JAVA_MEASURE_SIZE = 385.0;

    public String exportDefaultMetadata() throws Exception {
        Document document = readResourcesDocument();
        Map<String, SpriteMetadata> sprites = readSprites(document);
        Element skin = findSkin(document, DEFAULT_SKIN);

        double baseWidth = doubleAttribute(skin, "width", DEFAULT_BASE_WIDTH);
        double baseHeight = doubleAttribute(skin, "height", DEFAULT_BASE_HEIGHT);
        int judgmentLine = intAttribute(skin, "judgment_line", 0);

        List<String> entities = new ArrayList<String>();
        List<String> lanes = new ArrayList<String>();
        int layer = -1;
        for (Element layerElement : childElements(skin, "layer")) {
            layer++;
            for (Element entityElement : childElements(layerElement, "entity")) {
                addEntityMetadata(entityElement, layer, sprites, entities, lanes);
            }
        }

        return JsonWriter.object(
                JsonWriter.field("schemaVersion", 1),
                JsonWriter.field("format", "VOS_RENDER_METADATA"),
                JsonWriter.field("skin", DEFAULT_SKIN),
                JsonWriter.field("baseWidth", baseWidth),
                JsonWriter.field("baseHeight", baseHeight),
                JsonWriter.field("judgmentLine", judgmentLine),
                JsonWriter.field("measureSize", JAVA_MEASURE_SIZE),
                JsonWriter.rawField("entities", JsonWriter.array(entities.toArray(new String[0]))),
                JsonWriter.rawField("lanes", JsonWriter.array(lanes.toArray(new String[0]))));
    }

    private static Document readResourcesDocument() throws Exception {
        InputStream input = VosRenderMetadataExporter.class.getResourceAsStream(RESOURCES_XML);
        if (input == null) {
            throw new IllegalArgumentException("Missing resource: " + RESOURCES_XML);
        }
        try (InputStream in = input) {
            DocumentBuilderFactory factory = DocumentBuilderFactory.newInstance();
            factory.setNamespaceAware(true);
            return factory.newDocumentBuilder().parse(in);
        }
    }

    private static Map<String, SpriteMetadata> readSprites(Document document) {
        Map<String, SpriteMetadata> sprites = new HashMap<String, SpriteMetadata>();
        NodeList nodes = document.getElementsByTagNameNS("*", "sprite");
        for (int i = 0; i < nodes.getLength(); i++) {
            Element sprite = (Element) nodes.item(i);
            String id = sprite.getAttribute("id");
            if (id == null || id.trim().isEmpty()) {
                continue;
            }
            Element frame = firstChild(sprite, "frame");
            if (frame == null) {
                continue;
            }

            double scaleX = doubleAttribute(frame, "scale_x", doubleAttribute(frame, "scale", 1.0));
            double scaleY = doubleAttribute(frame, "scale_y", doubleAttribute(frame, "scale", 1.0));
            double textureX = doubleAttribute(frame, "x", 0.0);
            double textureY = doubleAttribute(frame, "y", 0.0);
            double textureWidth = doubleAttribute(frame, "w", 0.0);
            double textureHeight = doubleAttribute(frame, "h", 0.0);
            double width = textureWidth * scaleX;
            double height = textureHeight * scaleY;
            double frameSpeed = doubleAttribute(sprite, "framespeed", 0.0) / 1000.0;
            int frameCount = childElements(sprite, "frame").size();
            String texturePath = texturePathFor(frame.getAttribute("file"));
            sprites.put(id, new SpriteMetadata(id, width, height, frameCount, frameSpeed, texturePath,
                    textureX, textureY, textureWidth, textureHeight));
        }
        return sprites;
    }

    private static Element findSkin(Document document, String skinName) {
        NodeList nodes = document.getElementsByTagNameNS("*", "skin");
        for (int i = 0; i < nodes.getLength(); i++) {
            Element skin = (Element) nodes.item(i);
            if (skinName.equals(skin.getAttribute("name"))) {
                return skin;
            }
        }
        throw new IllegalArgumentException("Missing skin: " + skinName);
    }

    private static void addEntityMetadata(Element entity, int layer, Map<String, SpriteMetadata> sprites,
            List<String> entities, List<String> lanes) {
        String id = emptyToNull(entity.getAttribute("id"));
        String[] spriteRefs = spriteRefs(entity.getAttribute("sprite"));
        SpriteMetadata sprite = spriteRefs.length == 0 ? SpriteMetadata.empty() : sprites.get(spriteRefs[0]);
        if (sprite == null) {
            sprite = SpriteMetadata.empty();
        }

        double x = doubleAttribute(entity, "x", 0.0);
        double y = doubleAttribute(entity, "y", 0.0);
        if (id != null && id.startsWith("NOTE_")) {
            entities.add(entityJson("LONG_" + id, "longNote", layer, x, y, sprite.width, sprite.height, spriteRefs,
                    entity, true, id, sprite));
            entities.add(entityJson(id, "note", layer, x, y, sprite.width, sprite.height, spriteRefs, entity, true,
                    id, sprite));
            lanes.add(laneJson(id, laneForNoteId(id), x, sprite.width));
            return;
        }

        entities.add(entityJson(id == null ? "" : id, typeFor(id), layer, x, y, sprite.width, sprite.height,
                spriteRefs, entity, id != null, id, sprite));
    }

    private static String entityJson(String id, String type, int layer, double x, double y, double width, double height,
            String[] spriteRefs, Element source, boolean named, String channel, SpriteMetadata sprite) {
        List<String> fields = new ArrayList<String>();
        fields.add(JsonWriter.field("id", id));
        fields.add(JsonWriter.field("type", type));
        fields.add(JsonWriter.field("layer", layer));
        fields.add(JsonWriter.field("x", x));
        fields.add(JsonWriter.field("y", y));
        fields.add(JsonWriter.field("width", width));
        fields.add(JsonWriter.field("height", height));
        fields.add(JsonWriter.field("named", named));
        if (channel != null && channel.startsWith("NOTE_")) {
            fields.add(JsonWriter.field("channel", channel));
        }
        if (!sprite.texturePath.isEmpty()) {
            fields.add(JsonWriter.field("texturePath", sprite.texturePath));
            fields.add(JsonWriter.field("textureX", sprite.textureX));
            fields.add(JsonWriter.field("textureY", sprite.textureY));
            fields.add(JsonWriter.field("textureWidth", sprite.textureWidth));
            fields.add(JsonWriter.field("textureHeight", sprite.textureHeight));
        }
        String fillDirection = source.getAttribute("fill_direction");
        if (fillDirection != null && !fillDirection.trim().isEmpty()) {
            fields.add(JsonWriter.field("fillDirection", fillDirection));
        }
        fields.add(JsonWriter.rawField("sprites", JsonWriter.array(quoted(spriteRefs))));
        return JsonWriter.object(fields.toArray(new String[0]));
    }

    private static String laneJson(String channel, int lane, double x, double width) {
        return JsonWriter.object(
                JsonWriter.field("channel", channel),
                JsonWriter.field("lane", lane),
                JsonWriter.field("x", x),
                JsonWriter.field("width", width));
    }

    private static String typeFor(String id) {
        if (id == null) {
            return "entity";
        }
        if ("BGA".equals(id)) {
            return "bga";
        }
        if ("MEASURE_MARK".equals(id)) {
            return "measure";
        }
        if ("LIFE_BAR".equals(id) || "JAM_BAR".equals(id) || "TIME_BAR".equals(id)) {
            return "bar";
        }
        if ("COMBO_COUNTER".equals(id) || "JAM_COUNTER".equals(id)) {
            return "comboCounter";
        }
        if (id.endsWith("_COUNTER") || id.startsWith("COUNTER_JUDGMENT_")) {
            return "numberCounter";
        }
        if (id.startsWith("EFFECT_JUDGMENT_")) {
            return "judgmentEffect";
        }
        if (id.startsWith("PRESSED_NOTE_")) {
            return "pressedNote";
        }
        if (id.startsWith("PILL_")) {
            return "pill";
        }
        return "entity";
    }

    private static int laneForNoteId(String id) {
        return Integer.parseInt(id.substring("NOTE_".length())) - 1;
    }

    private static String[] spriteRefs(String spriteAttribute) {
        if (spriteAttribute == null || spriteAttribute.trim().isEmpty()) {
            return new String[0];
        }
        String[] raw = spriteAttribute.split(",");
        List<String> refs = new ArrayList<String>();
        for (String ref : raw) {
            String trimmed = ref.trim();
            if (!trimmed.isEmpty()) {
                refs.add(trimmed);
            }
        }
        return refs.toArray(new String[0]);
    }

    private static String[] quoted(String[] values) {
        String[] quoted = new String[values.length];
        for (int i = 0; i < values.length; i++) {
            quoted[i] = JsonWriter.string(values[i]);
        }
        return quoted;
    }

    private static List<Element> childElements(Element parent, String localName) {
        List<Element> result = new ArrayList<Element>();
        NodeList children = parent.getChildNodes();
        for (int i = 0; i < children.getLength(); i++) {
            Node child = children.item(i);
            if (child instanceof Element && localName.equals(child.getLocalName())) {
                result.add((Element) child);
            }
        }
        return result;
    }

    private static Element firstChild(Element parent, String localName) {
        for (Element child : childElements(parent, localName)) {
            return child;
        }
        return null;
    }

    private static double doubleAttribute(Element element, String name, double fallback) {
        String value = element.getAttribute(name);
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return Double.parseDouble(value.trim());
    }

    private static int intAttribute(Element element, String name, int fallback) {
        String value = element.getAttribute(name);
        if (value == null || value.trim().isEmpty()) {
            return fallback;
        }
        return Integer.parseInt(value.trim());
    }

    private static String emptyToNull(String value) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        return value.trim();
    }

    private static String texturePathFor(String fileName) {
        String trimmed = fileName == null ? "" : fileName.trim();
        if (trimmed.isEmpty()) {
            return "";
        }

        File sourceFile = sourceResourceFile(trimmed);
        if (sourceFile != null) {
            return sourceFile.getAbsolutePath();
        }

        URL resource = VosRenderMetadataExporter.class.getResource("/resources/" + trimmed);
        if (resource != null && "file".equals(resource.getProtocol())) {
            try {
                return new File(resource.toURI()).getAbsolutePath();
            } catch (Exception ignored) {
                return new File(resource.getPath()).getAbsolutePath();
            }
        }
        return "/resources/" + trimmed;
    }

    private static File sourceResourceFile(String fileName) {
        File fromWorkingDirectory = new File("src/resources", fileName);
        if (fromWorkingDirectory.isFile()) {
            return fromWorkingDirectory.getAbsoluteFile();
        }

        URL location = VosRenderMetadataExporter.class.getProtectionDomain().getCodeSource().getLocation();
        if (location == null || !"file".equals(location.getProtocol())) {
            return null;
        }
        try {
            File codeLocation = new File(location.toURI());
            File base = codeLocation.isDirectory() ? codeLocation : codeLocation.getParentFile();
            for (int i = 0; i < 3 && base != null; i++) {
                File candidate = new File(base, "src/resources/" + fileName);
                if (candidate.isFile()) {
                    return candidate.getAbsoluteFile();
                }
                base = base.getParentFile();
            }
        } catch (Exception ignored) {
            return null;
        }
        return null;
    }

    private static final class SpriteMetadata {
        final String id;
        final double width;
        final double height;
        final int frameCount;
        final double frameSpeed;
        final String texturePath;
        final double textureX;
        final double textureY;
        final double textureWidth;
        final double textureHeight;

        SpriteMetadata(String id, double width, double height, int frameCount, double frameSpeed,
                String texturePath, double textureX, double textureY, double textureWidth, double textureHeight) {
            this.id = id;
            this.width = width;
            this.height = height;
            this.frameCount = frameCount;
            this.frameSpeed = frameSpeed;
            this.texturePath = texturePath;
            this.textureX = textureX;
            this.textureY = textureY;
            this.textureWidth = textureWidth;
            this.textureHeight = textureHeight;
        }

        static SpriteMetadata empty() {
            return new SpriteMetadata("", 0.0, 0.0, 0, 0.0, "", 0.0, 0.0, 0.0, 0.0);
        }
    }
}
