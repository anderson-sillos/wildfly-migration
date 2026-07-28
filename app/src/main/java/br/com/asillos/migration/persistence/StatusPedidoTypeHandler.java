package br.com.asillos.migration.persistence;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import br.com.asillos.migration.domain.StatusPedido;

import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;

/**
 * Mantém explícito o contrato textual do enum no Oracle e no H2.
 */
public final class StatusPedidoTypeHandler
        extends BaseTypeHandler<StatusPedido> {

    @Override
    public void setNonNullParameter(
            PreparedStatement statement,
            int index,
            StatusPedido parameter,
            JdbcType jdbcType) throws SQLException {
        statement.setString(index, parameter.name());
    }

    @Override
    public StatusPedido getNullableResult(
            ResultSet resultSet, String columnName) throws SQLException {
        return from(resultSet.getString(columnName), resultSet.wasNull());
    }

    @Override
    public StatusPedido getNullableResult(
            ResultSet resultSet, int columnIndex) throws SQLException {
        return from(resultSet.getString(columnIndex), resultSet.wasNull());
    }

    @Override
    public StatusPedido getNullableResult(
            CallableStatement statement, int columnIndex) throws SQLException {
        return from(statement.getString(columnIndex), statement.wasNull());
    }

    private StatusPedido from(String value, boolean wasNull)
            throws SQLException {
        if (wasNull) {
            return null;
        }
        try {
            return StatusPedido.fromDatabaseValue(value);
        } catch (IllegalArgumentException exception) {
            throw new SQLException("Status de pedido desconhecido no banco",
                    exception);
        }
    }
}
