package org.open2jam.export;

import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class VosRenderMetadataExporterTest {
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
        assertTrue(json.contains("\"id\":\"NOTE_1\""));
        assertTrue(json.contains("\"id\":\"LONG_NOTE_1\""));
        assertTrue(json.contains("\"id\":\"JAM_BAR\""));
        assertTrue(json.contains("\"id\":\"SCORE_COUNTER\""));
        assertTrue(json.contains("\"id\":\"EFFECT_JUDGMENT_COOL\""));
        assertTrue(json.contains(
                "\"id\":\"EFFECT_JUDGMENT_COOL\",\"type\":\"judgmentEffect\",\"layer\":10,\"x\":-34.0"));
        assertTrue(json.contains("\"titleFrameSpeed\":0.012"));
        assertTrue(json.contains("\"titleSpriteFrames\":[{\"id\":\"combo_title\""));
        assertTrue(json.contains("\"titleTextureWidth\":64.0"));
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
