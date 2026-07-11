package org.open2jam.export;

import java.awt.Color;
import java.awt.Font;
import java.awt.FontMetrics;
import java.awt.Graphics2D;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.InputStream;
import java.net.URL;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
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
    private static final double COMBO_SHOW_TIME_MS = 4000.0;
    private static final double COMBO_WOBBLE_PIXELS = 10.0;
    private static final double COMBO_WOBBLE_SPEED = 0.5;
    private static final double JUDGMENT_SHOW_TIME_MS = 3000.0;
    private static final double JUDGMENT_SCALE_RAMP_MS = 100.0;
    private static final double JUDGMENT_INITIAL_SCALE = 0.5;
    private static final double STATUS_TEXT_RIGHT_X = 780.0;
    private static final double STATUS_TEXT_START_Y = 300.0;
    private static final double STATUS_TEXT_LINE_HEIGHT = 30.0;
    private static final double STATUS_TEXT_LABEL_WIDTH = 260.0;
    private static final int STATUS_TEXT_FONT_SIZE = 14;
    private static final double STATUS_TEXT_GLYPH_HEIGHT = 20.0;
    private static final double STATUS_TEXT_SCALE_X = 1.0;
    private static final double STATUS_TEXT_SCALE_Y = -1.0;
    private static final int STATUS_FONT_TEXTURE_WIDTH = 512;
    private static final int STATUS_FONT_TEXTURE_HEIGHT = 512;
    private static final int STATUS_FONT_CORRECT_LEFT = 9;
    private static final int STATUS_FONT_CORRECT_RIGHT = 8;
    private static final String STATUS_FONT_FAMILY = "Liberation Sans";
    private static final String STATUS_FONT_VERSION = "1.07.4";
    private static final String STATUS_FONT_RESOURCE = "/resources/fonts/LiberationSans-Bold.ttf";
    private static final String STATUS_FONT_SHA256 =
            "361c61b82d575c5c35fd9157fda8b0194bcfcd0d88ea8521a4fb5dd53d33dddc";
    private static final String STATUS_FONT_LICENSE = "SIL Open Font License 1.1";
    private static final String STATUS_FONT_SOURCE = "pdfjs-dist 5.4.624 standard_fonts";

    public String exportDefaultMetadata() throws Exception {
        Document document = readResourcesDocument();
        Map<String, SpriteMetadata> sprites = readSprites(document);
        Element skin = findSkin(document, DEFAULT_SKIN);

        double baseWidth = doubleAttribute(skin, "width", DEFAULT_BASE_WIDTH);
        double baseHeight = doubleAttribute(skin, "height", DEFAULT_BASE_HEIGHT);
        int judgmentLine = intAttribute(skin, "judgment_line", 0);
        int visibilityLayer = visibilityLayer(skin);

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
                JsonWriter.field("visibilityLayer", visibilityLayer),
                JsonWriter.rawField("visibilityMasks", visibilityMasksJson()),
                JsonWriter.field("measureSize", JAVA_MEASURE_SIZE),
                JsonWriter.rawField("statusTextLayout", statusTextLayoutJson()),
                JsonWriter.rawField("statusTextTemplates", statusTextTemplatesJson()),
                JsonWriter.rawField("statusFont", statusFontJson()),
                JsonWriter.rawField("entities", JsonWriter.array(entities.toArray(new String[0]))),
                JsonWriter.rawField("lanes", JsonWriter.array(lanes.toArray(new String[0]))));
    }

    private static int visibilityLayer(Element skin) {
        int noteLayer = -1;
        List<Element> unnamedEntities = new ArrayList<Element>();
        int layer = -1;
        for (Element layerElement : childElements(skin, "layer")) {
            layer++;
            for (Element entityElement : childElements(layerElement, "entity")) {
                String id = emptyToNull(entityElement.getAttribute("id"));
                if ("NOTE_1".equals(id)) {
                    noteLayer = layer;
                } else if (id == null) {
                    unnamedEntities.add(entityElement);
                }
            }
        }

        if (noteLayer < 0) {
            return 0;
        }

        int visibilityLayer = noteLayer + 1;
        for (Element entity : unnamedEntities) {
            int entityLayer = layerForEntity(skin, entity);
            if (entityLayer > visibilityLayer) {
                visibilityLayer++;
            }
        }
        return visibilityLayer + 1;
    }

    private static int layerForEntity(Element skin, Element target) {
        int layer = -1;
        for (Element layerElement : childElements(skin, "layer")) {
            layer++;
            for (Element entityElement : childElements(layerElement, "entity")) {
                if (entityElement == target) {
                    return layer;
                }
            }
        }
        return 0;
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
            List<Element> frameElements = childElements(sprite, "frame");
            if (frameElements.isEmpty()) {
                continue;
            }
            Element frame = frameElements.get(0);

            double scaleX = doubleAttribute(frame, "scale_x", doubleAttribute(frame, "scale", 1.0));
            double scaleY = doubleAttribute(frame, "scale_y", doubleAttribute(frame, "scale", 1.0));
            double textureX = doubleAttribute(frame, "x", 0.0);
            double textureY = doubleAttribute(frame, "y", 0.0);
            double textureWidth = doubleAttribute(frame, "w", 0.0);
            double textureHeight = doubleAttribute(frame, "h", 0.0);
            double width = textureWidth * scaleX;
            double height = textureHeight * scaleY;
            double frameSpeed = doubleAttribute(sprite, "framespeed", 0.0) / 1000.0;
            int frameCount = frameElements.size();
            String texturePath = texturePathFor(frame.getAttribute("file"));
            List<SpriteFrameMetadata> frames = readFrameMetadata(id, frameElements);
            sprites.put(id, new SpriteMetadata(id, width, height, frameCount, frameSpeed, texturePath,
                    textureX, textureY, textureWidth, textureHeight, frames));
        }
        return sprites;
    }

    private static List<SpriteFrameMetadata> readFrameMetadata(String id, List<Element> frameElements) {
        List<SpriteFrameMetadata> frames = new ArrayList<SpriteFrameMetadata>();
        for (Element frame : frameElements) {
            frames.add(new SpriteFrameMetadata(id,
                    texturePathFor(frame.getAttribute("file")),
                    doubleAttribute(frame, "x", 0.0),
                    doubleAttribute(frame, "y", 0.0),
                    doubleAttribute(frame, "w", 0.0),
                    doubleAttribute(frame, "h", 0.0)));
        }
        return frames;
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
        String spriteFrames = spriteFramesJson(spriteRefs, sprites);
        String[] titleRefs = spriteRefs(entity.getAttribute("title"));
        SpriteMetadata titleSprite = titleRefs.length == 0 ? null : sprites.get(titleRefs[0]);
        String titleSpriteFrames = spriteFramesJson(titleRefs, sprites);

        double x = doubleAttribute(entity, "x", 0.0);
        double y = doubleAttribute(entity, "y", 0.0);
        String type = typeFor(id);
        if ("judgmentEffect".equals(type)) {
            x -= sprite.width / 2.0;
        }
        if (id != null && id.startsWith("NOTE_")) {
            SpriteMetadata headSprite = spriteForReference(sprites, entity.getAttribute("head"), sprite);
            SpriteMetadata bodySprite = spriteForReference(sprites, entity.getAttribute("body"), sprite);
            SpriteMetadata tailSprite = spriteForReference(sprites, entity.getAttribute("tail"), sprite);
            String[] headRefs = new String[] { headSprite.id };
            String headSpriteFrames = spriteFramesJson(headRefs, sprites);
            String bodySpriteFrames = spriteFramesJson(new String[] { bodySprite.id }, sprites);
            String tailSpriteFrames = spriteFramesJson(new String[] { tailSprite.id }, sprites);
            entities.add(entityJson("LONG_" + id, "longNote", layer, x, y, headSprite.width, headSprite.height,
                    headRefs, entity, true, id, headSprite, bodySprite, tailSprite, sprite, titleSprite,
                    headSpriteFrames, bodySpriteFrames, tailSpriteFrames, titleSpriteFrames));
            entities.add(entityJson(id, "note", layer, x, y, sprite.width, sprite.height, spriteRefs, entity, true,
                    id, sprite, null, null, null, titleSprite, spriteFrames, "", "", titleSpriteFrames));
            lanes.add(laneJson(id, laneForNoteId(id), x, sprite.width));
            return;
        }

        entities.add(entityJson(id == null ? "" : id, type, layer, x, y, sprite.width, sprite.height,
                spriteRefs, entity, id != null, id, sprite, null, null, null, titleSprite, spriteFrames,
                "", "", titleSpriteFrames));
    }

    private static String entityJson(String id, String type, int layer, double x, double y, double width, double height,
            String[] spriteRefs, Element source, boolean named, String channel, SpriteMetadata sprite,
            SpriteMetadata bodySprite, SpriteMetadata tailSprite, SpriteMetadata normalSprite,
            SpriteMetadata titleSprite, String spriteFrames, String bodySpriteFrames, String tailSpriteFrames,
            String titleSpriteFrames) {
        List<String> fields = new ArrayList<String>();
        fields.add(JsonWriter.field("id", id));
        fields.add(JsonWriter.field("type", type));
        fields.add(JsonWriter.field("layer", layer));
        fields.add(JsonWriter.field("x", x));
        fields.add(JsonWriter.field("y", y));
        fields.add(JsonWriter.field("width", width));
        fields.add(JsonWriter.field("height", height));
        fields.add(JsonWriter.field("named", named));
        int showDigits = showDigitsFor(id);
        if (showDigits > 1) {
            fields.add(JsonWriter.field("showDigits", showDigits));
        }
        addComboCounterBehaviorFields(fields, id);
        addJudgmentEffectBehaviorFields(fields, id);
        addAnimationBehaviorFields(fields, id, sprite);
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
        if (normalSprite != null && !normalSprite.texturePath.isEmpty()) {
            fields.add(JsonWriter.field("normalHeight", normalSprite.height));
        }
        addSpriteFields(fields, "body", bodySprite);
        addSpriteFields(fields, "tail", tailSprite);
        addSpriteFields(fields, "title", titleSprite);
        addPartSpriteFrames(fields, "body", bodySprite, bodySpriteFrames);
        addPartSpriteFrames(fields, "tail", tailSprite, tailSpriteFrames);
        if (!spriteFrames.isEmpty()) {
            if (sprite.frameSpeed > 0.0) {
                fields.add(JsonWriter.field("frameSpeed", sprite.frameSpeed));
            }
            fields.add(JsonWriter.rawField("spriteFrames", spriteFrames));
        }
        if (!titleSpriteFrames.isEmpty()) {
            if (titleSprite != null && titleSprite.frameSpeed > 0.0) {
                fields.add(JsonWriter.field("titleFrameSpeed", titleSprite.frameSpeed));
            }
            fields.add(JsonWriter.rawField("titleSpriteFrames", titleSpriteFrames));
        }
        String fillDirection = source.getAttribute("fill_direction");
        if ("bar".equals(type) && fillDirection != null && !fillDirection.trim().isEmpty()) {
            fields.add(JsonWriter.field("fillDirection", fillDirection));
        }
        fields.add(JsonWriter.rawField("sprites", JsonWriter.array(quoted(spriteRefs))));
        return JsonWriter.object(fields.toArray(new String[0]));
    }

    private static void addComboCounterBehaviorFields(List<String> fields, String id) {
        int threshold = comboCounterThresholdFor(id);
        if (threshold <= 0) {
            return;
        }
        fields.add(JsonWriter.field("countThreshold", threshold));
        fields.add(JsonWriter.field("showTimeMs", COMBO_SHOW_TIME_MS));
        fields.add(JsonWriter.field("wobblePixels", COMBO_WOBBLE_PIXELS));
        fields.add(JsonWriter.field("wobbleSpeed", COMBO_WOBBLE_SPEED));
    }

    private static int comboCounterThresholdFor(String id) {
        if ("COMBO_COUNTER".equals(id)) {
            return 2;
        }
        if ("JAM_COUNTER".equals(id)) {
            return 1;
        }
        return 0;
    }

    private static void addJudgmentEffectBehaviorFields(List<String> fields, String id) {
        if (id == null || !id.startsWith("EFFECT_JUDGMENT_")) {
            return;
        }
        fields.add(JsonWriter.field("showTimeMs", JUDGMENT_SHOW_TIME_MS));
        fields.add(JsonWriter.field("scaleRampMs", JUDGMENT_SCALE_RAMP_MS));
        fields.add(JsonWriter.field("initialScale", JUDGMENT_INITIAL_SCALE));
    }

    private static String statusTextLayoutJson() {
        return JsonWriter.object(
                JsonWriter.field("rightX", STATUS_TEXT_RIGHT_X),
                JsonWriter.field("startY", STATUS_TEXT_START_Y),
                JsonWriter.field("lineHeight", STATUS_TEXT_LINE_HEIGHT),
                JsonWriter.field("labelWidth", STATUS_TEXT_LABEL_WIDTH),
                JsonWriter.field("fontFamily", STATUS_FONT_FAMILY),
                JsonWriter.field("fontSize", STATUS_TEXT_FONT_SIZE),
                JsonWriter.field("glyphHeight", STATUS_TEXT_GLYPH_HEIGHT),
                JsonWriter.field("bold", true),
                JsonWriter.field("antiAlias", false),
                JsonWriter.field("fontColor", "#ffffffff"),
                JsonWriter.field("horizontalAlignment", "right"),
                JsonWriter.field("scaleX", STATUS_TEXT_SCALE_X),
                JsonWriter.field("scaleY", STATUS_TEXT_SCALE_Y));
    }

    private static String statusTextTemplatesJson() {
        return JsonWriter.object(
                JsonWriter.field("speed", "{speedType}: x{speedMultiplier}"),
                JsonWriter.field("measure", "Current Measure: {measure}"),
                JsonWriter.field("gameSpeed", "Game Speed: {gameSpeedPitch}"),
                JsonWriter.rawField("speedTypes", JsonWriter.object(
                        JsonWriter.field("HiSpeed", "HI-SPEED"),
                        JsonWriter.field("xRSpeed", "xR-SPEED"),
                        JsonWriter.field("RegulSpeed", "REGUL-SPEED"),
                        JsonWriter.field("WSpeed", "W-SPEED"))));
    }

    static String statusFontJson() throws Exception {
        FontAtlasMetadata font = createStatusFontAtlas();
        List<String> glyphs = new ArrayList<String>();
        for (GlyphMetadata glyph : font.glyphs) {
            glyphs.add(JsonWriter.object(
                    JsonWriter.field("code", glyph.code),
                    JsonWriter.field("x", glyph.x),
                    JsonWriter.field("y", glyph.y),
                    JsonWriter.field("width", glyph.width),
                    JsonWriter.field("height", glyph.height)));
        }
        return JsonWriter.object(
                JsonWriter.field("source", "TrueTypeFont"),
                JsonWriter.field("fontFamily", STATUS_FONT_FAMILY),
                JsonWriter.field("fontVersion", STATUS_FONT_VERSION),
                JsonWriter.field("fontResource", STATUS_FONT_RESOURCE),
                JsonWriter.field("fontSha256", STATUS_FONT_SHA256),
                JsonWriter.field("fontLicense", STATUS_FONT_LICENSE),
                JsonWriter.field("fontSource", STATUS_FONT_SOURCE),
                JsonWriter.field("fontSize", STATUS_TEXT_FONT_SIZE),
                JsonWriter.field("bold", true),
                JsonWriter.field("antiAlias", false),
                JsonWriter.field("textureWidth", STATUS_FONT_TEXTURE_WIDTH),
                JsonWriter.field("textureHeight", STATUS_FONT_TEXTURE_HEIGHT),
                JsonWriter.field("fontHeight", font.fontHeight),
                JsonWriter.field("correctL", STATUS_FONT_CORRECT_LEFT),
                JsonWriter.field("correctR", STATUS_FONT_CORRECT_RIGHT),
                JsonWriter.field("pngBase64", font.pngBase64),
                JsonWriter.rawField("glyphs", JsonWriter.array(glyphs.toArray(new String[0]))));
    }

    private static FontAtlasMetadata createStatusFontAtlas() throws Exception {
        ensureHeadlessAwtForFontAtlas();
        Font font = loadStatusFont();
        BufferedImage atlas = new BufferedImage(
                STATUS_FONT_TEXTURE_WIDTH,
                STATUS_FONT_TEXTURE_HEIGHT,
                BufferedImage.TYPE_INT_ARGB);
        Graphics2D atlasGraphics = (Graphics2D) atlas.getGraphics();
        atlasGraphics.setColor(new Color(0, 0, 0, 1));
        atlasGraphics.fillRect(0, 0, STATUS_FONT_TEXTURE_WIDTH, STATUS_FONT_TEXTURE_HEIGHT);

        int rowHeight = 0;
        int positionX = 0;
        int positionY = 0;
        int fontHeight = 0;
        List<GlyphMetadata> glyphs = new ArrayList<GlyphMetadata>();

        for (int code = 0; code < 256; code++) {
            BufferedImage glyphImage = createStatusGlyphImage(font, (char) code);
            int width = glyphImage.getWidth();
            int height = glyphImage.getHeight();
            if (positionX + width >= STATUS_FONT_TEXTURE_WIDTH) {
                positionX = 0;
                positionY += rowHeight;
                rowHeight = 0;
            }
            if (height > fontHeight) {
                fontHeight = height;
            }
            if (height > rowHeight) {
                rowHeight = height;
            }
            atlasGraphics.drawImage(glyphImage, positionX, positionY, null);
            glyphs.add(new GlyphMetadata(code, positionX, positionY, width, height));
            positionX += width;
        }

        fontHeight -= 1;
        if (fontHeight <= 0) {
            fontHeight = 1;
        }

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        ImageIO.write(atlas, "png", out);
        return new FontAtlasMetadata(Base64.getEncoder().encodeToString(out.toByteArray()), fontHeight, glyphs);
    }

    private static Font loadStatusFont() throws Exception {
        byte[] bytes;
        try (InputStream input = VosRenderMetadataExporter.class.getResourceAsStream(STATUS_FONT_RESOURCE)) {
            if (input == null) {
                throw new IllegalStateException("Missing pinned status font: " + STATUS_FONT_RESOURCE);
            }
            bytes = input.readAllBytes();
        }

        String actualSha256 = HexFormat.of()
                .formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        if (!STATUS_FONT_SHA256.equals(actualSha256)) {
            throw new IllegalStateException(
                    "Pinned status font hash mismatch: expected " + STATUS_FONT_SHA256 + ", got " + actualSha256);
        }

        Font font;
        try (ByteArrayInputStream input = new ByteArrayInputStream(bytes)) {
            font = Font.createFont(Font.TRUETYPE_FONT, input);
        }
        if (!STATUS_FONT_FAMILY.equals(font.getFamily()) || !"LiberationSans-Bold".equals(font.getPSName())) {
            throw new IllegalStateException(
                    "Pinned status font identity mismatch: " + font.getFamily() + " / " + font.getPSName());
        }
        return font.deriveFont(Font.BOLD, (float) STATUS_TEXT_FONT_SIZE);
    }

    private static void ensureHeadlessAwtForFontAtlas() {
        if (System.getProperty("java.awt.headless") == null) {
            System.setProperty("java.awt.headless", "true");
        }
    }

    private static BufferedImage createStatusGlyphImage(Font font, char ch) {
        BufferedImage temp = new BufferedImage(1, 1, BufferedImage.TYPE_INT_ARGB);
        Graphics2D metricsGraphics = (Graphics2D) temp.getGraphics();
        metricsGraphics.setFont(font);
        FontMetrics fontMetrics = metricsGraphics.getFontMetrics();
        int charWidth = fontMetrics.charWidth(ch) + 8;
        if (charWidth <= 0) {
            charWidth = 7;
        }
        int charHeight = fontMetrics.getHeight() + 3;
        if (charHeight <= 0) {
            charHeight = font.getSize() + 3;
        }

        BufferedImage glyphImage = new BufferedImage(charWidth, charHeight, BufferedImage.TYPE_INT_ARGB);
        Graphics2D glyphGraphics = (Graphics2D) glyphImage.getGraphics();
        glyphGraphics.setFont(font);
        glyphGraphics.setColor(Color.WHITE);
        glyphGraphics.drawString(String.valueOf(ch), 3, 1 + fontMetrics.getAscent());
        return glyphImage;
    }

    private static final class FontAtlasMetadata {
        private final String pngBase64;
        private final int fontHeight;
        private final List<GlyphMetadata> glyphs;

        private FontAtlasMetadata(String pngBase64, int fontHeight, List<GlyphMetadata> glyphs) {
            this.pngBase64 = pngBase64;
            this.fontHeight = fontHeight;
            this.glyphs = glyphs;
        }
    }

    private static final class GlyphMetadata {
        private final int code;
        private final int x;
        private final int y;
        private final int width;
        private final int height;

        private GlyphMetadata(int code, int x, int y, int width, int height) {
            this.code = code;
            this.x = x;
            this.y = y;
            this.width = width;
            this.height = height;
        }
    }

    private static String visibilityMasksJson() {
        return JsonWriter.object(
                JsonWriter.rawField("Hidden", JsonWriter.array(
                        visibilityMaskPointJson(0.0, 0.0),
                        visibilityMaskPointJson(1.9, 0.0),
                        visibilityMaskPointJson(2.0, 1.0),
                        visibilityMaskPointJson(4.0, 1.0))),
                JsonWriter.rawField("Sudden", JsonWriter.array(
                        visibilityMaskPointJson(0.0, 1.0),
                        visibilityMaskPointJson(1.9, 1.0),
                        visibilityMaskPointJson(2.0, 0.0),
                        visibilityMaskPointJson(4.0, 0.0))),
                JsonWriter.rawField("Dark", JsonWriter.array(
                        visibilityMaskPointJson(0.0, 1.0),
                        visibilityMaskPointJson(1.3, 1.0),
                        visibilityMaskPointJson(1.5, 0.0),
                        visibilityMaskPointJson(2.5, 0.0),
                        visibilityMaskPointJson(2.7, 1.0),
                        visibilityMaskPointJson(4.0, 1.0))));
    }

    private static String visibilityMaskPointJson(double at, double alpha) {
        return JsonWriter.object(
                JsonWriter.field("at", at),
                JsonWriter.field("alpha", alpha));
    }

    private static void addAnimationBehaviorFields(List<String> fields, String id, SpriteMetadata sprite) {
        if (sprite == null || sprite.frameSpeed <= 0.0) {
            return;
        }
        fields.add(JsonWriter.field("animationLoop", animationLoopsFor(id)));
    }

    private static boolean animationLoopsFor(String id) {
        return !"EFFECT_CLICK".equals(id);
    }

    private static void addPartSpriteFrames(List<String> fields, String prefix, SpriteMetadata sprite,
            String spriteFrames) {
        if (sprite == null || spriteFrames.isEmpty()) {
            return;
        }
        if (sprite.frameSpeed > 0.0) {
            fields.add(JsonWriter.field(prefix + "FrameSpeed", sprite.frameSpeed));
        }
        fields.add(JsonWriter.rawField(prefix + "SpriteFrames", spriteFrames));
    }

    private static String spriteFramesJson(String[] spriteRefs, Map<String, SpriteMetadata> sprites) {
        List<String> frames = new ArrayList<String>();
        for (String spriteRef : spriteRefs) {
            SpriteMetadata sprite = sprites.get(spriteRef);
            if (sprite == null || sprite.texturePath.isEmpty()) {
                continue;
            }
            for (SpriteFrameMetadata frame : sprite.frames) {
                frames.add(JsonWriter.object(
                        JsonWriter.field("id", frame.id),
                        JsonWriter.field("texturePath", frame.texturePath),
                        JsonWriter.field("textureX", frame.textureX),
                        JsonWriter.field("textureY", frame.textureY),
                        JsonWriter.field("textureWidth", frame.textureWidth),
                        JsonWriter.field("textureHeight", frame.textureHeight)));
            }
        }
        if (frames.isEmpty()) {
            return "";
        }
        return JsonWriter.array(frames.toArray(new String[0]));
    }

    private static SpriteMetadata spriteForReference(Map<String, SpriteMetadata> sprites, String reference,
            SpriteMetadata fallback) {
        String id = emptyToNull(reference);
        if (id == null) {
            return fallback;
        }
        SpriteMetadata sprite = sprites.get(id);
        return sprite == null ? fallback : sprite;
    }

    private static void addSpriteFields(List<String> fields, String prefix, SpriteMetadata sprite) {
        if (sprite == null || sprite.texturePath.isEmpty()) {
            return;
        }
        fields.add(JsonWriter.field(prefix + "TexturePath", sprite.texturePath));
        fields.add(JsonWriter.field(prefix + "TextureX", sprite.textureX));
        fields.add(JsonWriter.field(prefix + "TextureY", sprite.textureY));
        fields.add(JsonWriter.field(prefix + "TextureWidth", sprite.textureWidth));
        fields.add(JsonWriter.field(prefix + "TextureHeight", sprite.textureHeight));
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

    private static int showDigitsFor(String id) {
        if ("SECOND_COUNTER".equals(id)) {
            return 2;
        }
        return 1;
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
        final List<SpriteFrameMetadata> frames;

        SpriteMetadata(String id, double width, double height, int frameCount, double frameSpeed,
                String texturePath, double textureX, double textureY, double textureWidth, double textureHeight,
                List<SpriteFrameMetadata> frames) {
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
            this.frames = frames;
        }

        static SpriteMetadata empty() {
            return new SpriteMetadata("", 0.0, 0.0, 0, 0.0, "", 0.0, 0.0, 0.0, 0.0,
                    new ArrayList<SpriteFrameMetadata>());
        }
    }

    private static final class SpriteFrameMetadata {
        final String id;
        final String texturePath;
        final double textureX;
        final double textureY;
        final double textureWidth;
        final double textureHeight;

        SpriteFrameMetadata(String id, String texturePath, double textureX, double textureY,
                double textureWidth, double textureHeight) {
            this.id = id;
            this.texturePath = texturePath;
            this.textureX = textureX;
            this.textureY = textureY;
            this.textureWidth = textureWidth;
            this.textureHeight = textureHeight;
        }
    }
}
