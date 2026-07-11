package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.InputStream;
import java.security.MessageDigest;
import java.util.HexFormat;
import org.junit.jupiter.api.Test;

class VosRenderMetadataExporterTest {
    private static final String STATUS_FONT_RESOURCE = "/resources/fonts/LiberationSans-Bold.ttf";
    private static final String STATUS_FONT_SHA256 =
            "361c61b82d575c5c35fd9157fda8b0194bcfcd0d88ea8521a4fb5dd53d33dddc";

    @Test
    void usesBundledPinnedStatusFont() throws Exception {
        String json = VosRenderMetadataExporter.statusFontJson();

        assertTrue(json.contains("\"fontFamily\":\"Liberation Sans\""));
        assertTrue(json.contains("\"fontVersion\":\"1.07.4\""));
        assertTrue(json.contains("\"fontResource\":\"" + STATUS_FONT_RESOURCE + "\""));
        assertTrue(json.contains("\"fontSha256\":\"" + STATUS_FONT_SHA256 + "\""));
        assertTrue(json.contains("\"fontLicense\":\"SIL Open Font License 1.1\""));
        assertTrue(json.contains("\"fontSource\":\"pdfjs-dist 5.4.624 standard_fonts\""));
        try (InputStream input = VosRenderMetadataExporter.class.getResourceAsStream(STATUS_FONT_RESOURCE)) {
            assertNotNull(input);
            assertEquals(STATUS_FONT_SHA256,
                    HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(input.readAllBytes())));
        }
    }

    @Test
    void exportsDefaultO2JamRenderMetadata() throws Exception {
        String json = new VosRenderMetadataExporter().exportDefaultMetadata();

        assertTrue(json.contains("\"schemaVersion\":1"));
        assertTrue(json.contains("\"format\":\"VOS_RENDER_METADATA\""));
        assertTrue(json.contains("\"skin\":\"o2jam\""));
        assertTrue(json.contains("\"baseWidth\":800.0"));
        assertTrue(json.contains("\"baseHeight\":600.0"));
        assertTrue(json.contains("\"judgmentLine\":480"));
        assertTrue(json.contains("\"measureSize\":385.0"));
        assertTrue(json.contains("\"visibilityLayer\":7"));
        assertTrue(json.contains("\"visibilityMasks\":{\"Hidden\":[{\"at\":0.0,\"alpha\":0.0},{\"at\":1.9,\"alpha\":0.0},{\"at\":2.0,\"alpha\":1.0},{\"at\":4.0,\"alpha\":1.0}]"));
        assertTrue(json.contains("\"Sudden\":[{\"at\":0.0,\"alpha\":1.0},{\"at\":1.9,\"alpha\":1.0},{\"at\":2.0,\"alpha\":0.0},{\"at\":4.0,\"alpha\":0.0}]"));
        assertTrue(json.contains("\"Dark\":[{\"at\":0.0,\"alpha\":1.0},{\"at\":1.3,\"alpha\":1.0},{\"at\":1.5,\"alpha\":0.0},{\"at\":2.5,\"alpha\":0.0},{\"at\":2.7,\"alpha\":1.0},{\"at\":4.0,\"alpha\":1.0}]"));
        assertTrue(json.contains("\"statusTextLayout\":{\"rightX\":780.0,\"startY\":300.0,\"lineHeight\":30.0"));
        assertTrue(json.contains("\"labelWidth\":260.0"));
        assertTrue(json.contains("\"fontFamily\":\"Liberation Sans\""));
        assertTrue(json.contains("\"fontSize\":14"));
        assertTrue(json.contains("\"glyphHeight\":20.0"));
        assertTrue(json.contains("\"bold\":true"));
        assertTrue(json.contains("\"antiAlias\":false"));
        assertTrue(json.contains("\"fontColor\":\"#ffffffff\""));
        assertTrue(json.contains("\"horizontalAlignment\":\"right\""));
        assertTrue(json.contains("\"scaleX\":1.0"));
        assertTrue(json.contains("\"scaleY\":-1.0"));
        assertTrue(json.contains("\"statusTextTemplates\":{\"speed\":\"{speedType}: x{speedMultiplier}\""));
        assertTrue(json.contains("\"measure\":\"Current Measure: {measure}\""));
        assertTrue(json.contains("\"gameSpeed\":\"Game Speed: {gameSpeedPitch}\""));
        assertTrue(json.contains("\"speedTypes\":{\"HiSpeed\":\"HI-SPEED\",\"xRSpeed\":\"xR-SPEED\""));
        assertTrue(json.contains("\"RegulSpeed\":\"REGUL-SPEED\",\"WSpeed\":\"W-SPEED\""));
        assertTrue(json.contains("\"statusFont\":{\"source\":\"TrueTypeFont\""));
        assertTrue(json.contains("\"textureWidth\":512"));
        assertTrue(json.contains("\"textureHeight\":512"));
        assertTrue(json.contains("\"correctL\":9"));
        assertTrue(json.contains("\"correctR\":8"));
        assertTrue(json.contains("\"pngBase64\""));
        assertTrue(json.contains("\"glyphs\":[{\"code\":0"));
        assertTrue(json.contains("\"id\":\"NOTE_1\""));
        assertTrue(json.contains("\"id\":\"LONG_NOTE_1\""));
        assertTrue(json.contains("\"id\":\"JAM_BAR\""));
        assertTrue(json.contains("\"id\":\"LIFE_BAR\",\"type\":\"bar\""));
        assertTrue(json.contains("\"id\":\"LIFE_BAR\",\"type\":\"bar\",\"layer\":1,\"x\":203.0,\"y\":247.0"));
        assertTrue(json.contains("\"fillDirection\":\"up_to_down\""));
        assertTrue(json.contains("\"id\":\"JAM_BAR\",\"type\":\"bar\",\"layer\":7,\"x\":4.0,\"y\":536.0"));
        assertTrue(json.contains("\"fillDirection\":\"left_to_right\""));
        assertTrue(json.contains("\"id\":\"\",\"type\":\"entity\",\"layer\":1,\"x\":226.0,\"y\":515.0,\"width\":226.0,\"height\":72.0,\"named\":false"));
        assertTrue(json.contains("\"sprites\":[\"timebar\"]"));
        assertTrue(json.contains("\"id\":\"SCORE_COUNTER\""));
        assertTrue(json.contains("\"id\":\"SECOND_COUNTER\",\"type\":\"numberCounter\""));
        assertTrue(json.contains("\"id\":\"SECOND_COUNTER\",\"type\":\"numberCounter\",\"layer\":10,\"x\":410.0,\"y\":569.0,\"width\":27.0,\"height\":21.0,\"named\":true,\"showDigits\":2"));
        assertTrue(json.contains("\"id\":\"EFFECT_CLICK\""));
        assertTrue(json.contains("\"animationLoop\":false"));
        assertTrue(json.contains("\"id\":\"EFFECT_LONGFLARE\""));
        assertTrue(json.contains("\"animationLoop\":true"));
        assertTrue(json.contains("\"id\":\"EFFECT_JUDGMENT_COOL\""));
        assertTrue(json.contains(
                "\"id\":\"EFFECT_JUDGMENT_COOL\",\"type\":\"judgmentEffect\",\"layer\":10,\"x\":-34.0"));
        assertTrue(json.contains("\"showTimeMs\":3000.0"));
        assertTrue(json.contains("\"scaleRampMs\":100.0"));
        assertTrue(json.contains("\"initialScale\":0.5"));
        assertTrue(json.contains("\"titleFrameSpeed\":0.012"));
        assertTrue(json.contains("\"titleSpriteFrames\":[{\"id\":\"combo_title\""));
        assertTrue(json.contains("\"titleTextureWidth\":64.0"));
        assertTrue(json.contains("\"id\":\"COMBO_COUNTER\",\"type\":\"comboCounter\""));
        assertTrue(json.contains("\"countThreshold\":2"));
        assertTrue(json.contains("\"id\":\"JAM_COUNTER\",\"type\":\"comboCounter\""));
        assertTrue(json.contains("\"countThreshold\":1"));
        assertTrue(json.contains("\"showTimeMs\":4000.0"));
        assertTrue(json.contains("\"wobblePixels\":10.0"));
        assertTrue(json.contains("\"wobbleSpeed\":0.5"));
        assertTrue(json.contains("\"channel\":\"NOTE_1\""));
        assertTrue(json.contains("\"lane\":0"));
        assertTrue(json.contains("\"x\":5.0"));
        assertTrue(json.contains("\"width\":28.0"));
        assertTrue(json.contains("\"texturePath\""));
        assertTrue(json.contains("Playing_BG10.png"));
        assertTrue(json.contains("main.png"));
        assertTrue(json.contains("\"textureX\":225.0"));
        assertTrue(json.contains("\"textureY\":142.0"));
        assertTrue(json.contains("\"textureWidth\":28.0"));
        assertTrue(json.contains("\"textureHeight\":7.0"));
        assertTrue(json.contains("\"bodyTextureX\":225.0"));
        assertTrue(json.contains("\"bodyTextureY\":143.0"));
        assertTrue(json.contains("\"bodyTextureWidth\":28.0"));
        assertTrue(json.contains("\"bodyTextureHeight\":5.0"));
        assertTrue(json.contains("\"bodyFrameSpeed\":0.012"));
        assertTrue(json.contains("\"bodySpriteFrames\":[{\"id\":\"body_note_white\""));
        assertTrue(json.contains("\"tailTextureX\":225.0"));
        assertTrue(json.contains("\"tailTextureY\":142.0"));
        assertTrue(json.contains("\"tailTextureWidth\":28.0"));
        assertTrue(json.contains("\"tailTextureHeight\":7.0"));
        assertTrue(json.contains("\"tailFrameSpeed\":0.012"));
        assertTrue(json.contains("\"tailSpriteFrames\":[{\"id\":\"head_note_white\""));
        assertTrue(json.contains("\"spriteFrames\":[{\"id\":\"score_number_0\""));
        assertTrue(json.contains("\"id\":\"score_number_9\""));
        assertTrue(json.contains("\"id\":\"MEASURE_MARK\""));
        assertTrue(json.contains("\"frameSpeed\":0.005"));
        assertTrue(json.contains("\"textureY\":138.0"));
    }
}
