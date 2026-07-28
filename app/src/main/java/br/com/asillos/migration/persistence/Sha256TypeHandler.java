package br.com.asillos.migration.persistence;

import java.sql.CallableStatement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.apache.ibatis.type.BaseTypeHandler;
import org.apache.ibatis.type.JdbcType;

/**
 * Preserva o digest hexadecimal sem o preenchimento de CHAR do fornecedor.
 */
public final class Sha256TypeHandler extends BaseTypeHandler<String> {
    @Override
    public void setNonNullParameter(
            PreparedStatement statement,
            int index,
            String parameter,
            JdbcType jdbcType) throws SQLException {
        statement.setString(index, normalized(parameter));
    }

    @Override
    public String getNullableResult(
            ResultSet resultSet, String columnName) throws SQLException {
        return from(resultSet.getString(columnName), resultSet.wasNull());
    }

    @Override
    public String getNullableResult(
            ResultSet resultSet, int columnIndex) throws SQLException {
        return from(resultSet.getString(columnIndex), resultSet.wasNull());
    }

    @Override
    public String getNullableResult(
            CallableStatement statement, int columnIndex) throws SQLException {
        return from(statement.getString(columnIndex), statement.wasNull());
    }

    private String from(String value, boolean wasNull) throws SQLException {
        return wasNull ? null : normalized(value);
    }

    private String normalized(String value) throws SQLException {
        String normalized = value == null ? null : value.trim();
        if (normalized == null
                || !normalized.matches("[0-9a-f]{64}")) {
            throw new SQLException("SHA-256 persistido tem formato inválido");
        }
        return normalized;
    }
}
