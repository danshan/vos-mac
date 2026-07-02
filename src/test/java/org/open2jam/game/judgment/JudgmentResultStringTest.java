package org.open2jam.game.judgment;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class JudgmentResultStringTest {
    @Test
    void exposesJavaJudgmentNamesWithPrefix() {
        assertEquals("JUDGMENT_PERFECT", JudgmentResult.PERFECT.toString());
        assertEquals("JUDGMENT_COOL", JudgmentResult.COOL.toString());
        assertEquals("JUDGMENT_GOOD", JudgmentResult.GOOD.toString());
        assertEquals("JUDGMENT_BAD", JudgmentResult.BAD.toString());
        assertEquals("JUDGMENT_MISS", JudgmentResult.MISS.toString());
    }
}
