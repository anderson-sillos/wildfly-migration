package br.com.asillos.migration.web;

import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

import br.com.asillos.migration.LegacyBuildMarker;
import br.com.asillos.migration.persistence.H2SchemaBootstrap;
import br.com.asillos.migration.persistence.MyBatisBootstrap;
import br.com.asillos.migration.persistence.PedidoRepository;

import org.apache.ibatis.session.SqlSessionFactory;

/**
 * Inicializa o datasource, o MyBatis e os recursos compartilhados do WAR.
 */
public final class MigrationContextListener
        implements ServletContextListener {

    @Override
    public void contextInitialized(ServletContextEvent event) {
        ServletContext context = event.getServletContext();
        try {
            H2SchemaBootstrap.runIfEnabled();
            SqlSessionFactory sessionFactory = MyBatisBootstrap.build();
            context.setAttribute(
                    ApplicationResources.PEDIDO_REPOSITORY,
                    new PedidoRepository(sessionFactory));
            context.setAttribute(
                    ApplicationResources.STARTED_AT,
                    Long.valueOf(System.currentTimeMillis()));
            context.log(
                    "Migration Lab iniciado com datasource "
                    + LegacyBuildMarker.DATASOURCE_JNDI_NAME);
        } catch (RuntimeException exception) {
            context.log(
                    "Migration Lab não iniciou: verifique o datasource "
                    + LegacyBuildMarker.DATASOURCE_JNDI_NAME);
            throw new IllegalStateException(
                    "Falha controlada ao inicializar a persistência");
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent event) {
        ServletContext context = event.getServletContext();
        context.removeAttribute(ApplicationResources.PEDIDO_REPOSITORY);
        context.removeAttribute(ApplicationResources.STARTED_AT);
    }
}
