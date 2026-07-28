package br.com.asillos.migration.persistence;

import org.apache.ibatis.session.SqlSession;
import org.apache.ibatis.session.SqlSessionFactory;

/**
 * Delimita commit, rollback e fechamento da sessão em um único ponto.
 */
public final class MyBatisTransactionTemplate {
    private final SqlSessionFactory sessionFactory;

    public MyBatisTransactionTemplate(SqlSessionFactory sessionFactory) {
        if (sessionFactory == null) {
            throw new IllegalArgumentException(
                    "SqlSessionFactory não pode ser nula");
        }
        this.sessionFactory = sessionFactory;
    }

    public <T> T execute(TransactionWork<T> work) {
        if (work == null) {
            throw new IllegalArgumentException(
                    "Trabalho transacional não pode ser nulo");
        }

        SqlSession session = sessionFactory.openSession(false);
        Throwable failure = null;
        try {
            T result = work.execute(session);
            session.commit();
            return result;
        } catch (RuntimeException exception) {
            failure = exception;
            rollback(session, exception);
            throw exception;
        } catch (Error error) {
            failure = error;
            rollback(session, error);
            throw error;
        } finally {
            close(session, failure);
        }
    }

    private void rollback(SqlSession session, Throwable original) {
        try {
            session.rollback();
        } catch (RuntimeException rollbackFailure) {
            original.addSuppressed(rollbackFailure);
        }
    }

    private void close(SqlSession session, Throwable original) {
        try {
            session.close();
        } catch (RuntimeException closeFailure) {
            if (original != null) {
                original.addSuppressed(closeFailure);
            } else {
                throw closeFailure;
            }
        }
    }
}
