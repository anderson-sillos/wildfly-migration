-- Idempotent data used by smoke tests and contract discovery.

MERGE INTO LAB_PEDIDO target
USING (
  SELECT
    'LAB-0001' AS NUMERO,
    'Cliente de referência' AS CLIENTE_NOME,
    'Pedido mínimo para validar o baseline' AS DESCRICAO,
    125.50 AS VALOR_TOTAL,
    'NOVO' AS STATUS
  FROM DUAL
) source
ON (target.NUMERO = source.NUMERO)
WHEN NOT MATCHED THEN
  INSERT (
    ID,
    NUMERO,
    CLIENTE_NOME,
    DESCRICAO,
    VALOR_TOTAL,
    STATUS,
    CRIADO_EM,
    ATUALIZADO_EM
  )
  VALUES (
    LAB_PEDIDO_SEQ.NEXTVAL,
    source.NUMERO,
    source.CLIENTE_NOME,
    source.DESCRICAO,
    source.VALOR_TOTAL,
    source.STATUS,
    SYSTIMESTAMP,
    SYSTIMESTAMP
  );

COMMIT;
