package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.io.InvalidClassException;
import org.junit.jupiter.api.Test;

class ConfigTest {
    @Test
    void identifiesInvalidClassExceptionWrappedByVoileMapAsStaleCache() {
        RuntimeException failure = new RuntimeException(new InvalidClassException("org.open2jam.parsers.VOSChart"));

        assertTrue(Config.isStaleCacheFailure(failure));
    }

    @Test
    void doesNotTreatUnrelatedRuntimeExceptionAsStaleCache() {
        RuntimeException failure = new RuntimeException(new IllegalStateException("broken config"));

        assertFalse(Config.isStaleCacheFailure(failure));
    }

    @Test
    void chartCacheKeyUsesSchemaVersionSoStaleLegacyEntriesAreNotOverwritten() {
        assertEquals("cache:v2:/songs", Config.cacheKey(new File("/songs")));
    }
}
