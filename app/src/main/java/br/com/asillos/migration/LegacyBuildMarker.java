package br.com.asillos.migration;

/**
 * Marca o WAR legado sem antecipar o fluxo funcional do CP-1D.
 */
public final class LegacyBuildMarker {
    public static final String DATASOURCE_JNDI_NAME =
            "java:/jdbc/MigrationDS";

    private LegacyBuildMarker() {
    }
}
