package br.com.asillos.migration.persistence;

import org.apache.ibatis.session.SqlSession;

/**
 * Unidade executada dentro de uma transação MyBatis.
 */
public interface TransactionWork<T> {
    T execute(SqlSession session);
}
