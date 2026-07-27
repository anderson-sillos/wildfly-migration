package br.com.asillos.migration;

/**
 * Mantém constantes do WAR legado compartilhadas pelos checkpoints.
 */
public final class LegacyBuildMarker {
    public static final String DATASOURCE_JNDI_NAME =
            "java:/jdbc/MigrationDS";

    private LegacyBuildMarker() {
    }
}
