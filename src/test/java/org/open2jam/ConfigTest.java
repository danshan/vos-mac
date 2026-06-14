package org.open2jam;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.File;
import java.io.InvalidClassException;
import java.nio.file.Path;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

class ConfigTest {
    private static final String CONFIG_DIR_PROPERTY = "open2jam.config.dir";

    @AfterEach
    void clearConfigDirOverride() {
        System.clearProperty(CONFIG_DIR_PROPERTY);
    }

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

    @Test
    void configFilesAreResolvedUnderConfiguredApplicationDataDirectory() {
        Path configDir = Path.of("/tmp/open2jam-config-test");
        System.setProperty(CONFIG_DIR_PROPERTY, configDir.toString());

        assertEquals(configDir.resolve("config.vl").toFile(), Config.configFile());
        assertEquals(configDir.resolve("game-options.xml").toFile(), Config.optionsFile());
    }

    @Test
    void defaultConfigDirectoryDoesNotDependOnProcessWorkingDirectory() {
        File configFile = Config.configFile();
        File optionsFile = Config.optionsFile();

        assertTrue(configFile.isAbsolute());
        assertTrue(optionsFile.isAbsolute());
        assertFalse(Path.of("config.vl").toAbsolutePath().equals(configFile.toPath()));
        assertFalse(Path.of("game-options.xml").toAbsolutePath().equals(optionsFile.toPath()));
    }
}
