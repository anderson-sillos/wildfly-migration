-- Idempotent portable data equivalent to the canonical Oracle seed.

INSERT INTO LAB_PEDIDO (
  ID,
  NUMERO,
  CLIENTE_NOME,
  DESCRICAO,
  VALOR_TOTAL,
  STATUS,
  CRIADO_EM,
  ATUALIZADO_EM
)
SELECT
  NEXT VALUE FOR LAB_PEDIDO_SEQ,
  'LAB-0001',
  'Cliente de referência',
  'Pedido mínimo para validar o baseline',
  125.50,
  'NOVO',
  SYSTIMESTAMP,
  SYSTIMESTAMP
FROM DUAL
WHERE NOT EXISTS (
  SELECT 1
  FROM LAB_PEDIDO
  WHERE NUMERO = 'LAB-0001'
);

COMMIT;
