package br.com.asillos.migration.persistence;

import java.io.IOException;
import java.io.InputStream;

import org.apache.ibatis.io.Resources;
import org.apache.ibatis.session.SqlSessionFactory;
import org.apache.ibatis.session.SqlSessionFactoryBuilder;

/**
 * Constrói o MyBatis usando exclusivamente o datasource do contêiner.
 */
public final class MyBatisBootstrap {
    public static final String CONFIGURATION_RESOURCE = "mybatis-config.xml";
    public static final String ENVIRONMENT_ID = "legacy-jndi";

    private MyBatisBootstrap() {
    }

    public static SqlSessionFactory build() {
        InputStream input = null;
        try {
            input = Resources.getResourceAsStream(CONFIGURATION_RESOURCE);
            return new SqlSessionFactoryBuilder().build(
                    input, ENVIRONMENT_ID);
        } catch (IOException exception) {
            throw new IllegalStateException(
                    "Configuração MyBatis não pôde ser carregada", exception);
        } catch (RuntimeException exception) {
            throw new IllegalStateException(
                    "Datasource JNDI do laboratório não está disponível",
                    exception);
        } finally {
            if (input != null) {
                try {
                    input.close();
                } catch (IOException ignored) {
                    // O parse já consumiu o recurso; não há recuperação útil.
                }
            }
        }
    }
}
